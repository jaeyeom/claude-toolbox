---
name: gh-issue-resolver
description: Resolve a GitHub issue end-to-end using the gh CLI. Use when asked to resolve, fix, or work on a GitHub issue, when the issue has a written plan or acceptance criteria, or when implementation starts to diverge from that plan.
argument-hint: "<issue-number>"
autouse: false
---

# GitHub Issue Resolver

Resolve a GitHub issue by executing the issue's plan, meeting its acceptance
criteria, committing the fix, and opening a draft pull request.

The issue's plan is the execution contract. Its acceptance criteria are the
definition of done. Do not invent a competing approach.

## Prerequisites

- The `gh` CLI must be installed and authenticated (`gh auth status`).
- You must be in a Git repository with a GitHub remote.

## Instructions

### Step 1 — Read the GitHub issue

Fetch the issue details:

```bash
gh issue view $ARGUMENTS --json number,title,body,state,labels,assignees
```

If the issue is already closed, inform the user and stop.

Extract the **plan** and **acceptance criteria** as the contract:

| Body has | Treat as the plan |
|----------|-------------------|
| A heading such as Plan, Proposed design, Proposed behavior, Suggested approach, or Scope | That section |
| None of those headings | The whole body |

| Body has | Treat as acceptance criteria |
|----------|------------------------------|
| Acceptance criteria or Requirements (checkboxes or a MUST/should list) | That section |
| Neither | The stated outcome in the title and body |

### Step 2 — Check for blocking dependencies

Parse the issue body for task list items referencing other issues. Look for
patterns like:

- `- [ ] #123` (unchecked sub-issue or dependency)
- `- [ ] https://github.com/OWNER/REPO/issues/123` (full URL reference)

For each **unchecked** issue reference found, check whether it is still open:

```bash
gh issue view <referenced-number> --json state --jq '.state'
```

If any referenced issue is **open**, it is a blocker. List all blocking issues
and reject the request:

> Issue #N is blocked by the following open issues: #X, #Y. Please resolve
> those first.

Checked items (`- [x] #123`) and closed referenced issues are not blockers.

If no task list items or sub-issue references are found in the body, proceed
(there are no blocking dependencies).

### Step 3 — Mark the issue as in progress

Assign the issue to yourself and add an "in progress" label:

```bash
gh issue edit $ARGUMENTS --add-assignee @me
gh issue edit $ARGUMENTS --add-label "in progress"
```

If the "in progress" label does not exist, attempt to create it:

```bash
gh label create "in progress" --description "Work is actively underway" --color 1D76DB
```

If label creation fails (e.g., insufficient permissions), skip labeling and
proceed — assignment alone is sufficient to signal progress.

### Step 3a — Create a feature branch

If the current branch is the repository default branch, create and switch to
a feature branch before making changes:

```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
git checkout -b issue-<number>-<short-slug>
```

Derive `<short-slug>` from the issue title (lowercase, hyphenated, a few
words). If already on a non-default branch, keep it.

### Step 4 — Execute the plan

Search the codebase for references to the issue number:

```bash
rg '#<issue-number>\b' .
rg 'issues/<issue-number>\b' .
```

Replace `<issue-number>` with the actual number from `$ARGUMENTS`.

- **TODO/FIXME comments** referencing the issue are strong pointers — read the
  surrounding code and follow the guidance they provide. Delete or update these
  comments as part of the fix.
- **Other references** (documentation, changelogs, test comments) provide
  context about the issue.

Use those searches to **locate the planned change sites**, not to replace the
plan. Implement the plan as written. After each meaningful step, compare what
you are doing to the plan and the acceptance criteria.

### Step 4a — Deviation gate (first yes)

STOP before continuing if any of these is true:

- the planned approach is wrong or incomplete
- a different implementation is needed (including a better existing helper)
- a planned step or file should be skipped
- extra work not in the plan is needed
- a plan assumption is false, or an unknown appears
- an acceptance criterion cannot be met as written

Present, then wait for an explicit yes:

1. What the plan / acceptance criteria said
2. What you found
3. The proposed change

Do **not** implement the deviation until the user explicitly approves it.

**No exceptions:**

- Do not treat "intent is satisfied" as permission to change the plan
- Do not treat "the plan is a means, not the requirement" as permission
- Do not proceed because the user said "just finish, don't wait"
- Do not implement first and mention the change later
- A better existing helper is still a deviation

### Step 4b — Issue update (second yes)

After an approved deviation is implemented, propose a **surgical** issue-body
edit so the plan and acceptance criteria match what was actually done.

The proposal is:

- a unified-diff (or before/after) of **only** the sentences or bullets that
  no longer match
- still-valid investigation left untouched
- acceptance-criteria wording updated only if the criteria themselves changed

Show that exact edit. Do **not** run `gh issue edit` until the user explicitly
approves that edit. If they decline, leave the issue body as-is.

```bash
gh issue edit $ARGUMENTS --body-file <updated-body>
```

**No exceptions:**

- The first yes approved the approach, not the issue edit
- "Bookkeeping", "the record is lying", or review starting soon does not skip
  the second yes
- Do not rewrite the whole issue body
- Do not edit first and mention it after

### Step 5 — Review the code changes

Before committing, review all changes you made:

1. Ensure changes are correct and complete relative to the **acceptance
   criteria** (or the contract from Step 1 if there is no AC section).
2. Confirm every implemented deviation was approved (first yes) and that any
   issue-body edit was either approved (second yes) or skipped because the
   user declined.
3. Remove unnecessary comments that merely restate what the code does.
4. Verify no debug code, temporary logging, or unrelated changes are included.

### Step 6 — Commit the changes

If you made code changes, create a git commit with a descriptive message that
references the issue:

```bash
git add <specific-files>
git commit -m "fix: description of the fix

Resolves #<issue-number>"
```

Follow the repository's commit message conventions. Include
`Resolves #<issue-number>` or `Fixes #<issue-number>` in the commit body so
GitHub automatically links the commit to the issue.

### Step 7 — Open a draft pull request

Push the feature branch and open a **draft** pull request.

Look for a default pull request template (names are case-insensitive), in
this order:

1. `.github/pull_request_template.md`
2. `pull_request_template.md` (repository root)
3. `docs/pull_request_template.md`
4. Files under `.github/PULL_REQUEST_TEMPLATE/`, `PULL_REQUEST_TEMPLATE/`,
   or `docs/PULL_REQUEST_TEMPLATE/` (one file: use it; several: use the
   first in lexicographic order)

Search the working tree first. If none of those paths exist, repeat the
same search on the default branch (`git show origin/<default>:<path>`).

If a template exists, use it as the PR body: keep every heading, checklist
item, and HTML comment, and fill in the sections from the issue and the work
done. Put `Resolves #<issue-number>` in the related-issue slot when the
template has one; otherwise include it in the body.

If no template exists, write a short body that includes
`Resolves #<issue-number>`.

Write the filled body to a file and create the draft PR:

```bash
git push -u origin HEAD
gh pr create --draft --title "<issue title>" --body-file <filled-body>
```

Pass the filled text with `--body-file`. `gh` rejects combining `--template`
with `--body` / `--body-file`, so do not pass the unfilled template path as
`--template`.

Omit `--draft` only when the user explicitly asks for a ready-for-review
pull request.

If a pull request already exists for this branch (`gh pr view`), report its
URL instead of creating another.

Report the PR URL to the user.

### Step 8 — Clean up the "in progress" label

After committing, remove the "in progress" label so it does not remain on the
issue after it is auto-closed:

```bash
gh issue edit $ARGUMENTS --remove-label "in progress"
```

If the label was never added (e.g., it could not be created in Step 3), skip
this step.

### Step 9 — Leave the issue open

Do **not** close the issue. The issue will be closed automatically when the
pull request is merged (via the `Resolves #N` reference), or the user can
close it manually after review.

## Red Flags — STOP

- "The plan is a means, not the requirement"
- "Intent is satisfied either way"
- "User said don't wait" / review is in N minutes
- Implementing a different approach, then mentioning it in the commit or PR
- `gh issue edit` after the first yes without showing the exact diff
- "Updating the issue is just bookkeeping"
- Rewriting the whole issue body
- Opening a non-draft PR without being asked
- Writing a PR body that drops the repo template's headings or checklists

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "The plan is a means; intent is satisfied" | The written plan is the contract. Changing it needs the first yes. |
| "User said just finish, don't wait" | Deviation still needs a yes. Message them and stop. |
| "I'll mention it in the commit / later" | That is implementing first. Stop. |
| "A better helper is not really a plan change" | Different files or approach = deviation. First yes. |
| "They already said yes to the approach" | That was the first yes. The issue edit needs a second yes. |
| "Asking again is pedantic / the issue is lying" | Propose the exact diff and wait. Do not edit. |
| "I'll rewrite the whole issue so it's accurate" | Surgical only: change the sentences that no longer match. |
| "It's ready, so skip draft" | Draft is the default. Ready only if the user asks. |
| "I'll write a better body from scratch" | Fill the template. Keep its structure. |
