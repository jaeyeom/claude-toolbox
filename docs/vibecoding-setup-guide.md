# Vibecoding Setup Guide

Use this guide when the question is "which claude-toolbox plugins should I
install for my workflow, and in what order?"

This is intentionally a workflow guide, not a full plugin catalog. The root
[README](../README.md) is the project landing page, and each plugin's
`README.md` is the source of truth for that plugin's details.

## Choose a Bundle

Pick the smallest bundle that matches your situation.

| Bundle | Use when | Install |
| --- | --- | --- |
| Solo developer | You want safer commits and a lightweight task loop | `git-guardrails`, `next-action`, `todo` |
| Go project | You want local quality gates, CI parity, and Go conventions | `git-guardrails`, `next-action`, `go-dev`, `makefile-workflow`, `gabyx-githooks-setup`, `ci-workflow` |
| Python project | You want local quality gates, CI parity, and Python conventions | `git-guardrails`, `next-action`, `python-dev`, `makefile-workflow`, `gabyx-githooks-setup`, `ci-workflow` |
| Team with Jira | You already have a base bundle and need ticket operations in Claude Code | `jira-commands`, `jira-edit-description` |
| Full suite | You want the recommended default workflow (see [all plugins](../README.md) for the complete list) | `git-guardrails`, `gabyx-githooks-setup`, `makefile-workflow`, `ci-workflow`, `go-dev`, `next-action`, `todo`, `gh-issue-resolver`, `claude-md`, `semgrep-review`, `sandbox-helpers` |

## Installation Recipes

### Solo Developer

```bash
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install git-guardrails
/plugin install next-action
/plugin install todo
```

Use this when you want the shortest path to a safer AI coding loop.

### Go Project

```bash
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install git-guardrails
/plugin install next-action
/plugin install go-dev
/plugin install makefile-workflow
/plugin install gabyx-githooks-setup
/plugin install ci-workflow
```

Use this when you want `git commit`, `make check`, and CI to reinforce the same
rules.

### Python Project

```bash
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install git-guardrails
/plugin install next-action
/plugin install python-dev
/plugin install makefile-workflow
/plugin install gabyx-githooks-setup
/plugin install ci-workflow
```

Use this when you want `git commit`, `make check`, and CI to reinforce the same
rules, with Python conventions (uv/ruff/pytest, inject-don't-patch).

### Team with Jira

Install this on top of one of the bundles above:

```bash
/plugin install jira-commands
/plugin install jira-edit-description
```

### Full Suite

This installs the recommended default set. Additional plugins such as
`python-dev`, `create-lang-dev-skill`, `biome-vcs-integration`, `jira-commands`,
`jira-edit-description`, `apply-figma-make`, and `cloudflare-macos-fix` are
available in the marketplace — install them individually as needed.

```bash
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install git-guardrails
/plugin install gabyx-githooks-setup
/plugin install makefile-workflow
/plugin install ci-workflow
/plugin install go-dev
/plugin install next-action
/plugin install todo
/plugin install gh-issue-resolver
/plugin install claude-md
/plugin install semgrep-review
/plugin install sandbox-helpers
```

## Minimal Configuration

After installing `next-action`, give it explicit task sources in your project's
`CLAUDE.md`:

```markdown
## Task Sources
- Local: TODO.md
- GitHub Issues: state open, assigned to @me
```

If you use a scaffolding tool such as `roboco-cli`, keep the generated
`CLAUDE.md` and layer claude-toolbox on top. A good division of responsibility
is:
- the scaffolder creates the project foundation
- claude-toolbox adds task flow, quality gates, and workflow conventions

## How the Bundle Fits Together

Think in layers:

1. Task selection: `next-action`, `todo`, and optionally `gh-issue-resolver`.
2. Commit safety: `git-guardrails`.
3. Shared checks: `gabyx-githooks-setup` calling `make check`.
4. Project conventions: `go-dev`, `python-dev`, or another `*-dev` plugin.
5. CI parity: `ci-workflow` running the same Makefile targets.

If you are unsure what to add next, fill gaps in that order.

## Example End-to-End Workflow

1. Ask `next-action` what to work on.

```text
> /next-action

## Next Action
**[GitHub #42]** fix: pagination returns duplicate results on page boundary
Priority: High | Score: 90
```

2. Resolve the issue.

```text
> /gh-issue-resolver 42
```

3. Let the commit-quality layer run automatically.

`git-guardrails` blocks unsafe git usage. `gabyx-githooks-setup` and
`makefile-workflow` enforce shared checks through repository hooks and
`make check`.

4. Push with confidence.

```text
> git push
```

`ci-workflow` runs the same `make check` and `make build` targets in CI, so
local and remote stay aligned.

5. Track progress.

```text
> /todo done "Fix pagination bug"
> /next-action
```

Move to the next task.

## Where to Read Next

- [Docs Index](./README.md) for the overall documentation map
- [Main README](../README.md) for the project overview
- Plugin `README.md` files under `plugins/` for exact behavior and configuration
