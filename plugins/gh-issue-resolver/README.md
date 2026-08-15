# gh-issue-resolver

A Claude Code skill for resolving GitHub issues end-to-end using the `gh` CLI.

## What It Does

- Reads a GitHub issue and treats its plan as the execution contract
- Uses the issue's acceptance criteria as the definition of done
- Checks for blocking sub-issues or task list dependencies
- Self-assigns the issue and labels it "in progress"
- Searches the codebase for references to the issue number (TODOs, FIXMEs, etc.)
- Executes the written plan; stops and asks before any deviation
- After an approved deviation, proposes a surgical issue-body edit and waits for a second yes
- Reviews changes against the acceptance criteria
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

1. **Read** — Fetches the issue via `gh issue view` and extracts the plan and acceptance criteria
2. **Block check** — Parses body for unchecked task list items (`- [ ] #N`); rejects if any are open
3. **In progress** — Assigns to self, adds "in progress" label
4. **Execute** — Follows the written plan; codebase search locates planned change sites
5. **Deviation gate** — If reality differs from the plan, stops and waits for a first yes
6. **Issue update** — After an approved deviation, proposes a surgical body edit and waits for a second yes
7. **Review** — Checks completeness against the acceptance criteria
8. **Commit** — Creates a commit with `Resolves #N` for automatic issue closure on merge

The issue is intentionally left open — it closes automatically when the fix is merged.
