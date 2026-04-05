#!/usr/bin/env bash
# unpushed-commits.sh — List commits on the current branch that have not been
# pushed to the remote. Tries multiple strategies to find the remote reference.
#
# Usage: unpushed-commits.sh
#
# Output: One commit per line in --oneline format, or empty if no unpushed
#   commits are found. Exits 0 in all cases (including no remote configured).
#
# Strategy order:
#   1. Compare against @{upstream} tracking ref
#   2. Compare against origin/<current-branch>
#   3. Compare against the remote default branch (origin/HEAD, origin/main,
#      or origin/master)

set -euo pipefail

# Strategy 1: upstream tracking ref
if output=$(git log '@{upstream}..HEAD' --oneline 2>/dev/null); then
	[[ -n "$output" ]] && echo "$output"
	exit 0
fi

# Strategy 2: same branch name on origin
current_branch=$(git branch --show-current 2>/dev/null)
if [[ -n "$current_branch" ]]; then
	if output=$(git log "origin/${current_branch}..HEAD" --oneline 2>/dev/null); then
		[[ -n "$output" ]] && echo "$output"
		exit 0
	fi
fi

# Strategy 3: remote default branch
default_ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo "")
if [[ -z "$default_ref" ]]; then
	# Fall back to origin/main or origin/master
	if git rev-parse --verify origin/main >/dev/null 2>&1; then
		default_ref="origin/main"
	elif git rev-parse --verify origin/master >/dev/null 2>&1; then
		default_ref="origin/master"
	fi
fi

if [[ -n "$default_ref" ]]; then
	if output=$(git log "${default_ref}..HEAD" --oneline 2>/dev/null); then
		[[ -n "$output" ]] && echo "$output"
		exit 0
	fi
fi

# No unpushed commits found or no remote configured
exit 0
