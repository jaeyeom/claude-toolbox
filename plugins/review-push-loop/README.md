# review-push-loop

PreToolUse hook that makes `review-and-push-loop` the default push method in
Claude Code sessions. The loop reviews each unpushed commit before pushing it
and stops at the first blocker, so routing `git push` through it makes
"review-then-push" the default instead of an opt-in step.

## What it does

- **Denies** plain `git push`, `git push origin <branch>`, `git push -u ...`,
  and force-pushes (`--force`, `-f`, `--force-with-lease`) — and tells the
  agent to run `review-and-push-loop --output compact` instead.
- **Allows** these escape hatches through:
  - `git push --tags` (and `git push origin --tags`)
  - `git push --delete <branch>` / `-d <branch>`
  - `git push origin :<branch>` (legacy delete syntax)
- **Surfaces an install hint** if `review-and-push-loop` is not on `PATH`.

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install review-push-loop
```

The hook expects `review-and-push-loop` to be installed and on `PATH`. Install
instructions live at
<https://github.com/jaeyeom/experimental/tree/main/devtools/reviewpush>
(see `README.md` and files below it).

## How it works

The plugin registers a `PreToolUse` hook on the `Bash` tool. Before any shell
command runs, the hook parses the command, checks whether it is a `git push`
invocation, applies the escape-hatch rules above, and either lets the command
through or denies it with a `permissionDecision: "deny"` JSON payload that
points the agent at `review-and-push-loop --output compact`.

If you genuinely need an unmediated `git push` (e.g. force-push during a
rebase), uninstall the plugin temporarily or use one of the allowed escape
hatches.
