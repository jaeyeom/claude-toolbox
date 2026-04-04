#!/bin/bash
# PreToolUse hook: warns about macOS sandbox TLS failures for Go CLI tools.
#
# Replaces the gh shim (~/.local/shims/bin/gh) with a Claude Code
# PreToolUse hook. On macOS, the Claude Code sandbox blocks the Security
# framework Mach service that Go's crypto/x509 (cgo) uses for TLS cert
# verification. This causes gh, jira, and other Go binaries to fail with
# cryptic x509 OSStatus errors.
#
# When the sandbox is active (dangerouslyDisableSandbox is not true) and
# the command invokes a known Go CLI tool, this hook prints a diagnostic
# warning to stderr explaining the cause and workarounds.
#
# Exit codes:
#   0 = allow the command (with optional warning on stderr)

# Only relevant on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
	exit 0
fi

# Read tool input from stdin
INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
SANDBOX_DISABLED=$(echo "$INPUT" | jq -r '.tool_input.dangerouslyDisableSandbox // false' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
	exit 0
fi

# If sandbox is already disabled for this call, no warning needed
if [[ "$SANDBOX_DISABLED" == "true" ]]; then
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

# Print diagnostic warning — allow the command to proceed so the user
# sees both the warning and the actual TLS error (which triggers Claude
# to retry with dangerouslyDisableSandbox: true).
echo "" >&2
echo "╭─ sandbox-helpers: TLS issue detected ──────────────────────╮" >&2
echo "│ Claude Code sandbox is active on macOS. Go binaries like   │" >&2
echo "│ gh/jira cannot verify TLS certs (Security framework        │" >&2
echo "│ blocked by sandbox).                                       │" >&2
echo "│                                                            │" >&2
echo "│ Workarounds:                                               │" >&2
echo "│   1. Retry with dangerouslyDisableSandbox: true            │" >&2
echo "│   2. Use /sandbox to manage sandbox restrictions           │" >&2
echo "│   3. Use curl with \$GH_TOKEN as a fallback:               │" >&2
echo "│      curl -sH \"Authorization: bearer \$GH_TOKEN\" \\         │" >&2
echo "│        https://api.github.com/...                         │" >&2
echo "╰────────────────────────────────────────────────────────────╯" >&2

exit 0
