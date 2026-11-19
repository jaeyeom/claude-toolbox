# cleanup-worktree-disk

Claude Code skill for safely reclaiming macOS and Linux disk space used by git
worktrees and Bazel output bases.

## Components

| Component               | Type   | Description                                                       |
| ----------------------- | ------ | ----------------------------------------------------------------- |
| `cleanup-worktree-disk` | Skill  | Plan, resolve uncertain items, confirm, apply, and verify cleanup |
| `scripts/inventory.sh`  | Script | Read-only JSON inventory of worktrees and Bazel bases             |
| `scripts/plan.sh`       | Script | Classify inventory and emit a JSON plan plus a human table        |
| `scripts/apply.sh`      | Script | Apply only selected plan items with safety rechecks               |
| `scripts/verify.sh`     | Script | Report disk free before and after and remaining plan items        |

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

## Configuration

`${XDG_CONFIG_HOME:-~/.config}/cleanup-worktree-disk/config` accepts
`repos`, `bazel_output_root`, `protect`, `fresh_hours`, and `extra.<name>`
key-value entries. With no config, platform defaults are used and the plan
prints a suggested config that can be saved after approval.

Linux uses `~/.cache/bazel/_bazel_$USER`; macOS uses
`/private/var/tmp/_bazel_$USER` by default.
