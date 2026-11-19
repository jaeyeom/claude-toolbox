#!/usr/bin/env bash
# Build a reviewable JSON cleanup plan; this script never deletes anything.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=plugins/cleanup-worktree-disk/skills/cleanup-worktree-disk/scripts/common.sh
source "$script_dir/common.sh"
had_config=0
[[ -f "$CONFIG_FILE" ]] && had_config=1
load_config
if [[ "${1:-}" == --write-config ]]; then
	[[ $# -eq 1 ]] || { printf 'Usage: %s --write-config\n' "$0" >&2; exit 2; }
	(( had_config == 0 )) || { printf 'Config already exists; refusing to overwrite it\n' >&2; exit 1; }
	mkdir -p "$(dirname "$CONFIG_FILE")"
	{
		printf 'repos=%s\n' "$(git rev-parse --show-toplevel)"
		[[ ! -d "$BAZEL_OUTPUT_ROOT" ]] || printf 'bazel_output_root=%s\n' "$BAZEL_OUTPUT_ROOT"
		printf 'protect=\nfresh_hours=%s\n' "$FRESH_HOURS"
	} >"$CONFIG_FILE"
	printf 'Saved config to %s\n' "$CONFIG_FILE"
	exit 0
fi
[[ $# -eq 0 ]] || { printf 'Usage: %s [--write-config]\n' "$0" >&2; exit 2; }
inventory=$("$script_dir/inventory.sh")
repo_root=$(git rev-parse --show-toplevel)
fresh_hours=$FRESH_HOURS
disk_volume=/
[[ "$(uname -s)" == Darwin ]] && disk_volume=/System/Volumes/Data
disk_before_kb=$(df -Pk "$disk_volume" | awk 'END {print $4}')

plan=$(jq -c --argjson fresh "$fresh_hours" --arg before "$disk_before_kb" '
  .items as $items |
  [ $items[] | select(.kind == "worktree") | . as $wt |
    (if $wt.primary then ["keep","primary checkout"]
     elif $wt.locked then ["keep","worktree is locked"]
     elif $wt.unpushed != "0" then ["ask","un-pushed or unknown commits require review"]
     elif $wt.state == "OPEN" then ["keep","pull request is open"]
     elif $wt.state == "MERGED" and $wt.dirty == 0 and $wt.unpushed == "0" then ["remove","pull request is merged and worktree is clean and pushed"]
     else ["ask","pull request state is not safely removable"] end) as $decision |
    {kind:"worktree",path:$wt.path,repo:$wt.repo,primary:$wt.primary,size_kb:$wt.size_kb,class:$decision[0],reasons:[$decision[1]],branch:$wt.branch,remote:$wt.remote,state:$wt.state,dirty:$wt.dirty,unpushed:$wt.unpushed,locked:$wt.locked,id:("worktree:"+$wt.path)}
  ] as $worktrees |
  ($worktrees | map(select(.class=="remove" and .branch!="DETACHED") | {kind:"branch",path:.branch,repo:.repo,size_kb:0,class:"remove",reasons:["branch belongs to removable worktree"],worktree_id:.id,id:("branch:"+.repo+":"+.branch)})) as $branches |
  [ $items[] | select(.kind == "output_base") | . as $base |
    ([ $worktrees[] | select(.path == $base.workspace)][0] // {}) as $owner_wt |
    ($owner_wt.class // "") as $owner |
    (if $base.symlink then ["keep","output base is a symbolic link"]
     elif $base.marker=="ORPHAN" then ["remove","workspace no longer exists"]
     elif $base.marker=="UNMAPPED" and $base.age_hours < $fresh then ["keep","unmapped output base is fresh"]
     elif $base.marker=="UNMAPPED" then ["ask","unmapped output base is old"]
     elif $owner=="remove" then ["remove","belongs to removable worktree"]
     else ["keep","belongs to a live worktree"] end) as $decision |
    {kind:"output_base",path:$base.path,size_kb:$base.size_kb,class:$decision[0],reasons:[$decision[1]],workspace:$base.workspace,repo:($owner_wt.repo // ""),marker:$base.marker,age_hours:$base.age_hours,id:("output_base:"+$base.path)}
  ] as $bases |
  {items:[$worktrees[],$branches[],$bases[]],extras:[],disk_before_kb:($before|tonumber)}
' <<<"$inventory")

while IFS='=' read -r name command; do
	[[ -n "$name" ]] || continue
	extra=$(jq -cn --arg name "$name" --arg command "$command" '{id:("extra:"+$name),kind:"extra",path:$name,size_kb:null,class:"ask",reasons:["configured extra command; estimate unavailable"],command:$command}')
	plan=$(jq -c --argjson extra "$extra" '.extras += [$extra]' <<<"$plan")
done <<<"$EXTRA_CONFIG"

while IFS=$'\t' read -r id path; do
	if is_protected "$path"; then
		plan=$(jq -c --arg id "$id" '.items as $all | ([ $all[]|select(.id==$id)][0]) as $target | .items |= map(if .id==$id or (.worktree_id==$id) or (.kind=="output_base" and .workspace==$target.path) then .class="keep" | .reasons += ["matched protect pattern or protected owner"] else . end)' <<<"$plan")
	fi
done < <(jq -r '.items[] | [.id,.path] | @tsv' <<<"$plan")

printf '%-12s %-8s %10s  %-48s %s\n' KIND CLASS SIZE PATH REASONS >&2
jq -r '(.items[]),(.extras[]) | [.kind,.class,(if .size_kb==null then "n/a" else ((.size_kb|tostring)+" KB") end),.path,(.reasons|join("; "))] | @tsv' <<<"$plan" | while IFS="$(printf '\t')" read -r kind class size path reasons; do
	printf '%-12s %-8s %10s  %-48s %s\n' "$kind" "$class" "$size" "$path" "$reasons" >&2
done
reclaim_kb=$(jq -r '[.items[]|select(.class=="remove")|.size_kb]|add//0' <<<"$plan")
printf 'Estimated reclaim: %s KB\n' "$reclaim_kb" >&2
printf '%s\n' "$plan"
if (( had_config == 0 )); then
	printf '\nNo config found. Suggested config (save only after user approval with --write-config):\n' >&2
	printf 'repos=%s\n' "$repo_root" >&2
	[[ ! -d "$BAZEL_OUTPUT_ROOT" ]] || printf 'bazel_output_root=%s\n' "$BAZEL_OUTPUT_ROOT" >&2
	printf 'protect=\nfresh_hours=%s\n' "$FRESH_HOURS" >&2
fi
