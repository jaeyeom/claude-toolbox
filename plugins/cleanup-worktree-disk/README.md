# cleanup-worktree-disk

Claude Code skill for safely reclaiming macOS and Linux disk space used by git
worktrees and Bazel output bases.

## Components

| Component                          | Type    | Description                                                       |
| ---------------------------------- | ------- | ----------------------------------------------------------------- |
| `cleanup-worktree-disk`            | Skill   | Plan, resolve uncertain items, confirm, apply, and verify cleanup |
| `scripts/cleanup_worktree_disk.py` | Python  | Inventory, planning, safety rechecks, apply, and verification     |
| `scripts/plan.sh`                  | Wrapper | Generate a JSON plan and human-readable table                     |
| `scripts/apply.sh`                 | Wrapper | Apply selected plan items with safety rechecks                    |
| `scripts/verify.sh`                | Wrapper | Report disk free before and after and remaining plan items        |

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install cleanup-worktree-disk
```

## Usage

Run from a main repository checkout. The plan is read-only. Review each item,
resolve items marked `ask`, and get explicit approval before running
`apply.sh`. GitHub CLI authentication and network access are required to
classify pull request state.

The implementation requires Python 3.10 or newer, Git, and the GitHub CLI.
The documented `plan.sh`, `apply.sh`, and `verify.sh` commands remain
compatible shell entry points and delegate to the Python implementation.

## Configuration

`${XDG_CONFIG_HOME:-~/.config}/cleanup-worktree-disk/config` accepts
`repos`, `bazel_output_root`, `protect`, `fresh_hours`, and `extra.<name>`
key-value entries. With no config, platform defaults are used and the plan
prints a suggested config that can be saved after approval.

Linux uses `~/.cache/bazel/_bazel_$USER`; macOS uses
`/private/var/tmp/_bazel_$USER` by default.

Run the automated fixture suite with
`bash skills/cleanup-worktree-disk/tests/run.sh`. It uses temporary
repositories and a stub GitHub CLI, so it does not modify real worktrees.
