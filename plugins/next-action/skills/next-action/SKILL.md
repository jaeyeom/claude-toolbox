---
name: next-action
description: Find the next highest-priority action to work on. Scans local TODO files, source code TODO comments, GitHub issues, and unpushed local commits. Checks for blockers, staleness, and priority signals to recommend what to do next. Use when asked "what should I work on next", "next task", "find work", or "what's left to do".
autouse: false
---

# Next Action

Find and suggest the next highest-priority action to work on by scanning
multiple task sources (TODO files, source code TODO comments, GitHub issues,
and unpushed local commits), checking for blockers and staleness, and presenting
a recommended action.

This skill **suggests only** — it does not begin working on the task unless the
user explicitly asks.

## Step 1 — Discover task sources

Check the repository root `CLAUDE.md` for any documented task source
configuration. Look for sections or comments that reference:

- TODO file paths (e.g., `TODO.md`, `TASKS.md`, `docs/TODO.md`)
- Issue tracker references (e.g., GitHub Issues, Jira project keys)
- Any custom task source conventions

If no task sources are documented in `CLAUDE.md`:

1. Search for common TODO files at the repo root: `TODO.md`, `TODO`,
   `TASKS.md`, `BACKLOG.md`.
2. Check whether `gh` CLI is available and authenticated (`gh auth status`).
3. If no local TODO file exists and `gh` is not available, ask the user where
   their tasks live. Suggest updating `CLAUDE.md` with a task source
   configuration section like:

   ```markdown
   ## Task Sources
   - Local: TODO.md
   - GitHub Issues: assigned to me, label "ready"
   ```

## Step 2 — Gather candidates from local TODO files

For each discovered TODO file:

1. Read the file contents.
2. Extract all incomplete items (`- [ ] ...`).
3. Parse priority from section headers (`## High Priority`, `## Medium
   Priority`, `## Low Priority`) or inline markers (`P0:`, `P1:`, `P2:`,
   `URGENT:`, `HIGH:`, `MEDIUM:`, `LOW:`).
4. Parse blocker markers: items containing `BLOCKED:`, `BLOCKED BY`, `WAITING
   ON`, or `DEPENDS ON` followed by a description or issue reference are
   considered blocked.
5. **In-progress check** — Detect items already being worked on:
   - Items using an in-progress checkbox marker (`- [~] ...` or `- [-] ...`)
   - Items containing `IN PROGRESS`, `WIP`, or `IN REVIEW` markers
   - Mark these items as in-progress and skip them during recommendation — they
     are likely being handled by another session.
6. **Staleness check** — For each candidate item, check whether referenced files
   or functions still exist:
   - If the item mentions a file path (e.g., `src/auth.go`), verify the file
     exists with `ls`.
   - If the item mentions a function or symbol name, search with `rg` to check
     it still exists in the codebase.
   - If the item references a GitHub issue number (`#123`), check its state
     with `gh issue view <number> --json state --jq '.state'`. Skip items
     referencing closed issues.
   - Flag stale items to the user but do not recommend them.

## Step 3 — Gather candidates from source code TODO comments

Run the helper script to scan and score inline TODO comments:

```bash
bash "${SKILL_DIR}/scan-code-todos.sh" --limit 20 .
```

where `${SKILL_DIR}` is the directory containing this SKILL.md file.

The script scans for `TODO`, `FIXME`, `HACK`, and `XXX` comments in source code
(excluding markdown, JSON, lock files, vendored/generated directories), parses
each match into structured JSON with fields: `tag`, `tracker_id`, `assignee`,
`description`, `file`, `line`, and `score`.

Scoring rules applied by the script:

- `FIXME` / `XXX` → 80
- `HACK` → 60
- `TODO` with `P0` / `URGENT` marker → 70
- `TODO` with tracker ID → 50
- plain `TODO` → 35
- Security keywords (`security`, `vulnerability`, `crash`, `data loss`,
  `race condition`) boost score to 80

**Post-processing (after receiving script output):**

1. **Deduplication** — If a TODO comment references a tracker ID that matches a
   GitHub issue gathered in Step 4, merge them: attach the code location to the
   GitHub issue candidate rather than creating a duplicate entry.  If multiple
   TODO comments share the same tracker ID, group them as a single candidate
   with multiple locations.

2. **Staleness check** — If a comment references a GitHub issue (`#123` in the
   `tracker_id` field), check its state with `gh issue view`. If the issue is
   closed, the TODO is stale — flag it as needing cleanup rather than
   recommending it as work.

## Step 4 — Gather candidates from GitHub Issues

Run the helper script to fetch and score open GitHub issues:

```bash
bash "${SKILL_DIR}/scan-github-issues.sh" --limit 20
```

where `${SKILL_DIR}` is the directory containing this SKILL.md file.

The script handles:

- Fetching open issues assigned to the current user (falls back to unassigned)
- Parsing priority signals from labels (`P0`, `P1`, `critical`, `urgent`,
  `high-priority`, `good first issue`, `help wanted`) and title prefixes
  (`[P0]`, `[URGENT]`, etc.)
- **Blocker detection** — task list references (`- [ ] #123`), URL references
  (`- [ ] https://github.com/.../issues/123`), and keywords (`blocked by #123`,
  `depends on #123`). Each referenced issue is checked; if still open, the
  issue is marked blocked.
- **In-progress detection** — issues with `in progress`, `wip`, `in-progress`,
  or `in review` labels, and issues with linked open pull requests.
- Scoring per the table in Step 6, including the `+15` assignment bonus.

Output: JSON array sorted by score (descending), each entry:

```json
{"number": 7, "title": "...", "labels": [...], "score": 55, "status": "ready", "blocked_by": [], "assignees": [...]}
```

Status values: `"ready"`, `"blocked"`, `"in_progress"`.

**Post-processing (after receiving script output):**

1. **Staleness check** — For each issue with status `"ready"`, search the
   codebase for references:

   ```bash
   rg '#<issue-number>\b' .
   rg 'issues/<issue-number>\b' .
   ```

   If the issue references specific files, functions, or code paths in its
   body, verify they still exist. Flag issues whose context has significantly
   changed.

## Step 5 — Review unpushed local commits

Check for commits on the current branch that have not been pushed to the remote.
These represent completed work that still needs to be pushed, or issues that
were addressed locally but whose corresponding GitHub issues remain open.

1. Detect unpushed commits:

   ```bash
   git log @{upstream}..HEAD --oneline 2>/dev/null || git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null
   ```

   If the branch has no upstream configured and no remote equivalent, skip this
   step.

2. For each unpushed commit, extract the commit subject and check:
   - **Issue references** — If the commit message references a GitHub issue
     (`#123`, `fixes #123`, `closes #123`, `resolves #123`), record the
     association. These issues may be resolved locally but not yet closed on
     GitHub because the commits haven't been pushed.
   - **Conventional commit scope** — Parse the commit type and scope (e.g.,
     `feat(auth): ...`, `fix(parser): ...`) to understand what area was changed.

3. Cross-reference with GitHub issue candidates from Step 4:
   - If an unpushed commit references an open GitHub issue (via `fixes #N`,
     `closes #N`, or `resolves #N`), mark that issue as **locally resolved —
     needs push**. Do not recommend it as work to do; instead, surface it as a
     push action.
   - If an unpushed commit references an issue but without a closing keyword
     (just `#N`), flag the issue as **partially addressed locally** — it may
     still need additional work.

4. Generate candidates from unpushed commits:
   - Unpushed commits that close issues → recommend **"Push to close #N"** as a
     candidate action with score 85 (high priority — the work is done, just
     needs delivery).
   - A batch of unpushed commits with no issue references → recommend **"Push N
     unpushed commits"** as a single candidate with score 45 (medium — routine
     delivery).

## Step 6 — Rank and recommend

Assign a priority score to each non-blocked, non-stale, non-in-progress
candidate:

| Source          | Priority signal                     | Score |
|-----------------|-------------------------------------|-------|
| Local TODO      | High Priority section / P0 / URGENT | 100   |
| Local TODO      | Medium Priority section / P1        | 50    |
| Local TODO      | Low Priority section / P2           | 20    |
| Code TODO       | FIXME / XXX / security-related      | 80    |
| Code TODO       | TODO with P0 / URGENT marker        | 70    |
| Code TODO       | TODO with tracker ID                | 50    |
| Code TODO       | plain TODO                          | 35    |
| GitHub Issue    | P0 / critical / urgent label        | 90    |
| GitHub Issue    | P1 / high-priority label            | 60    |
| GitHub Issue    | assigned to me                      | +15   |
| GitHub Issue    | help wanted / good first issue      | 30    |
| GitHub Issue    | no priority label                   | 40    |
| Unpushed Commit | closes/fixes/resolves an issue      | 85    |
| Unpushed Commit | no issue reference (batch push)     | 45    |

Sort candidates by score (descending). Break ties by preferring local TODO
items over GitHub issues, and older items over newer ones.

## Step 7 — Present the recommendation

Display the top recommendation clearly:

```
## Next Action

**[Source]** description-of-task
Priority: High | Score: 100
Status: Ready to work on

### Context
Brief summary of what the task involves and any relevant pointers.
```

Then list up to 4 runners-up in a compact table:

```
### Other candidates
| # | Source | Priority | Description          |
|---|--------|----------|----------------------|
| 2 | TODO   | Medium   | Refactor auth module |
| 3 | GH #42 | P1       | Fix pagination bug   |
```

If any items were flagged as blocked, stale, or in-progress, list them in a
separate section:

```
### Blocked / Stale / In-progress items
- **TODO**: "Migrate to new API" — BLOCKED BY #15 (still open)
- **GH #23**: "Fix login flow" — STALE: references `src/old-auth.go` which no longer exists
- **Code TODO**: `src/auth.go:42` — STALE: references closed issue #15
- **TODO**: "Add retry logic" — IN PROGRESS (likely being handled by another session)
- **GH #17**: "Refactor auth" — IN PROGRESS: has linked open PR #31
```

If any unpushed commits were found, list them in a dedicated section:

```
### Unpushed commits
- **Push to close #9** — `cc11f06 docs: add vibecoding setup guide` (closes #9, needs push)
- **3 unpushed commits** — routine delivery, no issue references
```

For issues marked as **locally resolved — needs push**, do not list them under
"Other candidates" — show them only in the "Unpushed commits" section to avoid
confusion.

## Step 8 — Suggest CLAUDE.md update (if needed)

If Step 1 found no task source configuration in `CLAUDE.md`, suggest appending
a task source section based on what was discovered:

```markdown
## Task Sources
- Local: TODO.md
- GitHub Issues: assigned to @me, state open
```

Explain why this helps: future invocations of `/next-action` will skip the
discovery step and use the configured sources directly.

Do **not** modify `CLAUDE.md` without user confirmation.

## Rules

- **Suggest only** — never start working on a task without explicit user
  confirmation.
- Always check for blockers before recommending an item.
- Always check for staleness before recommending an item.
- Always check for in-progress status before recommending an item — skip
  items that are likely being handled by another session or contributor.
- If zero actionable candidates are found, say so clearly and suggest creating
  tasks or checking the issue tracker directly.
- If the user provides an argument (e.g., `/next-action todo`,
  `/next-action code`, `/next-action github`, or `/next-action unpushed`),
  limit the scan to that source only.
- Respect any filters documented in `CLAUDE.md` task source configuration
  (e.g., specific labels, milestone, Jira project).
