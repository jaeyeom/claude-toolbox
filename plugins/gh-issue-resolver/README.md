# gh-issue-resolver

A Claude Code skill for resolving GitHub issues end-to-end using the `gh` CLI.

## What It Does

- Reads a GitHub issue and understands the requirements
- Checks for blocking sub-issues or task list dependencies
- Self-assigns the issue and labels it "in progress"
- Searches the codebase for references to the issue number (TODOs, FIXMEs, etc.)
- Investigates and implements the fix
- Reviews changes for quality (no unnecessary comments, no debug code)
- Commits with a message that references the issue for auto-close on merge

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- A Git repository with a GitHub remote

## Install

```bash
claude mcp add-plugin github:jaeyeom/claude-toolbox/plugins/gh-issue-resolver
```

## Usage

```
/gh-issue-resolver 42
```

Or describe the task naturally:

```
Resolve GitHub issue #42
```

## Workflow

1. **Read** — Fetches the issue via `gh issue view`
2. **Block check** — Parses body for unchecked task list items (`- [ ] #N`); rejects if any are open
3. **In progress** — Assigns to self, adds "in progress" label
4. **Investigate** — Searches codebase with `rg` for `#N` and `issues/N` references
5. **Resolve** — Makes code changes following the issue description and TODO pointers
6. **Review** — Checks for unnecessary comments and code quality
7. **Commit** — Creates a commit with `Resolves #N` for automatic issue closure on merge

The issue is intentionally left open — it closes automatically when the fix is merged.
