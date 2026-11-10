# shellcheck shell=bash
# Fixture helpers for fork-keeper tests. Source from tests/run.sh.
#
# A fixture is a temp dir holding:
#   upstream.git  bare upstream
#   origin.git    bare fork (starts as a copy of upstream)
#   useed/        working clone of upstream, used to author upstream commits
#   fork/         working clone of origin.git with an `upstream` remote

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../skills/fork-keeper/scripts" && pwd)"
RR="$SCRIPTS_DIR/review-range.sh"
# shellcheck disable=SC2034 # used by tests/run.sh
VV="$SCRIPTS_DIR/validate-verdict.sh"

# Isolate git from the user's global config (identity, shared hooks).
FK_TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/fork-keeper-tests.XXXXXX")"
mkdir -p "$FK_TEST_HOME/nohooks"
cat >"$FK_TEST_HOME/gitconfig" <<EOF
[user]
	name = Fork Keeper Test
	email = fork-keeper@example.invalid
[core]
	hooksPath = $FK_TEST_HOME/nohooks
[init]
	defaultBranch = main
[advice]
	detachedHead = false
EOF
export GIT_CONFIG_GLOBAL="$FK_TEST_HOME/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
trap 'rm -rf "$FK_TEST_HOME"' EXIT

FX="" # current fixture dir
BR="main"

g() { git -C "$1" "${@:2}"; }

# mk_fixture [branch]: fresh fixture with one upstream commit U0.
mk_fixture() {
	BR="${1:-main}"
	FX="$(mktemp -d "$FK_TEST_HOME/fx.XXXXXX")"
	git init -q --bare -b "$BR" "$FX/upstream.git"
	git init -q --bare -b "$BR" "$FX/origin.git"
	git clone -q "$FX/upstream.git" "$FX/useed" 2>/dev/null
	g "$FX/useed" checkout -q -b "$BR" 2>/dev/null || true
	echo base >"$FX/useed/README"
	g "$FX/useed" add README
	g "$FX/useed" commit -q -m U0
	g "$FX/useed" push -q origin "$BR"
	g "$FX/useed" push -q "$FX/origin.git" "$BR"
	git clone -q -b "$BR" "$FX/origin.git" "$FX/fork"
	g "$FX/fork" remote add upstream "$FX/upstream.git"
	refresh
}

# ucommit <file> <msg>: commit on upstream; prints sha.
ucommit() {
	echo "$2" >>"$FX/useed/$1"
	g "$FX/useed" add "$1"
	g "$FX/useed" commit -q -m "$2"
	g "$FX/useed" push -q -f origin "HEAD:$BR"
	g "$FX/useed" rev-parse HEAD
}

# fcommit <file> <msg>: commit on the fork and push to origin; prints sha.
fcommit() {
	echo "$2" >>"$FX/fork/$1"
	g "$FX/fork" add "$1"
	g "$FX/fork" commit -q -m "$2"
	g "$FX/fork" push -q origin "HEAD:$BR"
	g "$FX/fork" rev-parse HEAD
}

# refresh: fetch the way the pre-check does.
refresh() {
	g "$FX/fork" fetch -q origin
	g "$FX/fork" fetch -q --no-tags --prune upstream \
		"+refs/heads/*:refs/remotes/upstream/*" \
		"+refs/tags/*:refs/upstream-tags/*"
}

record_head() { g "$FX/fork" update-ref refs/fork-keeper/upstream-head "$1"; }

# sync_fork: do what a promoted sync leaves behind -- the fork's default
# branch is the user's stack rebased on upstream, and upstream-head records
# the upstream it was built on.
sync_fork() {
	refresh
	g "$FX/fork" rebase -q "upstream/$BR" >/dev/null
	g "$FX/fork" push -q -f origin "HEAD:$BR"
	refresh
	record_head "$(g "$FX/fork" rev-parse "upstream/$BR")"
}

# run_rr [args]: run review-range.sh in the fork; JSON on stdout.
run_rr() { (cd "$FX/fork" && bash "$RR" "$@"); }

pass=0
fail=0
CUR=""

ok() { pass=$((pass + 1)); }
bad() {
	fail=$((fail + 1))
	echo "FAIL [$CUR] $*"
}

# assert_json <json> <jq-boolean-expr> [--arg k v ...]
assert_json() {
	local json=$1 expr=$2
	shift 2
	if echo "$json" | jq -e "$@" "$expr" >/dev/null 2>&1; then ok; else
		bad "jq '$expr' on: $json"
	fi
}

assert_rc() {
	local want=$1 got=$2
	if [[ $want -eq $got ]]; then ok; else bad "want rc=$want got rc=$got"; fi
}

finish() {
	echo "fork-keeper tests: $pass passed, $fail failed"
	[[ $fail -eq 0 ]]
}
