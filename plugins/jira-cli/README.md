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

## Wiki Markup

All skills use Jira wiki markup (not Markdown). The `edit-description` skill
contains a comprehensive formatting reference including headers, code blocks,
links, and troubleshooting for common issues.
