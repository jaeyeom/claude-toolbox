# sandbox-helpers

PreToolUse hook that warns about macOS sandbox TLS failures when Go CLI tools (gh, jira) are invoked.

## Problem

On macOS, the Claude Code sandbox blocks the Security framework Mach service that Go's `crypto/x509` (cgo) uses for TLS certificate verification. This causes `gh`, `jira`, and other Go binaries to fail with cryptic `x509 OSStatus` errors.

## What it does

When a Bash command invokes `gh` or `jira` without `dangerouslyDisableSandbox: true`, the hook prints a diagnostic warning to stderr explaining:
- Why the command will fail (sandbox blocks Security framework)
- How to fix it (retry with sandbox disabled, use `/sandbox`, or use `curl` with `$GH_TOKEN`)

The hook **warns but does not block** — the command proceeds so Claude sees both the warning and the actual TLS error, which triggers an automatic retry with `dangerouslyDisableSandbox: true`.

Network-free subcommands (`gh help`, `gh completion`, `gh alias`) are excluded from warnings.

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install sandbox-helpers
```

## Replaces

This plugin replaces the `~/.local/shims/bin/gh` shell shim.

### What about the claude wrapper shim?

The `~/.local/shims/bin/claude` shim sets environment variables (`GH_TOKEN`, `SSL_CERT_FILE`, `TMPDIR`, `GOCACHE`, `GOLANGCI_LINT_CACHE`) before launching Claude Code. This **cannot** be replaced by a plugin hook because hooks run inside the already-started Claude session and cannot modify the parent process environment.

Options for the env-var setup:
1. **Keep a slim claude wrapper** that only handles env-var exports (recommended)
2. **Set env vars in shell profile** (`.zshrc` / `.bashrc`)
3. **Ansible playbook** that configures the shell environment
