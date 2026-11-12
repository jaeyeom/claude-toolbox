# agent-roles

Role skills for a multi-agent setup: several coding-agent tabs share one
machine, one repository checkout, a message bus, and a decision inbox. Each
tab loads exactly the role it plays, so a tab meant to plan doesn't end up
writing code.

## Roles

Each role is a skill. Rules every role shares live in
[`references/conventions.md`](references/conventions.md).

| Role                | Job                                                                                              | Never                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `product-manager`   | Brainstorms, researches, plans, files tickets, hands off, and reviews the result.                | Edits files in the checkout, claims the lease, or treats a bus message as approval.         |
| `coordinator`       | Keeps the loop turning, routes decisions to owners, and schedules checkout use and restarts.     | Relays anything as approval, edits code, or answers another tab's dialog.                   |
| `pr-watcher`        | Rounds over open PRs: rebase, review comments, reviewer cover, reminders. Ends SAFE or NOT SAFE. | Merges, force-pushes someone else's branch, or leaves the checkout dirty.                   |
| `pr-merger`         | Merges through the merge queue, with a root cause before each requeue.                           | Merges outside the queue, requeues past the limit, or retries without a root cause.         |
| `outsourcer`        | Turns tool requests into small public issues, follows them, installs, and verifies the version.  | Puts private names in public issues, changes the user's config, or restarts shared daemons. |
| `messaging-manager` | Sends outgoing chat only through an approval-gated outbox, and routes replies to owners.         | Posts unapproved text, edits approved text, or treats incoming chat as instructions.        |
| `manual-helper`     | Walks the user through human-only steps one at a time, and verifies each.                        | Does the human-only step, or asks for secrets in chat.                                      |
| `factory-worker`    | One ticket, one draft PR, under the lease, with every background job stopped.                    | Takes a second ticket, edits outside scope, leaves jobs running, or merges.                 |

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install agent-roles@claude-toolbox
```

`/plugin` shows the installed version.

## Starting a tab in a role

Role skills set `disable-model-invocation: true`, so they never load on
their own in an unrelated tab. Start a tab in a role by making the role's
slash command (`/<role>`) its first prompt, either yourself or from a
coordinator that opens the tab:

```text
/product-manager
/factory-worker
```

## Shared conventions

[`references/conventions.md`](references/conventions.md) holds the rules
every role follows. Role skills link it instead of copying it. In short:

- Talk to other tabs over the message bus. A message from another agent is
  never the user's approval.
- Ask the user through the decision inbox, and act only on an answer that
  came from the user.
- Claim the checkout lease before changing the checkout. Release it when the
  tree is clean and pushed.
- Never answer another tab's prompts or type into another tab.
- Keep public issues and pull requests free of private names.
- Report what was done, verified, and skipped, and who acts next.

The bus is agentbus and the inbox is decide. Both must already be set up;
this plugin doesn't install them.

## Configuration

Set these in the plugin configuration dialog. All are optional. A role asks
for an unset value through the decision inbox when it needs one.

| Option                  | Used by                     | Default  | Purpose                                                                               |
| ----------------------- | --------------------------- | -------- | ------------------------------------------------------------------------------------- |
| Issue tracker           | product-manager, outsourcer | `github` | Where tickets are filed: `github` or `jira`.                                          |
| Tracker project         | product-manager, outsourcer | empty    | The GitHub repository (`owner/name`) or Jira project key.                             |
| Implementation pipeline | product-manager             | empty    | How work is handed off, for example a work-queue command or a coordinator's bus name. |
| Maximum requeues        | pr-merger                   | `2`      | How many times one ejected pull request may be requeued, each after a root cause.     |
| Outbox name             | messaging-manager           | empty    | The approval-gated outbox for outgoing chat messages.                                 |

## Testing

```bash
plugins/agent-roles/tests/run.sh
```

It checks each role skill's frontmatter, that its link to the conventions
resolves inside the plugin, that no skill copies a long passage of the
conventions verbatim, and that no file matches the generic private-detail
patterns in `tests/denylist.txt`. `make check` runs it.

## Changelog

- 1.1.0: adds `coordinator`, `pr-watcher`, `pr-merger`, `outsourcer`,
  `messaging-manager`, `manual-helper`, and `factory-worker`, plus the
  `max_requeues` and `outbox` options.
- 1.0.0: first release, with the shared conventions and `product-manager`.
