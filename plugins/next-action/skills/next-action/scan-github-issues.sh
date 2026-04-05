#!/usr/bin/env bash
# scan-github-issues.sh — Fetch open GitHub issues, score them by priority,
# detect blockers and in-progress status, and output results as JSON.
#
# Usage: scan-github-issues.sh [--limit N] [--repo OWNER/REPO]
#   --limit N        Show top N results (default: 20)
#   --repo OWNER/REPO  Target repository (default: current repo)
#
# Output: JSON array sorted by score (descending), each entry:
#   { "number", "title", "labels", "score", "status", "blocked_by", "assignees" }
#
# Status values: "ready", "blocked", "in_progress"
#
# Requires: gh (GitHub CLI), jq

set -euo pipefail

LIMIT=20
REPO_FLAG=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--limit)
		LIMIT="$2"
		shift 2
		;;
	--limit=*)
		LIMIT="${1#--limit=}"
		shift
		;;
	--repo)
		REPO_FLAG="--repo $2"
		shift 2
		;;
	--repo=*)
		REPO_FLAG="--repo ${1#--repo=}"
		shift
		;;
	*)
		shift
		;;
	esac
done

# Require gh and jq
if ! command -v gh &>/dev/null || ! command -v jq &>/dev/null; then
	echo '[]'
	exit 0
fi

# Check gh authentication — detect sandbox/TLS issues
auth_err=$(gh auth status 2>&1) || {
	if echo "$auth_err" | grep -qi 'tls\|x509\|certificate\|OSStatus'; then
		cat >&2 <<'SANDBOX_WARN'
warning: gh failed due to TLS/certificate error — likely a macOS sandbox restriction.
Workarounds:
  1. Run with dangerouslyDisableSandbox: true
  2. Use /sandbox to manage sandbox restrictions
SANDBOX_WARN
	fi
	echo '[]'
	exit 0
}

# Fetch issues assigned to current user first
# shellcheck disable=SC2086
issues=$(gh issue list --assignee @me --state open \
	--json number,title,labels,body,assignees \
	--limit "$LIMIT" $REPO_FLAG 2>/dev/null || echo '[]')

assigned_count=$(echo "$issues" | jq 'length')

# If no assigned issues, fall back to all open issues
if [[ "$assigned_count" -eq 0 ]]; then
	# shellcheck disable=SC2086
	issues=$(gh issue list --state open \
		--json number,title,labels,body,assignees \
		--limit "$LIMIT" $REPO_FLAG 2>/dev/null || echo '[]')
fi

issue_count=$(echo "$issues" | jq 'length')
if [[ "$issue_count" -eq 0 ]]; then
	echo '[]'
	exit 0
fi

# Get current user for assignment detection
current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")

# Process each issue: score, detect blockers, detect in-progress
echo "$issues" | jq -c '.[]' | while IFS= read -r issue; do
	number=$(echo "$issue" | jq -r '.number')
	title=$(echo "$issue" | jq -r '.title')
	body=$(echo "$issue" | jq -r '.body // ""')
	labels_json=$(echo "$issue" | jq -c '[.labels[].name]')
	assignees_json=$(echo "$issue" | jq -c '[.assignees[].login]')
	# --- In-progress detection ---
	in_progress=false
	ip_match=$(echo "$labels_json" | jq '[.[] | ascii_downcase] | map(select(. == "in progress" or . == "in-progress" or . == "wip" or . == "in review" or . == "in_progress")) | length')
	if [[ "$ip_match" -gt 0 ]]; then
		in_progress=true
	fi

	# Check for linked open PRs via linkedBranches
	if [[ "$in_progress" == false ]]; then
		# shellcheck disable=SC2086
		linked=$(gh issue view "$number" --json linkedBranches \
			--jq '.linkedBranches | length' $REPO_FLAG 2>/dev/null || echo "0")
		if [[ "$linked" -gt 0 ]]; then
			in_progress=true
		fi
	fi

	if [[ "$in_progress" == true ]]; then
		printf '%s\n' "$(jq -nc \
			--argjson num "$number" \
			--arg title "$title" \
			--argjson labels "$labels_json" \
			--argjson score 0 \
			--arg status "in_progress" \
			--argjson blocked_by '[]' \
			--argjson assignees "$assignees_json" \
			'{number: $num, title: $title, labels: $labels, score: $score, status: $status, blocked_by: $blocked_by, assignees: $assignees}')"
		continue
	fi

	# --- Blocker detection ---
	blocked_by=()

	# Check for task list references: - [ ] #123
	while IFS= read -r ref_num; do
		[[ -z "$ref_num" ]] && continue
		# shellcheck disable=SC2086
		ref_state=$(gh issue view "$ref_num" --json state --jq '.state' $REPO_FLAG 2>/dev/null || echo "UNKNOWN")
		if [[ "$ref_state" == "OPEN" ]]; then
			blocked_by+=("$ref_num")
		fi
	done < <(echo "$body" | grep -oP '- \[ \] #\K[0-9]+' 2>/dev/null || true)

	# Check for URL references: - [ ] https://github.com/.../issues/123
	while IFS= read -r ref_num; do
		[[ -z "$ref_num" ]] && continue
		# Skip if already found as blocker
		already_found=false
		for b in "${blocked_by[@]+"${blocked_by[@]}"}"; do
			[[ "$b" == "$ref_num" ]] && already_found=true && break
		done
		[[ "$already_found" == true ]] && continue
		# shellcheck disable=SC2086
		ref_state=$(gh issue view "$ref_num" --json state --jq '.state' $REPO_FLAG 2>/dev/null || echo "UNKNOWN")
		if [[ "$ref_state" == "OPEN" ]]; then
			blocked_by+=("$ref_num")
		fi
	done < <(echo "$body" | grep -oP '- \[ \] https://github\.com/[^/]+/[^/]+/issues/\K[0-9]+' 2>/dev/null || true)

	# Check for "blocked by #N" / "depends on #N" keywords
	while IFS= read -r ref_num; do
		[[ -z "$ref_num" ]] && continue
		already_found=false
		for b in "${blocked_by[@]+"${blocked_by[@]}"}"; do
			[[ "$b" == "$ref_num" ]] && already_found=true && break
		done
		[[ "$already_found" == true ]] && continue
		# shellcheck disable=SC2086
		ref_state=$(gh issue view "$ref_num" --json state --jq '.state' $REPO_FLAG 2>/dev/null || echo "UNKNOWN")
		if [[ "$ref_state" == "OPEN" ]]; then
			blocked_by+=("$ref_num")
		fi
	done < <(echo "$body" | grep -ioP '(?:blocked by|depends on)\s*#\K[0-9]+' 2>/dev/null || true)

	status="ready"
	blocked_by_json='[]'
	if [[ ${#blocked_by[@]} -gt 0 ]]; then
		status="blocked"
		blocked_by_json=$(printf '%s\n' "${blocked_by[@]}" | jq -Rn '[inputs | tonumber]')
	fi

	# --- Scoring ---
	score=40 # default: no priority label

	# Check labels for priority signals using jq to handle multi-word labels
	if echo "$labels_json" | jq -e '[.[] | ascii_downcase] | any(. == "p0" or . == "critical" or . == "urgent")' >/dev/null 2>&1; then
		score=90
	elif echo "$labels_json" | jq -e '[.[] | ascii_downcase] | any(. == "p1" or . == "high-priority" or . == "high")' >/dev/null 2>&1; then
		score=60
	elif echo "$labels_json" | jq -e '[.[] | ascii_downcase] | any(. == "good first issue" or . == "help wanted")' >/dev/null 2>&1; then
		score=30
	fi

	# Check title prefixes for priority signals
	upper_title="${title^^}"
	if [[ "$upper_title" == *"[P0]"* ]] || [[ "$upper_title" == *"[URGENT]"* ]] || [[ "$upper_title" == *"[CRITICAL]"* ]]; then
		[[ $score -lt 90 ]] && score=90
	elif [[ "$upper_title" == *"[P1]"* ]] || [[ "$upper_title" == *"[HIGH]"* ]]; then
		[[ $score -lt 60 ]] && score=60
	fi

	# Assignment bonus
	if [[ -n "$current_user" ]]; then
		is_assigned=$(echo "$assignees_json" | jq --arg u "$current_user" '[.[] | select(. == $u)] | length')
		if [[ "$is_assigned" -gt 0 ]]; then
			score=$((score + 15))
		fi
	fi

	# Blocked issues get score 0 (they can't be worked on)
	if [[ "$status" == "blocked" ]]; then
		score=0
	fi

	printf '%s\n' "$(jq -nc \
		--argjson num "$number" \
		--arg title "$title" \
		--argjson labels "$labels_json" \
		--argjson score "$score" \
		--arg status "$status" \
		--argjson blocked_by "$blocked_by_json" \
		--argjson assignees "$assignees_json" \
		'{number: $num, title: $title, labels: $labels, score: $score, status: $status, blocked_by: $blocked_by, assignees: $assignees}')"
done | jq -s 'sort_by(-.score) | .[:'"$LIMIT"']'
