---
name: cleanup-worktree-disk
description: >-
  Reclaim macOS disk space by removing git worktrees whose PRs are already
  merged (plus their branches and Bazel output bases) and by deleting orphaned
  Bazel output bases whose workspace directory no longer exists. Use whenever
  the user is low on disk, says "clean up disk space", "free up space", "my
  disk is full", "clean up worktrees", "remove merged worktrees", "the bazel
  cache is huge", or after a batch of PRs has merged and stale worktrees pile
  up. Bazel output bases dominate disk (often 9–12 GB each), so reach for this
  even when the user only mentions worktrees — the cache is usually the real
  win.
---

# Cleanup worktree + Bazel disk

## What this does and why it's tricky

On a Bazel monorepo dev machine the disk is eaten by two things:

1. **Git worktrees** — each is a full source checkout (often 1–2 GB).
2. **Bazel output bases** under `/private/var/tmp/_bazel_$USER/<hash>/` — each
   built workspace gets its own, and they run **9–12 GB each**. This is almost
   always the bulk of the reclaimable space.

The job is to find worktrees whose work is already merged, remove them along
with their branch and their output base, and to sweep up output bases whose
workspace was already deleted (orphans). Sounds simple; it is full of sharp
edges that this skill exists to navigate. Read the gotchas — they each cost a
failed attempt to discover.

Run from inside the **main repo checkout**, not a worktree.

## Procedure

Work in phases: **inventory → classify → confirm → remove → verify.** Never
delete before showing the user the plan and the reclaim estimate.

### 1. Inventory (read-only)

Run the bundled script. It lists every worktree with its PR state and safety
signals, and classifies every output base. It deletes nothing.

```bash
bash "${SKILL_DIR}/scripts/inventory.sh"
```

where `${SKILL_DIR}` is the directory containing this SKILL.md file.

**Run it with the sandbox disabled.** It calls `gh`, and the Claude Code
sandbox blocks TLS for Go binaries (gh/jira) — inside the sandbox every PR
lookup silently returns `NO-PR`, which would make merged worktrees look
unmerged and hide the whole point of the skill.

### 2. Classify

From the inventory, sort worktrees into:

- **Remove**: `state=MERGED`, `dirty=0`, `unpushed=0` (or `unpushed=NO-REMOTE`
  for throwaway review checkouts of an already-merged PR).
- **Keep**: `state=OPEN`, or `LOCKED` (a lock is an explicit "don't touch"
  signal — respect it even if the PR is merged), or the primary checkout.
- **Ask the user**: anything ambiguous — `unpushed>0` (commits that exist only
  locally; deleting loses them), `NO-PR` with local-only commits, detached-HEAD
  scratch worktrees. Do not guess on these.

For output bases:

- **Remove**: `ORPHAN(safe-delete)` (workspace gone), plus the `LIVE` bases that
  map to worktrees you're about to remove.
- **Keep**: `install`/`cache` (shared — the script already skips them), `LIVE`
  bases of kept worktrees, and **`UNMAPPED-FRESH`** — a base with no
  `DO_NOT_BUILD_HERE` pointer and today's mtime is very likely a build in
  progress or mid-setup. Never delete fresh/unmapped bases.

### 3. Confirm

Present a table: each item, its size, and the total estimated reclaim. Get
explicit go-ahead before any destructive step. If `gh` couldn't run (you'll see
everything as `NO-PR`), stop and say so rather than deleting on bad data.

### 4. Remove

**All removal runs with the sandbox disabled.** This is not optional and it is
the single biggest gotcha:

- The sandbox denies deletion of protected paths that live *inside* every
  worktree — `.mcp.json`, `.claude/*`, `.git/worktrees/*/config.worktree`. A
  removal attempted in-sandbox fails with `Operation not permitted` **partway
  through**, leaving the worktree half-deleted (most files gone, admin dir and
  index intact). Do the whole removal in one out-of-sandbox pass.
- Because of that partial-deletion failure mode, **never reach for `--force` to
  paper over an error you don't understand.** A blind `--force` against a
  sandbox-blocked delete is exactly what shreds a worktree. Understand the
  refusal first.

Remove worktrees (force is legitimate here — these are merged and confirmed
clean; the only "untracked" content is regenerable build artifacts):

```bash
for wt in <paths-to-remove>; do
  git worktree remove --force "$wt" || rm -rf "$wt"
done
git worktree prune -v
```

Delete the now-detached branches. Use `-D`, not `-d`: squash-merged branches are
**not** ancestrally merged and `-d` will refuse them.

```bash
for br in <merged-branch-names>; do git branch -D "$br"; done
```

Remove the output bases. `rm -rf` alone fails with **`Permission denied`** —
Bazel marks external-repo files *and their parent directories* read-only, so
you can't unlink them. Make them writable first:

```bash
for h in <base-hashes-to-remove>; do
  chmod -R u+w "/private/var/tmp/_bazel_$(whoami)/$h" 2>/dev/null
  rm -rf "/private/var/tmp/_bazel_$(whoami)/$h"
done
```

### 5. Verify

Re-check free space and report the delta plainly:

```bash
df -h /System/Volumes/Data | tail -1
git worktree list
```

State the before/after free space and the count of worktrees and bases removed.

## Gotchas (each one cost a failed attempt)

- **Merged ≠ ancestrally merged.** Squash merges mean `git branch --merged` and
  `git status` clean tell you nothing about merge state. Use `gh pr list --head
  <remote-branch> --state all`. The remote branch name is usually *not* the
  local branch name, so resolve it via `@{upstream}` first — the script does
  this.
- **`gh`/`jira` need the sandbox off** (Go binary TLS). Inside the sandbox they
  fail silently, not loudly.
- **Removal needs the sandbox off** too (protected paths inside worktrees).
- **Bazel bases are read-only** → `chmod -R u+w` before `rm -rf`.
- **Never delete `install/`, `cache/`, or fresh unmapped bases.**
- **Respect `locked` worktrees** — that lock is a deliberate human signal.
- **zsh word-splitting**: on zsh, unquoted `$var` does *not* split on spaces.
  Build lists as arrays (`names=(a b c)`), or your loop runs once over the
  whole string.
- **`git status --porcelain` hides ignored files** — good for the safety gate
  (ignored build output is regenerable), but it means a "clean" worktree can
  still hold gigabytes of artifacts that `git worktree remove` will object to
  without `--force`.

## Scope

This skill covers worktrees and Bazel output bases only. For broader macOS
cleanup (Homebrew, Docker images, `~/Library/Caches`), that's out of scope —
say so rather than improvising destructive commands in unfamiliar territory.