---
name: gh-issue-resolver
description: Resolve a GitHub issue end-to-end using the gh CLI. Checks for blocking sub-issues/dependencies, self-assigns, investigates the codebase, makes changes, reviews code, and commits. Use when asked to resolve, fix, or work on a GitHub issue.
argument-hint: "<issue-number>"
autouse: false
---

# GitHub Issue Resolver

Resolve a GitHub issue by investigating the codebase, making changes, and committing the fix.

## Prerequisites

- The `gh` CLI must be installed and authenticated (`gh auth status`).
- You must be in a Git repository with a GitHub remote.

## Instructions

### Step 1 — Read the GitHub issue

Fetch the issue details:

```bash
gh issue view $ARGUMENTS --json number,title,body,state,labels,assignees
```

Read the title, body, and labels carefully. Understand what is being asked.

If the issue is already closed, inform the user and stop.

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

### Step 4 — Investigate and resolve the issue

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

If no references are found, rely on the issue description to understand what
needs to change. Investigate relevant files, trace the code path, and implement
the fix as described.

### Step 5 — Review the code changes

Before committing, review all changes you made:

1. Ensure changes are correct and complete relative to the issue description.
2. Remove unnecessary comments that merely restate what the code does.
3. Verify no debug code, temporary logging, or unrelated changes are included.

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

### Step 7 — Clean up the "in progress" label

After committing, remove the "in progress" label so it does not remain on the
issue after it is auto-closed:

```bash
gh issue edit $ARGUMENTS --remove-label "in progress"
```

If the label was never added (e.g., it could not be created in Step 3), skip
this step.

### Step 8 — Leave the issue open

Do **not** close the issue. The issue will be closed automatically when the
commit is merged (via the `Resolves #N` reference), or the user can close it
manually after review.
