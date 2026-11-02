# herdr-sweep

A Claude Code skill that sweeps [herdr](https://herdr.dev) agent sessions,
prints a digest, and sends follow-ups only after you approve them.

## Components

| Component     | Type  | Description                                      |
| ------------- | ----- | ------------------------------------------------ |
| `herdr-sweep` | Skill | Collect, digest, approve, then dispatch serially |

## Prerequisites

- [herdr](https://herdr.dev) installed, with `herdr` on `PATH`.
- The upstream `herdr` skill (`herdr --skill`) installed separately. This
  skill uses it for CLI syntax and does not copy it.
- A local sweep follows that skill's rule for running inside a herdr pane.
  A configured `--machine` profile uses that skill's machine rules.

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install herdr-sweep
```

## Usage

```text
/herdr-sweep
/herdr-sweep --machine <profile>
```

The skill also activates when you ask which herdr sessions finished, which
are stuck, or which are waiting on you.

What it does:

1. Collect sessions in the configured states.
2. Read each one with `herdr agent read --source recent-unwrapped`.
3. Digest what finished, what is stuck, and what is waiting on you.
4. Show follow-up drafts and send nothing until you approve them.
5. Send approved items one at a time with `herdr agent prompt --wait`.

A blocked approval or question is quoted verbatim and is not answered. A
timeout or stall is reported and is not retried. Other approved items on
that target wait until you say to continue. An `idle` session with a
background shell or job still running is flagged and is not prompted.

## Configuration

Set these in the plugin configuration dialog. Claude Code stores them in
your user `pluginConfigs` for `herdr-sweep`. Leave a value empty for the
default.

| Option                     | Default           | Purpose                                                                                                                                                                                      |
| -------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tab label pattern          | empty             | Regex whose first capture group is the work-item ID. Empty shows raw tab labels. Example: `^([A-Z]+-\d+)`                                                                                    |
| External dispatch commands | empty             | One `kind=command template` per follow-up kind. Example: `rebase=my-pr-tool dispatch --rebase --pr {pr} --go`. Other follow-ups use `herdr agent prompt`.                                    |
| States to sweep            | `done`, `blocked` | Lifecycle states to collect.                                                                                                                                                                 |
| Include unread idle        | off               | Also collect `idle` sessions whose last turn has not been read.                                                                                                                              |
| Machine profiles           | empty             | herdr `--machine` profiles. Empty sweeps the local session only. When set, only those profiles are swept. Each profile is dispatched on its own, with at most one agent working per profile. |

`{pr}` in a dispatch template is replaced with the pull request identifier
from that session. A template that needs `{pr}` and has none is shown and
not run.
