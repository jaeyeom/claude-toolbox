# jira-close-merged

Claude Code skill for syncing Jira tickets with merged git commits using the
Atlassian MCP.

## Prerequisites

- Atlassian MCP connected (`mcp__claude_ai_Atlassian__*` tools available)
- Git repository with Jira ticket IDs referenced in commit messages

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install jira-close-merged
```

## Skills

### Closing merged tickets

- `/jira-close-merged:jira-close-merged` — Scan the git log for Jira ticket IDs and transition any non-Done tickets to Done
- `/jira-close-merged:jira-close-merged PROJ` — Limit scan to a specific project key (e.g. `PROJ`)

## How it works

1. Scans `git log` (last 50 commits by default) for Jira ticket IDs matching
   `[A-Z]+-\d+` (e.g. `PROJ-123`, `TEAM-456`).
2. Looks up each ticket's current status via the Atlassian MCP.
3. Skips tickets already in the "Done" status category.
4. Transitions all remaining tickets to Done in one pass.
5. Reports a summary table with per-ticket results.

## Example usage

After a batch of PRs lands on main:

```
/jira-close-merged:jira-close-merged PROJ
```

Or to check all project keys in the last 100 commits:

```
/jira-close-merged:jira-close-merged
```

(The skill will show you which project keys it found and ask you to confirm
before making any changes.)
