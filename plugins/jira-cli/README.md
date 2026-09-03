# Jira CLI

Claude Code skills for common Jira operations using the `jira` CLI tool.

## Prerequisites

- [jira CLI](https://github.com/ankitpokhrel/jira-cli) installed and configured

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install jira-cli
```

## Skills

### Issue Creation

- `/jira-cli:new-task PROJECT` — Create a task in the given project
- `/jira-cli:new-task PROJ-123` — Create a task under an epic
- `/jira-cli:new-bug PROJECT` — Create a bug report in the given project
- `/jira-cli:new-bug PROJ-123` — Create a bug under an epic

### Issue Management

- `/jira-cli:resolve PROJ-123` — Investigate and resolve a Jira issue
- `/jira-cli:update PROJ-123` — Update a ticket description after investigation
- `/jira-cli:edit-description PROJ-123` — Edit a description with wiki markup guidance

### Project Planning

- `/jira-cli:plan-project path/to/design.md` — Plan a project with Jira tasks

## Hook

A `PreToolUse` hook on `Bash` denies `jira issue create` unless the command
includes `-p`/`--project` or `-P`/`--parent`.

The jira CLI falls back to the default project in
`~/.config/.jira/.config.yml` when those flags are omitted. That silently
creates the issue in the wrong project when a parent epic lives in a
different project
([jira-cli#979](https://github.com/ankitpokhrel/jira-cli/issues/979)).

Allowed through:

- `jira issue create -p PROJ ...` / `--project PROJ`
- `jira issue create -P PROJ-123 ...` / `--parent PROJ-123`

Denied:

- `jira issue create` with no project or parent flag

The skills above already pass a project key or parent issue, so they are
not blocked. The hook is for raw `jira issue create` shell commands.

## Wiki Markup

All skills use Jira wiki markup (not Markdown). The `edit-description` skill
contains a comprehensive formatting reference including headers, code blocks,
links, and troubleshooting for common issues.
