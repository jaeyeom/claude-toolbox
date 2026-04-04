---
name: next-action
description: Find the next highest-priority action to work on. Scans local TODO files, source code TODO comments, GitHub issues, and other task sources. Checks for blockers, staleness, and priority signals to recommend what to do next. Use when asked "what should I work on next", "next task", "find work", or "what's left to do".
autouse: false
---

# Next Action

Find and suggest the next highest-priority action to work on by scanning
multiple task sources (TODO files, source code TODO comments, and GitHub
issues), checking for blockers and staleness, and presenting a recommended
action.

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
5. **Staleness check** — For each candidate item, check whether referenced files
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

If `gh` CLI is available and authenticated:

1. Fetch open issues assigned to the current user:

   ```bash
   gh issue list --assignee @me --state open --json number,title,labels,body --limit 20
   ```

2. If no assigned issues exist, fetch unassigned issues (limit 10):

   ```bash
   gh issue list --state open --json number,title,labels,body --limit 10
   ```

3. For each issue, extract priority signals:
   - Labels: `P0`, `P1`, `P2`, `critical`, `urgent`, `high-priority`,
     `good first issue`, `help wanted`.
   - Title prefixes: `[P0]`, `[URGENT]`, etc.

4. **Blocker check** — For each issue, parse the body for blocking
   relationships:
   - Task list references: `- [ ] #123` or `- [ ] https://github.com/.../issues/123`
   - Keywords in body: `blocked by #123`, `depends on #123`
   - If the GitHub API exposes sub-issue relationships, check those via:

     ```bash
     gh issue view <number> --json body
     ```

   For each referenced issue, verify its state. If any blocking issue is still
   open, mark this issue as blocked.

5. **Staleness check** — Search the codebase for references to the issue:

   ```bash
   rg '#<issue-number>\b' .
   rg 'issues/<issue-number>\b' .
   ```

   If the issue references specific files, functions, or code paths in its
   body, verify they still exist. Flag issues whose context has significantly
   changed.

## Step 5 — Rank and recommend

Assign a priority score to each non-blocked, non-stale candidate:

| Source       | Priority signal                     | Score |
|------------- |-------------------------------------|-------|
| Local TODO   | High Priority section / P0 / URGENT | 100   |
| Local TODO   | Medium Priority section / P1        | 50    |
| Local TODO   | Low Priority section / P2           | 20    |
| Code TODO    | FIXME / XXX / security-related      | 80    |
| Code TODO    | TODO with P0 / URGENT marker        | 70    |
| Code TODO    | TODO with tracker ID                | 50    |
| Code TODO    | plain TODO                          | 35    |
| GitHub Issue | P0 / critical / urgent label        | 90    |
| GitHub Issue | P1 / high-priority label            | 60    |
| GitHub Issue | assigned to me                      | +15   |
| GitHub Issue | help wanted / good first issue      | 30    |
| GitHub Issue | no priority label                   | 40    |

Sort candidates by score (descending). Break ties by preferring local TODO
items over GitHub issues, and older items over newer ones.

## Step 6 — Present the recommendation

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

If any items were flagged as blocked or stale, list them in a separate section:

```
### Blocked / Stale items
- **TODO**: "Migrate to new API" — BLOCKED BY #15 (still open)
- **GH #23**: "Fix login flow" — STALE: references `src/old-auth.go` which no longer exists
- **Code TODO**: `src/auth.go:42` — STALE: references closed issue #15
```

## Step 7 — Suggest CLAUDE.md update (if needed)

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
- If zero actionable candidates are found, say so clearly and suggest creating
  tasks or checking the issue tracker directly.
- If the user provides an argument (e.g., `/next-action todo`,
  `/next-action code`, or `/next-action github`), limit the scan to that
  source only.
- Respect any filters documented in `CLAUDE.md` task source configuration
  (e.g., specific labels, milestone, Jira project).
