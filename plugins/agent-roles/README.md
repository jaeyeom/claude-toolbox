# agent-roles

Role skills for a multi-agent setup: several coding-agent tabs share one
machine, one repository checkout, a message bus, and a decision inbox. Each
tab loads exactly the role it plays, so a tab meant to plan doesn't end up
writing code.

## Components

| Component                   | Type      | Description                                                                         |
| --------------------------- | --------- | ----------------------------------------------------------------------------------- |
| `product-manager`           | Skill     | Brainstorms, researches, plans, files tickets, hands off, and reviews. Never codes. |
| `references/conventions.md` | Reference | Rules every role follows: messaging, decisions, the shared checkout, and reporting. |

More roles will follow in this plugin, one skill per role.

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install agent-roles@claude-toolbox
```

`/plugin` shows the installed version.

## Starting a tab in a role

Role skills set `disable-model-invocation: true`, so they never load on
their own in an unrelated tab. Start a tab in a role by making the role's
slash command its first prompt, either yourself or from a coordinator that
opens the tab:

```text
/product-manager
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

| Option                  | Default  | Purpose                                                                               |
| ----------------------- | -------- | ------------------------------------------------------------------------------------- |
| Issue tracker           | `github` | Where tickets are filed: `github` or `jira`.                                          |
| Tracker project         | empty    | The GitHub repository (`owner/name`) or Jira project key.                             |
| Implementation pipeline | empty    | How work is handed off, for example a work-queue command or a coordinator's bus name. |

## Testing

```bash
plugins/agent-roles/tests/run.sh
```

It checks each role skill's frontmatter, that its link to the conventions
resolves inside the plugin, and that no file matches the generic
private-detail patterns in `tests/denylist.txt`. `make check` runs it.

## Changelog

- 1.0.0: first release, with the shared conventions and `product-manager`.
