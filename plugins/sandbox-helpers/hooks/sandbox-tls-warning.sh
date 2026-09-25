#!/bin/bash
# PreToolUse hook: blocks macOS sandbox TLS failures for Go CLI tools.
#
# On macOS, the Claude Code sandbox blocks the Security framework Mach
# service that Go's crypto/x509 uses for TLS cert verification. This
# causes gh, jira, and circleci to fail with x509 OSStatus errors.
# circleci version, circleci help, and circleci config pack also fail
# earlier, while reading boot time. circleci completion does not.
#
# When the command invokes one of these tools, this hook blocks the
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

# gh/jira. Skip gh subcommands that do not need network access. A gh
# help/completion/alias on the same line suppresses the gh/jira warning.
warn_gh_jira=0
if echo "$COMMAND" | grep -qE '\b(gh|jira)\b'; then
	if ! echo "$COMMAND" | grep -qE '\bgh\s+(help|completion|alias)\b'; then
		warn_gh_jira=1
	fi
fi

# circleci the CLI. Do not treat .circleci/ or circleci-cli as the binary.
# circleci completion stays inside the sandbox; other subcommands do not.
warn_circleci=0
circleci_re='(^|[^[:alnum:]._-])circleci([^[:alnum:]._-]|$)'
completion_re='(^|[^[:alnum:]._-])circleci[[:space:]]+completion([^[:alnum:]._-]|$)'
circleci_for_match=$(printf '%s\n' "$COMMAND" | sed -E "s/${completion_re}/\\1/g")
if printf '%s\n' "$circleci_for_match" | grep -qE "$circleci_re"; then
	warn_circleci=1
fi

if [[ "$warn_gh_jira" -eq 0 && "$warn_circleci" -eq 0 ]]; then
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
if [[ "$warn_circleci" -eq 1 ]]; then
	cat >&2 <<'EOF'
sandbox-helpers: Claude Code sandbox is active on macOS.
circleci is a Go binary and cannot verify TLS certs (Security framework blocked).

circleci version, circleci help, and circleci config pack fail inside the sandbox
with "getting boot time: operation not permitted". circleci completion does not.

If circleci.com is not on the sandbox allowlist, the proxy returns Forbidden
before certificate verification. Once the host is allowed, the error is
"tls: failed to verify certificate: x509: OSStatus -26276".

Retry this command with dangerouslyDisableSandbox: true. That clears both
the boot-time error and the TLS failure.
EOF
	if [[ "$warn_gh_jira" -eq 1 ]]; then
		cat >&2 <<'EOF'

gh/jira on this command line hit the same TLS failure. The unsandboxed retry covers them too.
EOF
	fi
else
	cat >&2 <<'EOF'
sandbox-helpers: TLS issue detected. Claude Code sandbox is active on macOS.
Go binaries like gh/jira cannot verify TLS certs (Security framework blocked).

Retry this command with dangerouslyDisableSandbox: true to run outside the sandbox.
EOF
fi

exit 2
