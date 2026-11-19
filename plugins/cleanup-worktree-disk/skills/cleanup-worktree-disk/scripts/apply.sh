#!/usr/bin/env bash
# Apply only explicitly selected items from a reviewed plan.
set -euo pipefail

if [[ $# -lt 2 ]]; then
	printf 'Usage: %s <plan.json> <item-id> [item-id ...]\n' "$0" >&2
	exit 2
fi
plan_file=$1
shift
script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=plugins/cleanup-worktree-disk/skills/cleanup-worktree-disk/scripts/common.sh
source "$script_dir/common.sh"
load_config
jq -e '.items|type=="array"' "$plan_file" >/dev/null
repo_root=$(git rev-parse --show-toplevel)

result='[]'
failed_count=0
report() {
	local id status reason
	id=$1 status=$2 reason=$3
	[[ "$status" != failed ]] || failed_count=$((failed_count + 1))
	result=$(jq -c --arg id "$id" --arg status "$status" --arg reason "$reason" '. + [{id:$id,status:$status,reason:$reason}]' <<<"$result")
	printf '%s: %s (%s)\n' "$id" "$status" "$reason"
}

for id in "$@"; do
	item=$(jq -c --arg id "$id" '([.items[],.extras[]?] | map(select(.id==$id)) | .[0]) // empty' "$plan_file")
	if [[ -z "$item" ]]; then report "$id" failed 'not present in plan'; continue; fi
	class=$(jq -r '.class' <<<"$item")
	path=$(jq -r '.path' <<<"$item")
	kind=$(jq -r '.kind' <<<"$item")
	item_repo=$(jq -r '.repo // empty' <<<"$item")
	if [[ "$class" == keep ]]; then report "$id" skipped 'plan class is keep'; continue; fi
	if [[ "$class" != remove && "$class" != ask ]]; then report "$id" skipped "unknown plan class: $class"; continue; fi
	if is_protected "$path"; then report "$id" skipped 'matches configured protect pattern'; continue; fi

	case "$kind" in
	worktree)
		[[ "$path" != "$repo_root" ]] || { report "$id" skipped 'primary checkout'; continue; }
		if ! git -C "$item_repo" worktree list --porcelain | awk -v p="$path" '/^worktree /&&substr($0,10)==p{found=1} END{exit !found}'; then report "$id" skipped 'worktree no longer exists'; continue; fi
		if git -C "$item_repo" worktree list --porcelain | awk -v p="$path" '/^worktree /{hit=(substr($0,10)==p)} /^locked/{if(hit) found=1} END{exit !found}'; then report "$id" skipped 'worktree is now locked'; continue; fi
		if [[ "$(git -C "$path" status --porcelain | wc -l | tr -d ' ')" != 0 ]]; then report "$id" skipped 'worktree is now dirty'; continue; fi
		branch=$(git -C "$path" symbolic-ref --quiet --short HEAD 2>/dev/null || printf DETACHED)
		remote=$(git -C "$path" rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || true)
		if [[ "$branch" == DETACHED || -z "$remote" ]]; then report "$id" skipped 'detached or no upstream'; continue; fi
		unpushed=$(git -C "$path" rev-list --count "$remote..HEAD" 2>/dev/null || printf '?')
		if [[ "$unpushed" != 0 ]]; then report "$id" skipped 'worktree has unpushed or unknown commits'; continue; fi
		pr_json=$(gh pr list --head "${remote#*/}" --state all --json state 2>/dev/null || printf '[]')
		state=$(jq -r '.[0].state // "NO-PR"' <<<"$pr_json")
		if [[ "$state" != MERGED ]]; then report "$id" skipped "pull request state is $state"; continue; fi
		if git -C "$item_repo" worktree remove --force "$path"; then git -C "$item_repo" worktree prune; report "$id" removed 'merged, clean worktree removed'; else report "$id" failed 'git worktree remove failed'; fi
		;;
	branch)
		if ! git check-ref-format --branch "$path" >/dev/null 2>&1; then report "$id" skipped 'invalid branch name in plan'; continue; fi
		worktree_id=$(jq -r '.worktree_id // empty' <<<"$item")
		if [[ -z "$worktree_id" ]] || ! printf '%s\n' "$@" | grep -Fqx "$worktree_id"; then report "$id" skipped 'select the associated worktree in the same apply run'; continue; fi
		worktree_path=$(jq -r --arg id "$worktree_id" '.items[]|select(.id==$id)|.path' "$plan_file")
		if git -C "$item_repo" worktree list --porcelain | awk -v p="$worktree_path" '/^worktree /&&substr($0,10)==p{found=1} END{exit !found}'; then report "$id" skipped 'associated worktree was not removed'; continue; fi
		if git -C "$item_repo" worktree list --porcelain | grep -Fqx "branch refs/heads/$path"; then report "$id" skipped 'branch is still checked out'; continue; fi
		if git -C "$item_repo" show-ref --verify --quiet "refs/heads/$path"; then
			if git -C "$item_repo" branch -D -- "$path"; then report "$id" removed 'local branch deleted'; else report "$id" failed 'branch deletion failed'; fi
		else report "$id" skipped 'branch no longer exists'; fi
		;;
	output_base)
		[[ -n "$item_repo" ]] || item_repo=$repo_root
		case "$path" in "$BAZEL_OUTPUT_ROOT"/*) ;; *) report "$id" skipped 'path is outside configured Bazel root'; continue ;; esac
		[[ -d "$path" ]] || { report "$id" skipped 'output base no longer exists'; continue; }
		[[ ! -L "$path" ]] || { report "$id" skipped 'output base is a symbolic link'; continue; }
		root_real=$(cd "$BAZEL_OUTPUT_ROOT" && pwd -P)
		base_real=$(cd "$path" && pwd -P)
		case "$base_real" in "$root_real"/*) path=$base_real ;; *) report "$id" skipped 'resolved path is outside configured Bazel root'; continue ;; esac
		if [[ -e "$path/DO_NOT_BUILD_HERE" && ! -r "$path/DO_NOT_BUILD_HERE" ]]; then report "$id" skipped 'cannot read DO_NOT_BUILD_HERE'; continue; fi
		workspace=$(cat "$path/DO_NOT_BUILD_HERE" 2>/dev/null || true)
		if [[ -z "$workspace" ]]; then
			age=$(( ($(date +%s) - $(stat_mtime "$path")) / 3600 ))
			if (( age < FRESH_HOURS )); then report "$id" skipped 'unmapped output base is fresh'; continue; fi
		elif [[ -d "$workspace" ]]; then
			worktree_id=$(jq -r --arg ws "$workspace" '.items[]|select(.kind=="worktree" and .path==$ws)|.id' "$plan_file")
			if [[ -z "$worktree_id" ]] || ! printf '%s\n' "$@" | grep -Fqx "$worktree_id"; then report "$id" skipped 'select the associated worktree in the same apply run'; continue; fi
			if git -C "$item_repo" worktree list --porcelain | awk -v p="$workspace" '/^worktree /&&substr($0,10)==p{found=1} END{exit !found}'; then report "$id" skipped 'associated worktree was not removed'; continue; fi
		else workspace=""; fi
		if [[ -n "$workspace" ]]; then report "$id" skipped 'output base workspace is now live'; continue; fi
		if chmod -R u+w "$path" 2>/dev/null && rm -rf -- "$path"; then report "$id" removed 'output base deleted'; else report "$id" failed 'could not remove output base'; fi
		;;
	extra)
		command=$(jq -r '.command' <<<"$item")
		if bash -c "$command"; then report "$id" removed 'extra command completed'; else report "$id" failed 'extra command failed'; fi
		;;
	*) report "$id" failed "unknown item kind: $kind" ;;
	esac
done

printf '%s\n' "$result" >"${RESULT_FILE:-/dev/stdout}"
if (( failed_count > 0 )); then exit 1; fi
