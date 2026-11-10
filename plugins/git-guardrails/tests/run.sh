#!/bin/bash
# Fixture tests for hooks/git-guardrails.sh under both runners.
# Usage: tests/run.sh
set -u

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/git-guardrails.sh"
fail=0
pass=0

claude_input() { jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
agy_input() { jq -n --arg c "$1" '{toolCall: {name: "run_command", args: {CommandLine: $c}}}'; }

# expect <runner> <deny|allow> <command>
expect() {
	local runner=$1 want=$2 cmd=$3 out rc ok=1
	out=$("${runner}_input" "$cmd" | bash "$HOOK")
	rc=$?
	if [[ $rc -ne 0 ]]; then
		ok=0
	elif [[ $want == allow ]]; then
		[[ -z "$out" ]] || ok=0
	elif [[ $runner == claude ]]; then
		echo "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"
			and (.hookSpecificOutput.permissionDecisionReason | length > 0)
			and (has("decision") | not)' >/dev/null || ok=0
	else
		echo "$out" | jq -e '.decision == "deny" and (.reason | length > 0)
			and (has("hookSpecificOutput") | not)' >/dev/null || ok=0
	fi
	if [[ $ok -eq 1 ]]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		echo "FAIL [$runner] want=$want rc=$rc cmd=$cmd"
		echo "  output: $out"
	fi
}

for runner in claude agy; do
	expect "$runner" deny 'git add .'
	expect "$runner" deny 'git add -A'
	expect "$runner" deny 'git commit --no-verify -m wip'
	expect "$runner" deny 'GITHOOKS_DISABLE=1 git commit -m wip'
	expect "$runner" deny 'find . -name "*.tmp" -delete'
	expect "$runner" allow 'git add README.md'
	expect "$runner" allow 'git commit -m "fix: thing"'
	expect "$runner" allow 'ls -la'
done

# Unknown input shape is allowed without output.
out=$(echo '{}' | bash "$HOOK")
if [[ $? -eq 0 && -z "$out" ]]; then pass=$((pass + 1)); else
	fail=$((fail + 1))
	echo "FAIL empty input: $out"
fi

echo "git-guardrails: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
