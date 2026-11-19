#!/usr/bin/env bash
# Report disk space and any planned removal candidates that remain.
set -euo pipefail

if [[ $# -ne 1 ]]; then printf 'Usage: %s <plan.json>\n' "$0" >&2; exit 2; fi
plan=$1
jq -e '.items|type=="array"' "$plan" >/dev/null
disk_volume=/
[[ "$(uname -s)" == Darwin ]] && disk_volume=/System/Volumes/Data
before=$(jq -r '.disk_before_kb // "unknown"' "$plan")
after=$(df -Pk "$disk_volume" | awk 'END {print $4}')
printf 'Disk free (KB): before=%s after=%s\n' "$before" "$after"
printf 'Worktrees:\n'
while IFS= read -r repo; do git -C "$repo" worktree list; done < <(jq -r '.items[]|select(.kind=="worktree")|.repo' "$plan" | sort -u)
leftovers=0
while IFS=$'\t' read -r kind path repo; do
	case "$kind" in
		worktree) [[ ! -e "$path" ]] || { printf 'LEFTOVER worktree: %s\n' "$path"; leftovers=$((leftovers+1)); } ;;
		branch) git -C "$repo" show-ref --verify --quiet "refs/heads/$path" && { printf 'LEFTOVER branch: %s\n' "$path"; leftovers=$((leftovers+1)); } || true ;;
		output_base) [[ ! -e "$path" ]] || { printf 'LEFTOVER output base: %s\n' "$path"; leftovers=$((leftovers+1)); } ;;
	esac
done < <(jq -r '.items[] | select(.class=="remove") | [.kind,.path,(.repo // "")] | @tsv' "$plan")
printf 'Planned removal leftovers: %s\n' "$leftovers"
