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
transitions any non-Done tickets to Done. For unassigned tickets, also
assigns them to the author of the most recent commit that referenced the
ticket.

## Steps

### 1. Collect ticket IDs and commit authors

Run the following, substituting the project key(s) the user specifies (or
ask if unclear):

```bash
git log --format='%ae|%s' -50
```

Adjust the commit depth (default 50) to match the user's context. If the
user says "last 100 commits" or names a specific release tag, use that
range instead.

Parse each line as `author_email|subject`. Git log is newest-first, so the
**first** line mentioning a ticket ID is the most recent commit for that
ticket — record that line's `author_email` as the ticket's commit author.

Extract ticket IDs with the pattern `[A-Z]+-\d+`. If the user specifies a
project key like `PROJ`, only keep IDs matching `\bPROJ-\d+\b`. Build:

- a unique list of ticket IDs to process
- a map of `ticket_id → author_email` (most recent commit author per ticket)

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

For every ticket identified in step 3:

1. If the ticket has **no assignee** (`assignee` is null or missing):
   - Look up the commit author email from the map built in step 1.
   - Resolve it to a Jira account with `lookupJiraAccountId` (use the
     author's email; fall back to name only if email lookup fails).
   - If resolved, call `editJiraIssue` to set `fields.assignee` to that
     account id **before** transitioning. Record the display name for the
     report.
   - If the author can't be resolved, skip assignment and note it in the
     report — do **not** fail the close.
   - Never reassign a ticket that already has an assignee.
2. Call `transitionJiraIssue` with the Done transition id from step 4.

Run all tickets in parallel. If a ticket can't be transitioned (e.g.
blocked by a required field), report it as "skipped" with the error rather
than failing the whole run.

### 6. Report results

Show a compact summary table:

| Ticket | Summary (truncated to ~40 chars) | Result |
|--------|----------------------------------|--------|
| X-123  | Short summary...                 | Done ✓ (assigned to Jane) |
| X-124  | Another ticket...                | already done |
| X-125  | Blocked ticket...                | skipped: <reason> |
| X-126  | Unresolved author...             | Done ✓ (assignee unresolved) |

List counts at the end: "Transitioned N ticket(s), M already done, K skipped."

## Notes

- If the user doesn't specify a project key, scan for any `[A-Z]+-\d+`
  pattern (bare ticket IDs like `PROJ-123` in commit messages). Present
  the unique project keys found and ask the user to confirm which ones to
  process before proceeding — avoid accidentally closing tickets from
  unrelated projects.
- Commit depth defaults to 50; the user can override it (e.g. "last 100
  commits", "since last release tag").
- The git log is **not** author-filtered — it lists everyone's commits on
  the branch. The assignee for each ticket comes from that ticket's own
  most recent referencing commit, not from the user running the skill.
- When multiple commits reference the same ticket with different authors,
  the most recent commit's author wins (git log order).
- Requires the Atlassian MCP (`mcp__claude_ai_Atlassian__*` tools) to be
  connected.