#!/usr/bin/env bash
# claim.sh - claim-comment helper for the gh-issue-resolver skill.
#
# Usage:
#   claim.sh nickname                  Print this machine's nickname (exit 3 if unset)
#   claim.sh set-nickname <name>       Save the nickname (lowercase letters, digits, -)
#   claim.sh latest <issue>            Print the latest claim comment as JSON, with
#                                      "own": true when it is this machine's claim
#   claim.sh post <issue> [--agent NAME] [--session ID]
#                                      Post a claim comment and append it to the local log
#
# --agent is a lowercase agent id (claude-code, codex, grok, antigravity); input
# is lowercased with spaces turned into "-". It defaults to the first
# "_"-separated field of $AI_AGENT, else "agent".
# --session defaults to $CLAUDE_CODE_SESSION_ID when set; other agents should
# pass their own session ID if they know it.
#
# The claim comment is: "Claimed by <agent> on <nickname> at <UTC time>."
# The local log line has the same timestamp, so the two can be matched exactly.
#
# Config: ${XDG_CONFIG_HOME:-~/.config}/gh-issue-resolver/config  (nickname=<name>)
# Log:    ${XDG_STATE_HOME:-~/.local/state}/gh-issue-resolver/claims.jsonl
#
# Requires: gh (authenticated), jq.

set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/gh-issue-resolver/config"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/gh-issue-resolver/claims.jsonl"
CLAIM_PREFIX="Claimed by "

die() {
	echo "claim.sh: $*" >&2
	exit 1
}

usage() {
	sed -n '4,11p' "$0" | sed 's/^# \{0,1\}//' >&2
	exit 2
}

get_nickname() {
	[[ -f "$CONFIG_FILE" ]] || return 0
	sed -n 's/^nickname=//p' "$CONFIG_FILE" | tail -n 1
}

cmd_nickname() {
	local nick
	nick="$(get_nickname)"
	if [[ -z "$nick" ]]; then
		echo "claim.sh: no nickname set; run: claim.sh set-nickname <name>" >&2
		exit 3
	fi
	echo "$nick"
}

cmd_set_nickname() {
	local nick="${1:-}"
	[[ "$nick" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] ||
		die "nickname must be 1-32 chars of lowercase letters, digits, or '-' (got '$nick')"
	mkdir -p "$(dirname "$CONFIG_FILE")"
	if [[ -f "$CONFIG_FILE" ]]; then
		local tmp
		tmp="$(mktemp "$CONFIG_FILE.XXXXXX")"
		grep -v '^nickname=' "$CONFIG_FILE" >"$tmp" || true
		echo "nickname=$nick" >>"$tmp"
		mv "$tmp" "$CONFIG_FILE"
	else
		echo "nickname=$nick" >"$CONFIG_FILE"
	fi
	echo "$nick"
}

cmd_latest() {
	local issue="${1:-}"
	[[ "$issue" =~ ^[0-9]+$ ]] || usage
	local me nick
	me="$(gh api user --jq .login)"
	nick="$(get_nickname)"
	gh issue view "$issue" --json comments --jq '.comments' |
		jq --arg prefix "$CLAIM_PREFIX" --arg me "$me" --arg nick "$nick" '
			[.[] | select(.body | startswith($prefix))] | last
			| if . == null then empty else
				{author: .author.login, createdAt, body,
				 own: ($nick != "" and .author.login == $me
				       and (.body | contains(" on " + $nick + " at ")))}
			  end'
}

cmd_post() {
	local issue="${1:-}"
	[[ "$issue" =~ ^[0-9]+$ ]] || usage
	shift
	local agent="${AI_AGENT%%_*}" session="${CLAUDE_CODE_SESSION_ID:-}"
	[[ -n "$agent" ]] || agent="agent"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--agent)
			agent="${2:?--agent needs a value}"
			shift 2
			;;
		--session)
			session="${2:?--session needs a value}"
			shift 2
			;;
		*) usage ;;
		esac
	done

	agent="$(printf %s "$agent" | tr "[:upper:] " "[:lower:]-")"

	local nick repo ts body
	nick="$(get_nickname)"
	repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
	ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	if [[ -n "$nick" ]]; then
		body="${CLAIM_PREFIX}${agent} on ${nick} at ${ts}."
	else
		body="${CLAIM_PREFIX}${agent} at ${ts}."
	fi

	local url
	url="$(gh issue comment "$issue" --body "$body")"

	mkdir -p "$(dirname "$LOG_FILE")"
	jq -cn \
		--arg time "$ts" --arg repo "$repo" --argjson issue "$issue" \
		--arg nickname "$nick" --arg agent "$agent" --arg session "$session" \
		--arg directory "$PWD" --arg comment "$url" \
		'{time: $time, repo: $repo, issue: $issue, nickname: $nickname,
		  agent: $agent, session: $session, directory: $directory, comment: $comment}' \
		>>"$LOG_FILE"

	echo "$body"
	echo "$url"
}

command -v jq >/dev/null || die "jq is required"

case "${1:-}" in
nickname) cmd_nickname ;;
set-nickname) cmd_set_nickname "${2:-}" ;;
latest) cmd_latest "${2:-}" ;;
post)
	shift
	cmd_post "$@"
	;;
*) usage ;;
esac
