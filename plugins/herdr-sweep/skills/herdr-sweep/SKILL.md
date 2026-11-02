---

name: herdr-sweep
description: Use when several herdr agent sessions are open and you need to see which finished, which are stuck, which are waiting on the user, or what each should do next. Also use when the user asks for a herdr sweep, a session digest, or /herdr-sweep.
argument-hint: "[--machine <profile>]"
---

# herdr-sweep

Sweep herdr agent sessions, print a digest, and send follow-ups only after
the user approves them.

Command syntax, JSON fields, error names, seen-state, and background-task
signals come from the installed `herdr` skill (`herdr --skill`). Do not guess
flags or copy that skill into this one. If `herdr` is not installed, say so
and stop.

For a local sweep, follow that skill's rule for when you are not inside a
herdr pane. A `--machine` profile follows that skill's machine rules instead.

## Configuration

Values live in this plugin's `userConfig`. Claude Code stores them under
`pluginConfigs` for `herdr-sweep` and fills the placeholders below when it
loads this skill. An empty value, `[]`, or text that still contains
`${user_config.` means unset. Use the default.

| Key                   | Default when unset | Meaning                                                                                                                                                                           |
| --------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `label_pattern`       | unset              | Regex. The first capture group is the work-item ID. Unset: raw tab labels, no grouping.                                                                                           |
| `dispatch_commands`   | unset              | List of `kind=command template`. The kind is the text before the first `=`. Only `{pr}` is substituted, from that session's read. Unset: every follow-up is `herdr agent prompt`. |
| `states`              | `done`, `blocked`  | Lifecycle states to collect.                                                                                                                                                      |
| `include_unread_idle` | `false`            | Also collect `idle` sessions whose last turn is unread.                                                                                                                           |
| `machines`            | unset              | `--machine` profiles. Unset: the local session only. Set: those profiles only.                                                                                                    |

Current values:

- Label pattern: ${user_config.label_pattern}
- Dispatch commands: ${user_config.dispatch_commands}
- States: ${user_config.states}
- Include unread idle: ${user_config.include_unread_idle}
- Machines: ${user_config.machines}

If the user names one profile for this run, sweep only that profile.

A list may arrive as a JSON array or as one entry per line. `states` entries
are state names. `machines` entries are profile labels or ids. Dispatch kinds
match exactly after trimming.

## Workflow

Run the steps below once per target. Targets are the configured machine
profiles, or the local session when that list is unset. Pass the same
`--machine <profile>` on every herdr command for a profile, and do not pass
`--machine` for the local session. Do not reuse agent names or pane ids from
another target.

A timeout, stall, or error on one target does not stop the others. On one
target, at most one agent is `working` because of a prompt this skill sent.

### 1. Collect

Run `herdr agent list`. Keep a session when its state is in `states`. When
`include_unread_idle` is true, also keep an `idle` session whose last turn is
unread, using the seen-state signal from the herdr skill.

If none remain, print this digest and stop. Do not read further and do not
send anything:

```text
## herdr-sweep (<target>)

No sessions in the selected states.
```

`<target>` is `local` or the profile name.

### 2. Read

For each kept session, run `herdr agent read --source recent-unwrapped`.

### 3. Digest

Print one digest for this target. Group sessions by the work-item ID captured
from the tab label when `label_pattern` is set. A label that does not match
stands alone under its raw label. When the pattern is unset, list raw labels
and do not group.

For each session include:

- what it finished
- what it is stuck on
- what it is waiting on from the user

When the session is `blocked`, the waiting line is the pending approval or
question copied verbatim from the read. Do not paraphrase it, draft a reply,
or add a proposed prompt.

When the session is `idle` and a background shell or job it started is still
running, say that, and name the job from the read or from the background-task
signal in the herdr skill. That session is not finished. Do not propose a
prompt for it.

### 4. Propose

For every remaining session that needs a follow-up, draft one item. If the
follow-up's kind matches a `dispatch_commands` entry, the draft is that
command template. Otherwise the draft is the text for `herdr agent prompt`.

Replace `{pr}` with the pull request identifier from that session's read. If
the template contains `{pr}` and the read has no pull request identifier,
say so in the proposal and mark the item not sendable.

Show every draft. Then stop. Send nothing until the user approves one
session, several sessions, or all of them. No reply means no send.

### 5. Dispatch

Send approved, sendable items one at a time. Wait until that send finishes
before starting the next on this target.

A matching dispatch kind runs the filled command template. Anything else runs
`herdr agent prompt --wait` with the approved text. Pass `--machine` the same
way as in Collect.

If the result is a timeout or a stall, as the herdr skill names those
results, report the session and the result, and stop dispatch on this
target. Do not send that item again. Do not start the next approved item
until the user says to continue.

If the result is blocked, stop dispatch for that session, quote the dialog
verbatim, and do not answer it. The next approved item on this target may
still go out after this wait has returned.

## Safety

- Never answer a blocked approval or question. Do not send keys, a prompt, or
  other text into that dialog. Show the dialog verbatim.
- Never resend an item after a timeout or a stall.
- Never close a tab or pane this skill did not create. This skill does not
  create them.
- `idle` with a running background shell or job is not finished. Flag it, and
  do not stack a prompt on it.

## Rationalizations

| Excuse                                         | Reality                                                      |
| ---------------------------------------------- | ------------------------------------------------------------ |
| "The question is obvious, so I will answer it" | Quote it. The user answers.                                  |
| "The timeout means it never arrived"           | Report the timeout or stall. Do not send it again.           |
| "Idle means it can take a prompt"              | A running background job stays in the digest with no prompt. |
| "They approved all, so send them together"     | Approved items go out one at a time per target.              |
| "An empty sweep should still nudge someone"    | No selected sessions means the empty digest and no send.     |
| "I know the herdr flag from memory"            | Read the herdr skill for syntax and output fields.           |
