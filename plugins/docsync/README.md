# Docsync

A Claude Code skill that uses the `docsync` CLI to find documentation
sections implicated by a code change, review them against the diff, and
patch stale factual drift.

## Components

| Component | Type  | Description                                              |
| --------- | ----- | -------------------------------------------------------- |
| `docsync` | Skill | Run `docsync check`, review implicated docs, edit if stale |

## Prerequisites

The `docsync` binary must be on `PATH`:

```bash
go install github.com/jaeyeom/experimental/devtools/docsync/cmd/docsync@latest
```

A `docsync.yml` mapping at the repo root is the index from code paths to
docs. If none exists, the skill offers a small starter mapping from obvious
code↔doc pairs — it does not invent a full coverage map.

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install docsync
```

## Usage

The skill activates when you ask about stale docs, or as a finishing step
after a feature, fix, or PR:

- "Which docs need review after this change?"
- "Sync the docs with this branch"
- "We're done with the auth refactor — anything in the docs stale?"

It runs `docsync check` against the PR-shaped diff (or named files), reads
implicated sections, patches clear factual drift, and asks before large
rewrites.

## What It Covers

- Change-set selection (`--base` merge-base vs `--files`)
- JSON check output (`affected`, `triggered_by`, `unmatched_files`)
- Thin `docsync.yml` bootstrap when the mapping is missing
- Glob gotchas (root-anchored patterns, no implicit `**/`)
