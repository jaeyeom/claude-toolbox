#!/bin/bash
# PreToolUse hook: blocks dangerous git and find command patterns.
#
# Replaces the git shim (~/.local/shims/bin/git) and find shim
# (~/.local/shims/bin/find) with a Claude Code PreToolUse hook.
#
# Blocked patterns:
#   - git commit --no-verify  (skips hooks)
#   - git add . / -A / --all  (stages unrelated files)
#   - find -exec/-execdir/-ok/-okdir/-delete/-fls/-fprint/-fprint0/-fprintf
#
# Exit codes:
#   0 = allow the command
#   2 = block the command (JSON on stdout with decision + reason)

# Read tool input from stdin
INPUT=$(cat)

# Parse the command from tool input JSON
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
	exit 0
fi

# Helper: output a PreToolUse deny decision as JSON
deny() {
	jq -n --arg reason "$1" '{
		continue: true,
		hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "deny",
			permissionDecisionReason: $reason
		}
	}'
	exit 0
}

# --- git commit --no-verify ---
if echo "$COMMAND" | grep -qE '\bgit\b[^|;]*\bcommit\b[^|;]*--no-verify'; then
	deny "The --no-verify flag is not allowed. Please run git commit without --no-verify to ensure hooks are executed. There is an absolute reason for this."
fi

# --- git add . / -A / --all ---
if echo "$COMMAND" | grep -qE '\bgit\b\s+add\s+(\.|(-A|--all))(\s|$|;|\|)'; then
	deny "'git add .', 'git add -A', and 'git add --all' may stage unrelated files. Please specify files explicitly, e.g.: git add file1.txt file2.txt. Use 'git status' to see what would be added."
fi

# --- find with dangerous options ---
if echo "$COMMAND" | grep -qE '\bfind\b'; then
	BLOCKED_OPTS=(-exec -execdir -ok -okdir -delete -fls -fprint -fprint0 -fprintf)
	for opt in "${BLOCKED_OPTS[@]}"; do
		if echo "$COMMAND" | grep -qE "(^|\s)${opt}(\s|$)"; then
			deny "The '${opt}' option for find is not allowed in AI assistant context. These options can execute commands or modify files. Use dedicated tools (Glob, Grep, Read) instead."
		fi
	done
fi

exit 0
