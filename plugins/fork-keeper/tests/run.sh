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
	refresh
	record_head "$u1"
	ucommit up.txt U2 >/dev/null
	refresh
	out=$(run_rr)
	assert_json "$out" '.first_run == false and .upstream_old == $u1 and .review_base == $u1 and .rewritten == false' --arg u1 "$u1"
}

test_rewrite_detected() {
	mk_fixture
	local u1 u2 out
	u1=$(ucommit up.txt U1)
	u2=$(ucommit up.txt U2)
	refresh
	record_head "$u2"
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
	refresh
	record_head "$u1"
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
	refresh
	record_head "$u1"
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

test_missing_upstream_ref_exits_2() {
	mk_fixture
	g "$FX/fork" remote remove upstream
	run_rr >/dev/null 2>&1
	assert_rc 2 $?
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
	CUR=$t
	"$t"
done

finish
