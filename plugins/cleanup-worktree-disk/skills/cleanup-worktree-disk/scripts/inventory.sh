#!/usr/bin/env bash
# Read-only inventory + classification for worktree / bazel-cache cleanup.
# Prints a plan; deletes NOTHING. Run from inside the main repo checkout.
#
# Requires `gh` for merge-state detection, which needs network. The Claude Code
# sandbox blocks TLS for Go binaries (gh/jira), so this must run with the
# sandbox disabled — otherwise every gh call silently returns NO-PR.
set -uo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
	echo "not in a git repo"
	exit 1
}
cd "$repo_root" || exit
git fetch origin -q 2>/dev/null || true

bazel_root="/private/var/tmp/_bazel_$(whoami)"

echo "=== disk (Data volume) ==="
df -h /System/Volumes/Data 2>/dev/null | tail -1 || df -h / | tail -1

echo
echo "=== worktrees ==="
# porcelain groups: worktree / HEAD / branch|detached / [locked]
git worktree list --porcelain | awk '
  /^worktree /{wt=$2; br=""; locked=0}
  /^branch /{br=$2}
  /^detached/{br="DETACHED"}
  /^locked/{locked=1}
  /^$/{ if(wt!=""){ printf "%s\t%s\t%s\n", wt, br, locked; wt="" } }
  END{ if(wt!=""){ printf "%s\t%s\t%s\n", wt, br, locked } }
' | sed 's#refs/heads/##' | while IFS=$'\t' read -r wt br locked; do
	[ "$wt" = "$repo_root" ] && continue # never the primary checkout
	base=$(basename "$wt")
	# Resolve the remote branch the local branch tracks; PRs live under that name,
	# which is frequently NOT the local branch name (e.g. worktree-* prefixes).
	head="$br"
	if [ "$br" != "DETACHED" ]; then
		up=$(git rev-parse --abbrev-ref "$br@{upstream}" 2>/dev/null | sed 's#^origin/##')
		[ -n "$up" ] && head="$up"
	fi
	state="NO-PR"
	if [ "$br" != "DETACHED" ]; then
		s=$(gh pr list --head "$head" --state all --json state -q '.[0].state' 2>/dev/null)
		[ -n "$s" ] && [ "$s" != "null" ] && state="$s"
	fi
	# Safety signals: dirty working tree (ignored files excluded) + unpushed commits.
	dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
	unpushed="?"
	if [ "$br" != "DETACHED" ]; then
		if git rev-parse --verify --quiet "refs/remotes/origin/$head" >/dev/null 2>&1; then
			unpushed=$(git -C "$wt" rev-list --count "origin/$head..HEAD" 2>/dev/null || echo "?")
		else
			unpushed="NO-REMOTE"
		fi
	fi
	lk=""
	[ "$locked" = "1" ] && lk="LOCKED"
	printf '%-44s state=%-8s dirty=%-3s unpushed=%-9s %s\n' "$base" "$state" "$dirty" "$unpushed" "$lk"
done

echo
echo "=== bazel output bases ($bazel_root) ==="
[ -d "$bazel_root" ] || {
	echo "(none)"
	exit 0
}
today=$(date +%Y-%m-%d)
for d in "$bazel_root"/*/; do
	d="${d%/}"
	name=$(basename "$d")
	# install/ and cache/ are shared across all workspaces — never candidates.
	case "$name" in install | cache) continue ;; esac
	ws=$(cat "$d/DO_NOT_BUILD_HERE" 2>/dev/null)
	mtime=$(stat -f '%Sm' -t '%Y-%m-%d' "$d" 2>/dev/null)
	sz=$(du -sh "$d" 2>/dev/null | cut -f1)
	if [ -z "$ws" ]; then
		flag="UNMAPPED"
		[ "$mtime" = "$today" ] && flag="UNMAPPED-FRESH(keep)"
	elif [ ! -d "$ws" ]; then
		flag="ORPHAN(safe-delete)"
	else
		flag="LIVE -> $ws"
	fi
	printf '%-34s %-7s mtime=%s  %s\n' "$name" "$sz" "$mtime" "$flag"
done