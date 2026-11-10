#!/usr/bin/env bash
# validate-verdict.sh - Check a fork-keeper verdict.json against the contract.
#
# Usage: validate-verdict.sh <verdict.json> [--candidate-head <sha>]
#
# Exit 0: the verdict is well-formed (and, if "clean", truly eligible for
#         promotion). Exit 1: anything else, with reasons on stderr.
#
# The promotion script (jaeyeom/experimental#598) must treat any non-zero exit
# as "never promote". See ../references/verdict-schema.md.

set -uo pipefail

fail() {
	echo "validate-verdict: $*" >&2
	exit 1
}

[[ $# -ge 1 ]] || fail "usage: validate-verdict.sh <verdict.json> [--candidate-head <sha>]"
file=$1
shift
want_head=""
while [[ $# -gt 0 ]]; do
	case $1 in
	--candidate-head)
		[[ $# -ge 2 ]] || fail "--candidate-head needs a value"
		want_head=$2
		shift 2
		;;
	*) fail "unknown argument: $1" ;;
	esac
done

command -v jq >/dev/null 2>&1 || fail "jq is required"
[[ -f $file ]] || fail "no such file: $file"
jq -e . "$file" >/dev/null 2>&1 || fail "not valid JSON: $file"

# Each rule yields an error string when violated; the list must be empty.
errors=$(jq -r --arg want "$want_head" '
	def sha: type == "string" and test("^[0-9a-f]{40}$");
	def cats: ["secret-leak","destructive","concealment","supply-chain",
		"repo-signal","agent-manipulation","uncertain"];
	. as $v | [
		(if $v.schema != 1 then "schema must be 1" else empty end),
		(if ($v.verdict | IN("clean","needs-review")) | not
			then "verdict must be \"clean\" or \"needs-review\"" else empty end),
		(if ($v.candidate_head | sha) | not then "candidate_head must be a 40-hex sha" else empty end),
		(if ($v.range | type) != "object" then "range must be an object" else empty end),
		(if ($v.range.upstream_old | sha) | not then "range.upstream_old must be a 40-hex sha" else empty end),
		(if ($v.range.upstream_new | sha) | not then "range.upstream_new must be a 40-hex sha" else empty end),
		(if ($v.findings | type) != "array" then "findings must be an array" else empty end),
		(if ($v.conflicts | type) != "array" then "conflicts must be an array" else empty end),
		(($v.findings // [])[]? | select((.category | IN(cats[])) | not)
			| "unknown finding category: \(.category)"),
		(if $want != "" and $v.candidate_head != $want
			then "candidate_head \($v.candidate_head) != expected \($want)" else empty end),
		(if $v.verdict == "clean" then
			(if ($v.findings | length) > 0 then "clean verdict has findings" else empty end),
			(if any(($v.conflicts // [])[]; .confident != true)
				then "clean verdict has an unconfident conflict" else empty end),
			(if $v.range.rewritten != false then "clean verdict but upstream history was rewritten" else empty end),
			(if $v.range.fork_has_merges != false then "clean verdict but fork has merge commits" else empty end),
			(if $v.range.first_run != false then "clean verdict on a first review" else empty end),
			(if ($v.range.moved_tags | length) > 0 then "clean verdict but upstream tags moved" else empty end),
			(if ($v.range.deleted_tags | length) > 0 then "clean verdict but upstream tags were deleted" else empty end)
		else empty end)
	] | .[]' "$file" 2>&1) || fail "could not evaluate $file: $errors"

if [[ -n $errors ]]; then
	while IFS= read -r e; do echo "validate-verdict: $e" >&2; done <<<"$errors"
	exit 1
fi
exit 0
