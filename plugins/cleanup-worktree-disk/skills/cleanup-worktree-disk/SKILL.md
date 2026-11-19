---

name: cleanup-worktree-disk
description: "Reclaim macOS or Linux disk space by reviewing git worktrees, branches, and Bazel output bases, then removing only explicitly approved items. Use when the user is low on disk, asks to clean up disk space or worktrees, or says the Bazel cache is huge."
---

# Cleanup worktree and Bazel disk

This skill inventories worktrees and Bazel output bases, classifies each item,
and applies only the items the user approves. The scripts do the mechanical
work; the model resolves ambiguous items and presents the plan.

## Procedure

Run from a main repository checkout. `gh` must be authenticated so pull
request state can be checked. Do not continue if inventory cannot query GitHub.

### 1. Plan (read-only)

```bash
plan_file="${TMPDIR:-/tmp}/cleanup-plan.json"
bash "${SKILL_DIR}/scripts/plan.sh" > "$plan_file"
```

The script prints a human table to stderr and JSON to stdout. Read the JSON and
show the user every item, its size, class, reasons, and the estimated total
reclaim. The classes are `remove`, `keep`, and `ask`.

- Remove merged, clean, pushed worktrees and their branches.
- Keep the primary checkout, locked worktrees, open worktrees without
  unpushed commits, live bases of kept
  worktrees, and fresh unmapped bases.
- Ask about unpushed, detached, unknown PR state, old unmapped bases, and any
  other uncertain item. Do not resolve these by guessing.
- Orphaned output bases and live bases belonging to a removable worktree are
  removable.
- Protected paths always remain `keep`.

If there is no config, defaults are used and the script prints a suggested
config. Show it to the user and offer to save it. Only after the user agrees,
run `bash "${SKILL_DIR}/scripts/plan.sh" --write-config`.

### 2. Confirm

Resolve every `ask` item with the user. Show the complete selected item list
and reclaim estimate, then get explicit approval before applying anything.

### 3. Apply selected items

Pass the plan followed by selected IDs. List worktrees before their associated
branches and output bases so each apply-time check sees the worktree already
removed:

```bash
bash "${SKILL_DIR}/scripts/apply.sh" "$plan_file" \
  'worktree:/path/to/worktree' 'branch:/path/to/main-checkout:branch-name' \
  'output_base:/path/to/base'
```

An item classified `ask` can be applied only after the user resolves it and
explicitly approves it. The apply script rechecks locks, dirtiness, upstream
commits, PR state, output-base ownership and freshness immediately before each
operation. It skips items that became unsafe and reports each result. It never
uses `--force` to bypass a failed safety check.

Deletion must run outside the sandbox when it blocks Git worktree removal or
removing read-only Bazel output trees. Bazel output files are made writable
before removal. A failed removal is reported; do not improvise a forceful
fallback.

Configured `extra.<name>` commands appear as `extra:<name>` plan items. They
run only when the user selects them.

### 4. Verify

```bash
bash "${SKILL_DIR}/scripts/verify.sh" "$plan_file"
```

Report disk free before and after, remaining worktrees, and planned removal
items that are still present.

## Configuration

`${XDG_CONFIG_HOME:-~/.config}/cleanup-worktree-disk/config` uses simple
`key=value` lines:

- `repos`: colon-separated main checkouts to scan; defaults to the current
  repository.
- `bazel_output_root`: output-base directory. Defaults to
  `/private/var/tmp/_bazel_$USER` on macOS and
  `~/.cache/bazel/_bazel_$USER` on Linux.
- `protect`: colon-separated glob patterns matched against item paths.
- `fresh_hours`: age threshold for unmapped bases; defaults to 24.
- `extra.<name>`: optional command, run only when selected by the user.

For isolated runs and fixtures, `CLEANUP_WORKTREE_BAZEL_ROOT` can override the
detected default when no config value is set.

## Safety rules

- Never remove the primary checkout or a locked worktree.
- Never remove dirty worktrees, worktrees with unpushed commits, or worktrees
  whose PR is no longer confirmed merged.
- Never remove shared `install/` or `cache/` bases, fresh unmapped bases, or
  paths matching `protect`.
- `gh` lookups require network access. If they fail, stop without applying the
  plan.
