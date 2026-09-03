# Claude Toolbox

A curated marketplace of Claude Code plugins for building a reliable
AI-assisted development workflow.

claude-toolbox is opinionated about a few things:
- Commits should be hard to mess up.
- Local checks and CI should run the same workflow.
- Agents should know your task flow and language conventions.

## The Workflow

These plugins work together to create a reliable development workflow:

```
┌─────────────────────────────────────────────────────────┐
│  gabyx-githooks-setup                                   │
│  Shared Git hooks run automatically on commit and push  │
│                         │                               │
│                         ▼                               │
│  makefile-workflow                                      │
│  Hooks call `make check` - format, lint, test, build    │
│                    │              │                     │
│                    ▼              ▼                     │
│  *-dev (go-dev, python-dev)  ci-workflow                │
│  Language-specific     CI calls the same                │
│  conventions the       Makefile targets                 │
│  checks enforce        via GitHub Actions               │
└─────────────────────────────────────────────────────────┘
```

Add the task-management layer on top:
- `next-action` finds the next item worth doing.
- `todo` tracks local work.
- `gh-issue-resolver` can take an issue from its written plan through a draft pull request, stopping when the plan must change.

## Quick Start

Install the marketplace and a practical starter bundle:

```text
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install git-guardrails
/plugin install next-action
/plugin install go-dev
/plugin install makefile-workflow
/plugin install gabyx-githooks-setup
/plugin install ci-workflow
```

That gives you:
- safer git usage
- a next-task workflow
- language-aware coding guidance
- shared local checks and matching CI

This starter bundle uses `go-dev` as the language-specific plugin example.
Python projects should install `python-dev` instead. For other setups, start
with the bundle guide in
[Vibecoding Setup Guide](./docs/vibecoding-setup-guide.md), which separates
solo, Go, Python, Jira, and full-suite installs.

## Documentation

Start here based on the question you are trying to answer:

- [Docs Index](./docs/README.md): documentation map for guides, plugin docs, and reference material
- [Vibecoding Setup Guide](./docs/vibecoding-setup-guide.md): choose a bundle and wire up an end-to-end workflow
- [Contributing Guide](./CONTRIBUTING.md): create or submit a plugin to the marketplace

## Plugin Directory

Workflow:
- [gabyx-githooks-setup](./plugins/gabyx-githooks-setup)
- [makefile-workflow](./plugins/makefile-workflow)
- [ci-workflow](./plugins/ci-workflow)
- [go-dev](./plugins/go-dev)
- [python-dev](./plugins/python-dev)
- [protobuf-dev](./plugins/protobuf-dev)
- [create-lang-dev-skill](./plugins/create-lang-dev-skill)
- [biome-vcs-integration](./plugins/biome-vcs-integration)
- [claude-md](./plugins/claude-md)
- [docsync](./plugins/docsync)

Task management:
- [todo](./plugins/todo)
- [next-action](./plugins/next-action)
- [gh-issue-resolver](./plugins/gh-issue-resolver)

Jira:
- [jira-commands](./plugins/jira-commands)
- [jira-edit-description](./plugins/jira-edit-description)

Safety and security:
- [semgrep-review](./plugins/semgrep-review)
- [git-guardrails](./plugins/git-guardrails)
- [sandbox-helpers](./plugins/sandbox-helpers)

Other:
- [apply-figma-make](./plugins/apply-figma-make)
- [cloudflare-macos-fix](./plugins/cloudflare-macos-fix)
- [cleanup-worktree-disk](./plugins/cleanup-worktree-disk)

Each plugin directory contains its own `README.md`, which is the source of truth
for installation details, configuration, and examples.

## Reference Documentation

The `docs/claude/` directory mirrors Claude Code reference material used by this
repo:

- [Skills](./docs/claude/skills.md)
- [Slash Commands](./docs/claude/slash-commands.md)
- [Subagents](./docs/claude/sub-agents.md)
- [Hooks](./docs/claude/hooks-guide.md)

## License

MIT
