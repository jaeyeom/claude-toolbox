#!/bin/bash
# PreToolUse hook: warns about macOS sandbox TLS failures for Go CLI tools.
#
# Replaces the gh shim (~/.local/shims/bin/gh) with a Claude Code
# PreToolUse hook. On macOS, the Claude Code sandbox blocks the Security
# framework Mach service that Go's crypto/x509 (cgo) uses for TLS cert
# verification. This causes gh, jira, and other Go binaries to fail with
# cryptic x509 OSStatus errors.
#
# When the command invokes a known Go CLI tool, this hook outputs a JSON
# warning explaining the cause and workarounds. The dangerouslyDisableSandbox
# flag is NOT checked because excludedCommands sets it yet the sandbox still
# blocks Security framework access needed for TLS cert verification.
#
# Exit codes:
#   0 = allow the command (with optional warning via JSON output)

# Only relevant on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
	exit 0
fi

# Read tool input from stdin
INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
	exit 0
fi

# Check if command uses Go CLI tools affected by sandbox TLS
if ! echo "$COMMAND" | grep -qE '\b(gh|jira)\b'; then
	exit 0
fi

# Skip subcommands that don't need network access
if echo "$COMMAND" | grep -qE '\bgh\s+(help|completion|alias)\b'; then
	exit 0
fi

# Output JSON warning — allow the command to proceed so the user
# sees both the warning and the actual TLS error (which triggers Claude
# to retry with dangerouslyDisableSandbox: true).
MESSAGE="sandbox-helpers: TLS issue detected. Claude Code sandbox is active on macOS. Go binaries like gh/jira cannot verify TLS certs (Security framework blocked by sandbox). Workarounds: (1) Retry with dangerouslyDisableSandbox: true, (2) Use /sandbox to manage sandbox restrictions, (3) Use curl with \$GH_TOKEN as a fallback."

# PreToolUse hooks must output JSON to be visible to Claude
jq -n --arg msg "$MESSAGE" '{
  continue: true,
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  }
}'

exit 0
