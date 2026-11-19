#!/usr/bin/env bash
set -euo pipefail

plugin_dir=$(cd "$(dirname "$0")/.." && pwd)
scripts="$plugin_dir/scripts"
tmp=$(mktemp -d)
tmp=$(cd "$tmp" && pwd -P)
trap 'chmod -R u+w "$tmp" 2>/dev/null || true; rm -rf "$tmp"' EXIT
repo="$tmp/repo"
remote="$tmp/remote.git"
bazel="$tmp/bazel"
bin="$tmp/bin"
mkdir -p "$bin" "$bazel"
git init -q "$repo"
git -C "$repo" config user.name Fixture
git -C "$repo" config user.email fixture@example.invalid
git -C "$repo" config commit.gpgsign false
printf 'seed\n' >"$repo/README"
git -C "$repo" add README
git -C "$repo" commit -qm seed
git init -q --bare "$remote"
git -C "$repo" remote add origin "$remote"
git -C "$repo" push -qu origin HEAD
main_branch=$(git -C "$repo" branch --show-current)

make_worktree() {
	local branch=$1
	git -C "$repo" switch -qc "$branch"
	printf '%s\n' "$branch" >"$repo/$branch.txt"
	git -C "$repo" add "$branch.txt"
	git -C "$repo" commit -qm "$branch"
	git -C "$repo" push -qu -u origin "$branch"
	git -C "$repo" switch -q "$main_branch"
	git -C "$repo" worktree add -q "$tmp/$branch" "$branch"
}

make_worktree merged
make_worktree open
make_worktree locked
make_worktree unpushed
git -C "$tmp/unpushed" config user.name Fixture
git -C "$tmp/unpushed" config user.email fixture@example.invalid
printf 'local only\n' >>"$tmp/unpushed/README"
git -C "$tmp/unpushed" commit -qam 'local only'
git -C "$repo" worktree add -q --detach "$tmp/detached" "$main_branch"
git -C "$repo" worktree lock "$tmp/locked" --reason 'fixture lock'

cat >"$bin/gh" <<'EOF'
#!/bin/sh
head=
while [ "$#" -gt 0 ]; do
	if [ "$1" = --head ]; then head=$2; shift 2; else shift; fi
done
case "$head" in merged) printf '[{"state":"MERGED"}]\n' ;; open|locked|unpushed) printf '[{"state":"OPEN"}]\n' ;; *) printf '[]\n' ;; esac
EOF
chmod +x "$bin/gh"

config_home="$tmp/config"
mkdir -p "$config_home/cleanup-worktree-disk"
cat >"$config_home/cleanup-worktree-disk/config" <<EOF
repos=$repo
bazel_output_root=$bazel
protect=$bazel/protected*
fresh_hours=24
extra.marker=printf selected > '$tmp/extra-ran'
EOF

mkdir -p "$bazel/orphan" "$bazel/protected-orphan" "$bazel/fresh"
printf '%s\n' "$tmp/missing-workspace" >"$bazel/orphan/DO_NOT_BUILD_HERE"
printf '%s\n' "$tmp/missing-protected" >"$bazel/protected-orphan/DO_NOT_BUILD_HERE"
touch -t 200001010000 "$bazel/orphan" "$bazel/protected-orphan"

export PATH="$bin:$PATH" XDG_CONFIG_HOME="$config_home"
cd "$repo"
plan="$tmp/plan.json"
bash "$scripts/plan.sh" >"$plan" 2>"$tmp/table.txt"
jq -e '.items|type=="array"' "$plan" >/dev/null
class_of() { jq -r --arg path "$1" '.items[]|select(.path==$path)|.class' "$plan"; }
[[ $(class_of "$tmp/merged") == remove ]]
[[ $(class_of "$tmp/open") == keep ]]
[[ $(class_of "$tmp/locked") == keep ]]
[[ $(class_of "$tmp/unpushed") == ask ]]
[[ $(class_of "$tmp/detached") == ask ]]
[[ $(class_of "$bazel/orphan") == remove ]]
[[ $(class_of "$bazel/protected-orphan") == keep ]]
[[ $(jq -r '.extras[0].id' "$plan") == extra:marker ]]

# A worktree that becomes dirty after planning must be skipped.
printf 'changed\n' >>"$tmp/merged/README"
branch_id=$(jq -r --arg repo "$repo" '.items[]|select(.kind=="branch" and .repo==$repo and .path=="merged")|.id' "$plan")
# Read-only orphan bases are made writable and removed in the same apply run.
chmod -R a-w "$bazel/orphan"
[[ ! -e "$tmp/extra-ran" ]]
RESULT_FILE="$tmp/apply-result.json" bash "$scripts/apply.sh" "$plan" "worktree:$tmp/merged" "$branch_id" "output_base:$bazel/orphan" extra:marker >/dev/null
jq -e '.[0].status=="skipped" and (.[0].reason|contains("dirty"))' "$tmp/apply-result.json" >/dev/null
jq -e '.[1].status=="skipped" and (.[1].reason|contains("associated worktree"))' "$tmp/apply-result.json" >/dev/null
jq -e '.[2].status=="removed"' "$tmp/apply-result.json" >/dev/null
jq -e '.[3].status=="removed"' "$tmp/apply-result.json" >/dev/null
[[ ! -e "$bazel/orphan" ]]

# Extras run only when their plan ID is selected.
[[ -f "$tmp/extra-ran" ]]

bash "$scripts/verify.sh" "$plan" >"$tmp/verify.txt"
grep -q 'Disk free (KB): before=' "$tmp/verify.txt"

# With no config, defaults still produce a plan and a suggested config.
mkdir -p "$tmp/empty-bazel"
HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" CLEANUP_WORKTREE_BAZEL_ROOT="$tmp/empty-bazel" XDG_CONFIG_HOME="$tmp/no-config" bash "$scripts/plan.sh" >"$tmp/default-plan.json" 2>"$tmp/default-table.txt"
jq -e '.items|type=="array"' "$tmp/default-plan.json" >/dev/null
grep -q 'Suggested config' "$tmp/default-table.txt"
HOME="$tmp/home" CLEANUP_WORKTREE_BAZEL_ROOT="$tmp/empty-bazel" XDG_CONFIG_HOME="$tmp/no-config" bash "$scripts/plan.sh" --write-config >/dev/null
grep -qx "repos=$repo" "$tmp/no-config/cleanup-worktree-disk/config"
if HOME="$tmp/home" CLEANUP_WORKTREE_BAZEL_ROOT="$tmp/empty-bazel" XDG_CONFIG_HOME="$tmp/no-config" bash "$scripts/plan.sh" --write-config >/dev/null 2>&1; then
	printf 'refused config overwrite unexpectedly succeeded\n' >&2
	exit 1
fi

printf 'cleanup-worktree-disk tests passed\n'
