# Jira Commands

Slash commands for common Jira operations using the `jira` CLI tool.

## Prerequisites

- [jira CLI](https://github.com/ankitpokhrel/jira-cli) installed and configured

## Commands

Install via Claude Code:

```
claude install github:jaeyeom/claude-toolbox/plugins/jira-commands
```

Then use the following commands:

- `/jira new-bug PROJECT` — Create a bug report in the given project
- `/jira new-bug PROJ-123` — Create a bug under an epic
- `/jira new-task PROJECT` — Create a task in the given project
- `/jira new-task PROJ-123` — Create a task under an epic
- `/jira resolve PROJ-123` — Investigate and resolve a Jira issue
- `/jira update PROJ-123` — Update a ticket description after investigation
- `/jira plan-project path/to/design.md` — Plan a project with Jira tasks

## Related Plugins

- **jira-edit-description** — Detailed wiki markup formatting skill referenced
  by these commands
