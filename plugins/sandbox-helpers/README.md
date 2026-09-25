# sandbox-helpers

PreToolUse hook that blocks the first macOS sandbox failure for Go CLI tools (`gh`, `jira`, and `circleci`) in a Claude Code session.

## Problem

On macOS, the Claude Code sandbox blocks the Security framework Mach service that Go's `crypto/x509` uses for TLS certificate verification. `gh`, `jira`, and `circleci` then fail with:

```text
tls: failed to verify certificate: x509: OSStatus -26276
```

`curl` to the same host succeeds. For `circleci`, two other sandbox failures show up first:

- `circleci version`, `circleci help`, and `circleci config pack` exit with `getting boot time: operation not permitted`. `circleci completion` does not.
- If `circleci.com` is missing from the sandbox allowlist, the proxy returns `Forbidden` before certificate verification. The `x509` line appears only after the host is allowed.

An unsandboxed retry clears both the boot-time error and the TLS failure. Reproduced on macOS 26.6 with Claude Code 2.1.282 and `circleci` 1.0.50961.

## What it does

On macOS, the first Bash command in a session that invokes `gh`, `jira`, or `circleci` is blocked (exit 2). Stderr tells Claude to retry with `dangerouslyDisableSandbox: true`. Later calls in that session are allowed through.

The `circleci` match is the CLI token, including an absolute path such as `/opt/homebrew/bin/circleci`. It does not match the `.circleci/` directory or the `circleci-cli` name, so `cat .circleci/config.yml` is left alone.

Excluded subcommands:

- `gh help`, `gh completion`, `gh alias`
- `circleci completion`

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
