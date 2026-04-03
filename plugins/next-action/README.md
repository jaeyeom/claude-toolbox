# next-action

Find the next highest-priority action to work on by scanning multiple task
sources.

## Features

- **Multi-source scanning** — Checks local TODO files (`TODO.md`, `TASKS.md`,
  etc.) and GitHub Issues via the `gh` CLI.
- **Priority ranking** — Scores candidates by priority labels, section headers,
  and inline markers to recommend the most impactful task.
- **Blocker detection** — Identifies blocked items via `BLOCKED BY` markers in
  TODO files and blocking issue relationships (sub-issues, `depends on #N`) in
  GitHub Issues.
- **Staleness checking** — Verifies that referenced files, functions, and issues
  still exist before recommending a task.
- **Configurable sources** — Reads task source configuration from `CLAUDE.md` so
  you can point it at custom TODO paths, specific labels, or filtered issue
  queries.
- **Suggest-only** — Presents the recommendation and waits for confirmation
  before starting any work.

## Usage

```
/next-action            # Scan all configured sources
/next-action todo       # Only check local TODO files
/next-action github     # Only check GitHub Issues
```

## Task Source Configuration

Add a section to your project's `CLAUDE.md` to customize where the skill looks
for tasks:

```markdown
## Task Sources
- Local: TODO.md
- GitHub Issues: assigned to @me, state open, label "ready"
```

If no configuration is found, the skill discovers sources automatically and
suggests a `CLAUDE.md` update.

## Requirements

- **GitHub Issues**: `gh` CLI installed and authenticated (`gh auth status`).
- **Local TODO files**: Markdown format with checkbox items (`- [ ] ...`).
