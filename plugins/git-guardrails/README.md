# git-guardrails

PreToolUse hooks that block dangerous command patterns in Claude Code sessions.

## What it blocks

### Git commands
- **`git commit --no-verify`** — Skipping hooks is not allowed; pre-commit hooks exist for a reason.
- **`git add .`**, **`git add -A`**, **`git add --all`** — Bulk staging may include unrelated or sensitive files. Specify files explicitly instead.

### Find commands
- **`find` with `-exec`, `-execdir`, `-ok`, `-okdir`, `-delete`, `-fls`, `-fprint`, `-fprint0`, `-fprintf`** — These options can execute arbitrary commands or modify files. Use Claude Code's dedicated tools (Glob, Grep, Read) instead.

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install git-guardrails
```

## How it works

The plugin registers a `PreToolUse` hook on the `Bash` tool. Before any shell command executes, the hook parses the command string and blocks it (exit code 2 with a JSON reason) if it matches a dangerous pattern. Safe commands pass through with no overhead beyond a fast string check.

## Replaces

This plugin replaces the following shell shims:
- `~/.local/shims/bin/git` — git commit --no-verify and git add . blocking
- `~/.local/shims/bin/find` — find -exec/-delete blocking

The plugin approach is cleaner because:
- No PATH ordering dependency
- Works even if Claude uses an absolute path to the binary
- Fires before the command runs (not after binary resolution)
- Centrally managed and version-controlled
