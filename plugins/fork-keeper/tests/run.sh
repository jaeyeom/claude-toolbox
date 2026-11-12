#!/bin/bash
# jq programs use $vars bound by --arg, so single quotes are intended.
# shellcheck disable=SC2016
# Fixture tests for fork-keeper's helper scripts.
# Usage: plugins/fork-keeper/tests/run.sh
set -u

# shellcheck source=plugins/fork-keeper/tests/lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

# ---------------------------------------------------------------- review-range

test_first_run_uses_merge_base() {
	mk_fixture
	local u0 out
	u0=$(g "$FX/fork" rev-parse HEAD)
	fcommit mine.txt P1 >/dev/null
	ucommit up.txt U1 >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.first_run == true and .upstream_old == $u0 and .up_to_date == false' --arg u0 "$u0"
}

test_up_to_date() {
	mk_fixture
	fcommit mine.txt P1 >/dev/null
	refresh
	assert_json "$(run_rr)" '.up_to_date == true'
}

test_normal_range_uses_recorded_head() {
	mk_fixture
	local u1 out
	fcommit mine.txt P1 >/dev/null
	u1=$(ucommit up.txt U1)
	sync_fork
	ucommit up.txt U2 >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.first_run == false and .upstream_old == $u1 and .review_base == $u1 and .rewritten == false and .fork_behind_recorded_head == false' --arg u1 "$u1"
}

test_rewrite_detected() {
	mk_fixture
	local u1 out
	u1=$(ucommit up.txt U1)
	ucommit up.txt U2 >/dev/null
	sync_fork
	g "$FX/useed" reset -q --hard "$u1"
	ucommit up.txt U2-rewritten >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.rewritten == true and .review_base == $u1' --arg u1 "$u1"
}

test_upstream_merged_patch_dropped_from_user_commits() {
	mk_fixture
	local p2 out
	fcommit p1.txt P1 >/dev/null
	p2=$(fcommit p2.txt P2)
	# Upstream takes P1 verbatim (same patch-id, different commit).
	echo P1 >>"$FX/useed/p1.txt"
	g "$FX/useed" add p1.txt
	g "$FX/useed" commit -q -m "P1 (upstreamed)"
	g "$FX/useed" push -q origin "HEAD:$BR"
	refresh
	out=$(run_rr)
	assert_json "$out" '.user_commits == [$p2]' --arg p2 "$p2"
}

test_fork_merge_commits_reported() {
	mk_fixture
	g "$FX/fork" checkout -q -b side
	echo side >"$FX/fork/side.txt"
	g "$FX/fork" add side.txt
	g "$FX/fork" commit -q -m side
	g "$FX/fork" checkout -q "$BR"
	g "$FX/fork" merge -q --no-ff -m merge side
	g "$FX/fork" push -q origin "HEAD:$BR"
	ucommit up.txt U1 >/dev/null
	refresh
	assert_json "$(run_rr)" '.fork_has_merges == true'
}

test_moved_tag_detected() {
	mk_fixture
	local u1 u2
	u1=$(ucommit up.txt U1)
	g "$FX/useed" tag v1 "$u1"
	g "$FX/useed" push -q origin v1
	sync_fork
	g "$FX/fork" update-ref refs/fork-keeper/upstream-tags/v1 "$u1"
	u2=$(ucommit up.txt U2)
	g "$FX/useed" tag -f v1 "$u2" >/dev/null
	g "$FX/useed" push -q -f origin v1
	refresh
	assert_json "$(run_rr)" '.moved_tags == [{"name":"v1","was":$u1,"now":$u2}]' --arg u1 "$u1" --arg u2 "$u2"
}

test_deleted_tag_detected() {
	mk_fixture
	local u1
	u1=$(ucommit up.txt U1)
	sync_fork
	g "$FX/fork" update-ref refs/fork-keeper/upstream-tags/v0 "$u1"
	assert_json "$(run_rr)" '.deleted_tags == ["v0"] and .moved_tags == []'
}

test_master_branch() {
	mk_fixture master
	local u0 out
	u0=$(g "$FX/fork" rev-parse HEAD)
	fcommit mine.txt P1 >/dev/null
	ucommit up.txt U1 >/dev/null
	refresh
	out=$(run_rr -b master)
	assert_json "$out" '.first_run == true and .upstream_old == $u0 and .up_to_date == false' --arg u0 "$u0"
}

test_default_branch_from_origin_head() {
	mk_fixture master
	local u0 out
	u0=$(g "$FX/fork" rev-parse HEAD)
	ucommit up.txt U1 >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.branch == "master" and .upstream_old == $u0 and .up_to_date == false' --arg u0 "$u0"
}

test_explicit_branch_overrides_origin_head() {
	mk_fixture master
	g "$FX/fork" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/nonexistent
	assert_json "$(run_rr -b master)" '.branch == "master"'
}

test_missing_origin_head_exits_2() {
	mk_fixture
	g "$FX/fork" symbolic-ref --delete refs/remotes/origin/HEAD
	run_rr >/dev/null 2>&1
	assert_rc 2 $?
}

test_missing_upstream_ref_exits_2() {
	mk_fixture
	g "$FX/fork" remote remove upstream
	run_rr >/dev/null 2>&1
	assert_rc 2 $?
}

test_rewrite_after_sync_excludes_removed_upstream_commits() {
	mk_fixture
	local u1 p1 out
	u1=$(ucommit up.txt U1)
	ucommit up.txt U2 >/dev/null
	refresh
	g "$FX/fork" merge -q --ff-only upstream/main
	p1=$(fcommit mine.txt P1)
	refresh
	record_head "$(g "$FX/fork" rev-parse upstream/main)"
	# Upstream scrubs U2 (e.g. after a compromise) and adds U3.
	g "$FX/useed" reset -q --hard "$u1"
	ucommit other.txt U3 >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.rewritten == true and .user_commits == [$p1]' --arg p1 "$p1"
}

test_fork_behind_recorded_head_flagged() {
	mk_fixture
	local u0 out
	u0=$(g "$FX/fork" rev-parse HEAD)
	ucommit up.txt U1 >/dev/null
	ucommit up.txt U2 >/dev/null
	refresh
	# Recorded head says U2 was reviewed, but the fork (rolled back) is at U0.
	record_head "$(g "$FX/fork" rev-parse upstream/main)"
	ucommit up.txt U3 >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.fork_behind_recorded_head == true and .review_base == $u0' --arg u0 "$u0"
}

# ------------------------------------------------------------- validate-verdict

H40=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
B40=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
C40=cccccccccccccccccccccccccccccccccccccccc

# mk_verdict <jq-update>: write a verdict (valid clean baseline + update); prints path.
mk_verdict() {
	local f
	f="$(mktemp "$FK_TEST_HOME/verdict.XXXXXX")"
	jq -n --arg h "$H40" --arg b "$B40" --arg c "$C40" '{
		schema: 1, verdict: "clean", candidate_head: $h,
		range: {upstream_old: $b, upstream_new: $c, first_run: false,
			up_to_date: false, rewritten: false, review_base: $b,
			user_commits: [$h], fork_has_merges: false,
			fork_behind_recorded_head: false,
			moved_tags: [], deleted_tags: []},
		conflicts: [], findings: [], summary: "looks safe"
	} | '"${1:-.}" >"$f"
	echo "$f"
}

FINDING='{"category":"secret-leak","file":"install.sh","line":3,"commit":"'$C40'","summary":"sends ~/.ssh to a remote host"}'

run_vv() { bash "$VV" "$@" >/dev/null 2>&1; }

test_valid_clean_passes() {
	run_vv "$(mk_verdict)"
	assert_rc 0 $?
}

test_valid_needs_review_passes() {
	run_vv "$(mk_verdict '.verdict = "needs-review" | .findings = ['"$FINDING"']')"
	assert_rc 0 $?
}

test_clean_with_findings_fails() {
	run_vv "$(mk_verdict '.findings = ['"$FINDING"']')"
	assert_rc 1 $?
}

test_clean_with_unconfident_conflict_fails() {
	run_vv "$(mk_verdict '.conflicts = [{commit: $h, files: ["a.el"], confident: false}]')"
	assert_rc 1 $?
}

test_clean_with_rewrite_fails() {
	run_vv "$(mk_verdict '.range.rewritten = true')"
	assert_rc 1 $?
}

test_clean_with_moved_tag_fails() {
	run_vv "$(mk_verdict '.range.moved_tags = [{name: "v1", was: $b, now: $c}]')"
	assert_rc 1 $?
}

test_clean_with_deleted_tag_fails() {
	run_vv "$(mk_verdict '.range.deleted_tags = ["v0"]')"
	assert_rc 1 $?
}

test_clean_with_fork_merges_fails() {
	run_vv "$(mk_verdict '.range.fork_has_merges = true')"
	assert_rc 1 $?
}

test_clean_on_first_run_fails() {
	run_vv "$(mk_verdict '.range.first_run = true')"
	assert_rc 1 $?
}

test_unknown_category_fails() {
	run_vv "$(mk_verdict '.verdict = "needs-review" | .findings = [('"$FINDING"' | .category = "style")]')"
	assert_rc 1 $?
}

test_unknown_verdict_value_fails() {
	run_vv "$(mk_verdict '.verdict = "approved"')"
	assert_rc 1 $?
}

test_bad_sha_fails() {
	run_vv "$(mk_verdict '.candidate_head = "HEAD"')"
	assert_rc 1 $?
}

test_missing_file_fails() {
	run_vv "$FK_TEST_HOME/does-not-exist.json"
	assert_rc 1 $?
}

test_not_json_fails() {
	local f="$FK_TEST_HOME/garbage.json"
	echo "Sure! Here is the verdict: clean" >"$f"
	run_vv "$f"
	assert_rc 1 $?
}

test_candidate_head_mismatch_fails() {
	run_vv "$(mk_verdict)" --candidate-head "$B40"
	assert_rc 1 $?
}

test_candidate_head_match_passes() {
	run_vv "$(mk_verdict)" --candidate-head "$H40"
	assert_rc 0 $?
}

test_clean_missing_moved_tags_fails() {
	run_vv "$(mk_verdict 'del(.range.moved_tags)')"
	assert_rc 1 $?
}

test_clean_null_deleted_tags_fails() {
	run_vv "$(mk_verdict '.range.deleted_tags = null')"
	assert_rc 1 $?
}

test_clean_fork_behind_fails() {
	run_vv "$(mk_verdict '.range.fork_behind_recorded_head = true')"
	assert_rc 1 $?
}

test_clean_missing_fork_behind_fails() {
	run_vv "$(mk_verdict 'del(.range.fork_behind_recorded_head)')"
	assert_rc 1 $?
}

test_bad_user_commits_fails() {
	run_vv "$(mk_verdict '.range.user_commits = "abc"')"
	assert_rc 1 $?
}

test_empty_candidate_head_arg_fails() {
	run_vv "$(mk_verdict)" --candidate-head ""
	assert_rc 1 $?
}

test_multiple_json_values_fails() {
	local f g
	f=$(mk_verdict)
	g="$FK_TEST_HOME/two-values.json"
	{
		cat "$f"
		jq -c '.candidate_head = $b' --arg b "$B40" "$f"
	} >"$g"
	run_vv "$g"
	assert_rc 1 $?
}

test_range_mismatch_fails() {
	local v r
	v=$(mk_verdict)
	r="$FK_TEST_HOME/range-mismatch.json"
	jq '.range | .rewritten = true' "$v" >"$r"
	run_vv "$v" --range "$r"
	assert_rc 1 $?
}

test_range_match_passes() {
	local v r
	v=$(mk_verdict)
	r="$FK_TEST_HOME/range-match.json"
	jq '.range' "$v" >"$r"
	run_vv "$v" --range "$r"
	assert_rc 0 $?
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
	# shellcheck disable=SC2034 # read by the assert helpers in lib.sh
	CUR=$t
	"$t"
done

finish
