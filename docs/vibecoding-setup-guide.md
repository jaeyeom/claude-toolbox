# Vibecoding Setup Guide

Get productive fast with **claude-toolbox** — a curated plugin suite for
[Claude Code](https://docs.anthropic.com/en/docs/claude-code) that adds quality
gates, task management, and language-specific dev support to your vibecoding
workflow.

This guide is tool-agnostic. Whether you bootstrap your repo with
[roboco-cli](https://github.com/roboco-io/roboco-cli), manually, or any other
scaffolding tool, the plugins work the same way.

## What Is claude-toolbox?

claude-toolbox is a marketplace of Claude Code plugins. Each plugin adds a
focused capability — a skill, a hook, or a slash command — that Claude Code
picks up automatically. Plugins layer together so commit quality, task flow, and
language idioms reinforce each other without manual coordination.

## Plugin Catalog

### Quality Gates

| Plugin | What it does |
|--------|-------------|
| [git-guardrails](../plugins/git-guardrails) | Hook that blocks dangerous git commands (`--no-verify`, bulk `git add`, `find -exec`) |
| [pre-commit-lint](../plugins/pre-commit-lint) | Hook that auto-detects staged file types and runs the right linters before commit |
| [gabyx-githooks-setup](../plugins/gabyx-githooks-setup) | Sets up [gabyx/Githooks](https://github.com/gabyx/Githooks) so every contributor runs the same shared hooks |
| [semgrep-review](../plugins/semgrep-review) | Triages semgrep security findings — fixes real issues, suppresses false positives |

### Build & CI

| Plugin | What it does |
|--------|-------------|
| [makefile-workflow](../plugins/makefile-workflow) | Creates consistent `check`, `format`, `lint`, `test`, `build` Makefile targets |
| [ci-workflow](../plugins/ci-workflow) | Generates GitHub Actions that call the same Makefile targets, so CI mirrors local |

### Task Management

| Plugin | What it does |
|--------|-------------|
| [next-action](../plugins/next-action) | Scans TODO files, code TODOs, and GitHub Issues to recommend what to work on next |
| [todo](../plugins/todo) | Manages a `TODO.md` file with priorities and completion tracking |
| [gh-issue-resolver](../plugins/gh-issue-resolver) | Resolves a GitHub issue end-to-end: assigns, investigates, fixes, commits |

### Language & Framework Support

| Plugin | What it does |
|--------|-------------|
| [go-dev](../plugins/go-dev) | Go best practices — idiomatic patterns, error handling, testing, build system detection |
| [create-lang-dev-skill](../plugins/create-lang-dev-skill) | Mines your PR reviews and codebase to create a custom `*-dev` skill for any language |
| [claude-md](../plugins/claude-md) | Writes effective CLAUDE.md files containing only tacit knowledge |
| [biome-vcs-integration](../plugins/biome-vcs-integration) | Configures Biome to respect `.gitignore` via VCS integration |

### Integrations

| Plugin | What it does |
|--------|-------------|
| [jira-commands](../plugins/jira-commands) | Slash commands for Jira: create bugs/tasks, resolve, update, plan projects |
| [jira-edit-description](../plugins/jira-edit-description) | Edits Jira descriptions with proper wiki markup formatting |
| [apply-figma-make](../plugins/apply-figma-make) | Applies Figma Make exported designs to website pages |

### Environment Fixes

| Plugin | What it does |
|--------|-------------|
| [sandbox-helpers](../plugins/sandbox-helpers) | Diagnoses macOS sandbox TLS failures for CLI tools like `gh` and `jira` |
| [cloudflare-macos-fix](../plugins/cloudflare-macos-fix) | Fixes sharp module installation failures on macOS Apple Silicon |

## Recommended Bundles

### Solo Developer

For any project where you want safe commits and a task-driven workflow:

```bash
/plugin install git-guardrails
/plugin install next-action
/plugin install todo
```

**git-guardrails** prevents accidental `--no-verify` and bulk staging.
**next-action** tells you what to work on. **todo** keeps track of it.

### Go Project

Everything above, plus Go-specific tooling:

```bash
/plugin install git-guardrails
/plugin install next-action
/plugin install go-dev
/plugin install makefile-workflow
/plugin install gabyx-githooks-setup
/plugin install ci-workflow
```

**go-dev** encodes Go idioms. **makefile-workflow** creates the targets.
**gabyx-githooks-setup** wires them into git hooks. **ci-workflow** generates
GitHub Actions that call the same targets.

### Team with Jira

Add Jira integration to any bundle:

```bash
/plugin install jira-commands
/plugin install jira-edit-description
```

Now you can create and manage Jira tickets directly from Claude Code with
`/jira new-bug`, `/jira resolve`, etc.

### Full Suite

Install everything:

```bash
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install git-guardrails
/plugin install pre-commit-lint
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

## How Plugins Layer Together

```
  You type: git commit
       │
       ▼
  ┌─ git-guardrails ──────────────────────┐
  │  Blocks --no-verify and bulk git add  │
  └───────────────┬───────────────────────┘
                  │
       ▼
  ┌─ pre-commit-lint ─────────────────────┐
  │  Detects file types → runs linters    │
  └───────────────┬───────────────────────┘
                  │
       ▼
  ┌─ gabyx-githooks-setup ────────────────┐
  │  Shared hooks call make check         │
  └───────────────┬───────────────────────┘
                  │
       ▼
  ┌─ makefile-workflow ───────────────────┐
  │  make check = format + lint + test    │
  │  Rules informed by go-dev idioms      │
  └───────────────┬───────────────────────┘
                  │
       ▼
  ┌─ ci-workflow ─────────────────────────┐
  │  Same Makefile targets in GitHub CI   │
  │  Local = CI. No drift.               │
  └───────────────────────────────────────┘
```

The task management layer runs in parallel:

```
  /next-action  →  Scans TODO.md + code TODOs + GitHub Issues
       │
       ▼
  Pick a task  →  /gh-issue-resolver 42  →  Assigns, fixes, commits
       │
       ▼
  Commit triggers quality gates above
```

## Installation & Configuration

### Add the Marketplace

```bash
/plugin marketplace add jaeyeom/claude-toolbox
```

This registers the marketplace so you can browse and install plugins.

### Install Plugins

```bash
/plugin install <plugin-name>
```

Plugins are installed per-project by default. To install globally (available in
all projects):

```bash
/plugin install --global <plugin-name>
```

### Configure Task Sources

After installing **next-action**, add a task sources section to your project's
`CLAUDE.md`:

```markdown
## Task Sources
- Local: TODO.md
- GitHub Issues: state open, assigned to @me
```

This tells `/next-action` where to look without re-discovering each time.

## Integration with Repo Scaffolding Tools

Tools like [roboco-cli](https://github.com/roboco-io/roboco-cli) bootstrap
repos for AI-native development by setting up `CLAUDE.md`, hooks, and MCP
servers. claude-toolbox complements these tools:

- **roboco-cli creates the foundation** — `CLAUDE.md`, initial project
  structure, MCP server configuration
- **claude-toolbox adds the workflow layer** — quality gates, task management,
  language idioms, CI generation

They don't conflict. After scaffolding with roboco-cli (or any similar tool),
install the claude-toolbox plugins you need. The plugins read your existing
`CLAUDE.md` and adapt to your project's conventions.

## Example End-to-End Workflow

Here's a typical vibecoding session using claude-toolbox plugins:

**1. Find what to work on**

```
> /next-action

## Next Action
**[GitHub #42]** fix: pagination returns duplicate results on page boundary
Priority: High | Score: 90
```

**2. Resolve the issue**

```
> /gh-issue-resolver 42
```

Claude assigns the issue, searches the codebase for references, traces the bug,
implements the fix, and commits with `Resolves #42`.

**3. Quality gates run automatically**

The commit triggers:
- **git-guardrails** ensures no `--no-verify` bypass
- **pre-commit-lint** runs linters on staged files
- **gabyx-githooks-setup** runs shared hooks (`make check`)
- **makefile-workflow** targets run `format`, `lint`, `test`

If anything fails, Claude fixes it and re-commits.

**4. Push and CI mirrors local**

```
> git push
```

**ci-workflow** has already generated GitHub Actions that run the same `make
check` and `make build` targets. If it passed locally, it passes in CI.

**5. Track progress**

```
> /todo complete "Fix pagination bug"
> /next-action
```

Move to the next task.

## Further Reading

- [Main README](../README.md) — project overview and plugin structure
- Individual plugin READMEs linked in the catalog above
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) —
  plugins, skills, hooks, and commands
