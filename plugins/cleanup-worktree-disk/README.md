# cleanup-worktree-disk

Claude Code skill for reclaiming macOS disk space in a Bazel + git-worktree
workflow.

## Problem

On a Bazel monorepo dev machine, disk is eaten by two things:

1. **Git worktrees** — each is a full source checkout (often 1–2 GB).
2. **Bazel output bases** under `/private/var/tmp/_bazel_$USER/<hash>/` — each
   built workspace gets its own, often **9–12 GB each**. This is almost always
   the bulk of reclaimable space.

Stale worktrees whose PRs are already merged, plus orphaned output bases whose
workspace directory no longer exists, pile up after batches of PRs land.

## Components

| Component               | Type   | Description                                              |
| ----------------------- | ------ | -------------------------------------------------------- |
| `cleanup-worktree-disk` | Skill  | Inventory → classify → confirm → remove → verify flow    |
| `inventory.sh`          | Script | Read-only worktree + Bazel base classification (bundled) |

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install cleanup-worktree-disk
```

## Usage

The skill activates when the user is low on disk or asks to clean up worktrees
or Bazel caches:

- "clean up disk space"
- "remove merged worktrees"
- "the bazel cache is huge"
- "my disk is full"

Run from inside the main repo checkout (not a worktree).

## What it covers

- Detecting merged PRs via `gh` (squash merges defeat `git branch --merged`)
- Removing worktrees, branches, and their live Bazel output bases
- Sweeping orphaned Bazel bases whose `DO_NOT_BUILD_HERE` workspace is gone
- macOS sandbox gotchas (`gh` TLS, protected paths during deletion)
- Bazel read-only output files (`chmod -R u+w` before `rm -rf`)

Out of scope: Homebrew, Docker images, `~/Library/Caches`, and other general
macOS cleanup.