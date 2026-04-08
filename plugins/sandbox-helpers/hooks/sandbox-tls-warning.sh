#!/bin/bash
# PreToolUse hook: blocks macOS sandbox TLS failures for Go CLI tools.
#
# On macOS, the Claude Code sandbox blocks the Security framework Mach
# service that Go's crypto/x509 (cgo) uses for TLS cert verification.
# This causes gh, jira, and other Go binaries to fail with cryptic
# x509 OSStatus errors.
#
# When the command invokes a known Go CLI tool, this hook blocks the
# first attempt (exit 2, stderr fed back to Claude) so Claude retries
# with dangerouslyDisableSandbox: true. Subsequent calls in the same
# session are allowed through (exit 0) to avoid infinite blocking.
#
# Exit codes:
#   0 = allow the command
#   2 = block the command (stderr fed back to Claude)

# Only relevant on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
	exit 0
fi

# Read tool input from stdin
INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)

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

# Track warnings per session to allow retry after first block
STATE_FILE="/tmp/claude/sandbox-helpers-${SESSION_ID}.warned"
if [[ -f "$STATE_FILE" ]]; then
	# Already warned in this session — allow the retry
	exit 0
fi

# Mark as warned for this session
mkdir -p /tmp/claude 2>/dev/null
touch "$STATE_FILE" 2>/dev/null

# Block and print diagnostic to stderr (fed back to Claude)
cat >&2 <<'EOF'
sandbox-helpers: TLS issue detected. Claude Code sandbox is active on macOS.
Go binaries like gh/jira cannot verify TLS certs (Security framework blocked).

Retry this command with dangerouslyDisableSandbox: true to run outside the sandbox.
EOF

exit 2
