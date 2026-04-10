#!/bin/bash
# PreToolUse hook: blocks jira issue create without -p/--project flag.
#
# The jira CLI uses a default project from ~/.config/.jira/.config.yml when
# -p is not specified. This causes issues when using -P (parent epic) from a
# different project — the issue gets silently created in the wrong project.
#
# Blocked pattern:
#   - jira issue create without -p/--project or -P/--parent
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

# --- jira issue create without -p/--project ---
if echo "$COMMAND" | grep -qE '\bjira\b[^|;]*\bissue\b[^|;]*\bcreate\b'; then
	if ! echo "$COMMAND" | grep -qE '\bjira\b[^|;]*\bissue\b[^|;]*\bcreate\b[^|;]*(\s-p\s|\s-p[^-\s]|--project\b|\s-P\s|\s-P[^-\s]|--parent\b)'; then
		deny "jira issue create must include -p/--project or -P/--parent flag. Relying on the default project is error-prone (see ankitpokhrel/jira-cli#979)."
	fi
fi

exit 0
