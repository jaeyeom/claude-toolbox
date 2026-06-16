---
name: jira-close-merged
description: >
  Marks Jira tickets as Done when their commits have been merged into the
  current branch. Use whenever the user wants to sync Jira with merged
  commits — e.g. "mark done", "close tickets from commits", "sync Jira
  with merged PRs", "any Jira tickets to close?", or after a batch of PRs
  lands. Works with any Jira project key.
---

# Jira: Close Merged Tickets

Scans the git log for Jira ticket IDs, checks their current status, and
transitions any non-Done tickets to Done.

## Steps

### 1. Collect ticket IDs

Run the following, substituting the project key(s) the user specifies (or
ask if unclear):

```bash
git log --oneline -50 | grep -oP '\b[A-Z]+-\d+\b' | sort -u
```

Adjust the commit depth (default 50) and project key pattern to match the
user's context. If the user says "last 100 commits" or names a specific
project key, use that. If the user specifies a project key like `PROJ`,
use `grep -oP '\bPROJ-\d+\b'` instead.

### 2. Look up Jira status

Use `searchJiraIssuesUsingJql` with a query like:

```
issueKey in (PROJECT-1, PROJECT-2, ...)
```

Request only `summary`, `status`, and `assignee` fields to keep the
response small. Use `getAccessibleAtlassianResources` to resolve the
cloud ID if you don't already have it in context.

### 3. Identify tickets to close

Skip tickets already in a "Done" status category (where
`status.statusCategory.key == "done"`). Report them as "already done"
so the user knows they were checked.

### 4. Get the Done transition ID

Call `getTransitionsForJiraIssue` on any one of the tickets to be
transitioned. Find the transition whose `to.statusCategory.key` is
`"done"` and note its `id`.

If there are no non-Done tickets, skip this step and go to step 6.

### 5. Transition all non-Done tickets in parallel

Call `transitionJiraIssue` for every ticket identified in step 3, all at
once. If a ticket can't be transitioned (e.g. blocked by a required
field), report it as "skipped" with the error rather than failing the
whole run.

### 6. Report results

Show a compact summary table:

| Ticket | Summary (truncated to ~40 chars) | Result |
|--------|----------------------------------|--------|
| X-123  | Short summary...                 | Done ✓ |
| X-124  | Another ticket...                | already done |
| X-125  | Blocked ticket...                | skipped: <reason> |

List counts at the end: "Transitioned N ticket(s), M already done, K skipped."

## Notes

- If the user doesn't specify a project key, scan for any `[A-Z]+-\d+`
  pattern (bare ticket IDs like `PROJ-123` in commit messages). Present
  the unique project keys found and ask the user to confirm which ones to
  process before proceeding — avoid accidentally closing tickets from
  unrelated projects.
- Commit depth defaults to 50; the user can override it (e.g. "last 100
  commits", "since last release tag").
- Requires the Atlassian MCP (`mcp__claude_ai_Atlassian__*` tools) to be
  connected.
