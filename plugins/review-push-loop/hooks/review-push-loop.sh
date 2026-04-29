#!/bin/bash
# PreToolUse hook: redirects 'git push' to 'review-and-push-loop'.
#
# Rationale: review-and-push-loop reviews each unpushed commit before
# pushing it, and stops at the first blocker. Routing 'git push' through
# the loop makes "review-then-push" the default behavior in agent
# sessions instead of an opt-in step.
#
# Behavior:
#   - 'git push' (plain), 'git push origin <branch>', 'git push -u ...'
#     → deny, suggest 'review-and-push-loop --output compact'
#   - 'git push --tags' / 'git push origin --tags'                 → allow
#   - 'git push --delete ...' / 'git push origin :<branch>'        → allow
#   - 'git push --force' / '-f' / '--force-with-lease'             → deny
#     (force pushes should be explicit; uninstall the plugin or use a
#      tag/delete escape if force push is genuinely needed)
#
# If 'review-and-push-loop' is not on PATH, deny with an install hint
# pointing to the source repo.
#
# Exit codes:
#   0 = decision delivered as JSON on stdout (allow or deny)

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
	exit 0
fi

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

# Only intercept commands that contain 'git push'.
if ! echo "$COMMAND" | grep -qE '\bgit\b[[:space:]]+(-[A-Za-z]+[[:space:]]+|--[A-Za-z-]+(=[^[:space:]]+)?[[:space:]]+)*push\b'; then
	exit 0
fi

# Escape hatch: tag pushes.
if echo "$COMMAND" | grep -qE '(^|[[:space:]])--tags(\b|=)'; then
	exit 0
fi

# Escape hatch: branch deletes via --delete or 'origin :branch' syntax.
if echo "$COMMAND" | grep -qE '(^|[[:space:]])(--delete|-d)(\b|=)'; then
	exit 0
fi
if echo "$COMMAND" | grep -qE '\bgit\b[^|;&]*\bpush\b[^|;&]*[[:space:]]:[A-Za-z0-9._/-]+'; then
	exit 0
fi

INSTALL_HINT="See install instructions at https://github.com/jaeyeom/experimental/tree/main/devtools/reviewpush (README.md and files below it)."

# If the binary is missing, surface install instructions.
if ! command -v review-and-push-loop >/dev/null 2>&1; then
	deny "The review-push-loop plugin redirects 'git push' to 'review-and-push-loop', but that binary is not on PATH. ${INSTALL_HINT} After installing, retry with: review-and-push-loop --output compact"
fi

deny "Use 'review-and-push-loop --output compact' instead of 'git push'. It reviews each unpushed commit and stops at the first blocker. Escape hatches that bypass this hook: 'git push --tags', 'git push --delete <branch>', 'git push origin :<branch>'."
