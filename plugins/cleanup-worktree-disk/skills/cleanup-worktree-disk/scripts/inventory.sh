#!/usr/bin/env bash
# Read-only inventory used by plan.sh. Prints JSON and deletes nothing.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"
script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=plugins/cleanup-worktree-disk/skills/cleanup-worktree-disk/scripts/common.sh
source "$script_dir/common.sh"
load_config

items='[]'
worktrees_file=$(mktemp)
trap 'rm -f "$worktrees_file"' EXIT
IFS=: read -r -a configured_repos <<<"$REPOS"
for configured_repo in "${configured_repos[@]}"; do
	if ! git -C "$configured_repo" rev-parse --show-toplevel >/dev/null 2>&1; then
		printf 'Configured repo is not a git checkout: %s\n' "$configured_repo" >&2
		exit 1
	fi
	configured_repo=$(git -C "$configured_repo" rev-parse --show-toplevel)
	if git -C "$configured_repo" remote get-url origin >/dev/null 2>&1; then
		git -C "$configured_repo" fetch origin -q || { printf 'Could not refresh origin refs for %s\n' "$configured_repo" >&2; exit 1; }
	fi
	git -C "$configured_repo" worktree list --porcelain | awk -v repo="$configured_repo" '/^worktree /{print repo "\t" substr($0,10)}' >>"$worktrees_file"
done
sort -u "$worktrees_file" -o "$worktrees_file"
while IFS=$'\t' read -r owning_repo path; do
	[[ -n "$path" ]] || continue
	branch=$(git -C "$path" symbolic-ref --quiet --short HEAD 2>/dev/null || printf DETACHED)
	locked=0
	if git -C "$owning_repo" worktree list --porcelain | awk -v p="$path" '/^worktree /{hit=(substr($0,10)==p)} /^locked/{if(hit) ok=1} END{exit !ok}'; then locked=1; fi
	remote=""
	state="NO-PR"
	unpushed="?"
	if [[ "$branch" != DETACHED ]]; then
		remote=$(git -C "$path" rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || true)
		if [[ -n "$remote" ]]; then
			unpushed=$(git -C "$path" rev-list --count "$remote..HEAD" 2>/dev/null || printf '?')
			command -v gh >/dev/null 2>&1 || { printf 'gh is required to classify pull requests\n' >&2; exit 1; }
			pr_json=$(gh pr list --head "${remote#*/}" --state all --json state 2>/dev/null) || { printf 'gh failed to query PR state for %s\n' "$path" >&2; exit 1; }
			state=$(jq -r '.[0].state // "NO-PR"' <<<"$pr_json")
		else unpushed=NO-REMOTE
		fi
	fi
	dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
	size=$(du -sk "$path" 2>/dev/null | awk '{print $1+0}')
	items=$(jq -c --arg path "$path" --arg repo "$owning_repo" --arg branch "$branch" --arg remote "$remote" --arg state "$state" --arg unpushed "$unpushed" --argjson locked "$locked" --argjson dirty "$dirty" --argjson size "$size" '. + [{kind:"worktree",path:$path,repo:$repo,primary:($path==$repo),branch:$branch,remote:$remote,state:$state,unpushed:$unpushed,locked:($locked==1),dirty:$dirty,size_kb:$size}]' <<<"$items")
done <"$worktrees_file"

if [[ -d "$BAZEL_OUTPUT_ROOT" ]]; then
	for path in "$BAZEL_OUTPUT_ROOT"/*; do
		[[ -d "$path" ]] || continue
		name=${path##*/}
		[[ "$name" == install || "$name" == cache ]] && continue
		symlink=false
		[[ -L "$path" ]] && symlink=true
		workspace=$(cat "$path/DO_NOT_BUILD_HERE" 2>/dev/null || true)
		if [[ -z "$workspace" ]]; then marker=UNMAPPED
		elif [[ ! -d "$workspace" ]]; then marker=ORPHAN
		else marker=LIVE; fi
		age=$(( ($(date +%s) - $(stat_mtime "$path")) / 3600 ))
		size=$(du -sk "$path" 2>/dev/null | awk '{print $1+0}')
		items=$(jq -c --arg path "$path" --arg workspace "$workspace" --arg marker "$marker" --argjson age "$age" --argjson size "$size" --argjson symlink "$symlink" '. + [{kind:"output_base",path:$path,workspace:$workspace,marker:$marker,age_hours:$age,size_kb:$size,symlink:$symlink}]' <<<"$items")
	done
fi

jq -n --argjson items "$items" '{items:$items}'
