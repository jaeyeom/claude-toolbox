# Claude Toolbox

A curated marketplace of Claude Code plugins that help you **commit and push with confidence**.

## The Workflow

These plugins work together to create a reliable development workflow:

```
┌─────────────────────────────────────────────────────────┐
│  gabyx-githooks-setup                                   │
│  Shared Git hooks run automatically on commit and push  │
│                         │                               │
│                         ▼                               │
│  makefile-workflow                                      │
│  Hooks call `make check` — format, lint, test, build    │
│                    │              │                     │
│                    ▼              ▼                     │
│  *-dev (e.g. go-dev)      ci-workflow                   │
│  Language-specific     CI calls the same                │
│  conventions the       Makefile targets                 │
│  checks enforce        via GitHub Actions               │
└─────────────────────────────────────────────────────────┘
```

1. **[gabyx-githooks-setup](./plugins/gabyx-githooks-setup)** sets up [gabyx/Githooks](https://github.com/gabyx/Githooks), a shared hooks manager. Once installed, every contributor runs the same pre-commit and commit-msg checks without manual configuration.

2. **[makefile-workflow](./plugins/makefile-workflow)** defines the targets those hooks call — `make check`, `make format`, `make lint`, `make test`, `make build` — with a consistent naming convention across Go, Node, Bazel, and mixed stacks.

3. **[ci-workflow](./plugins/ci-workflow)** generates GitHub Actions workflows that call the same Makefile targets (`make check`, `make build`), so CI mirrors your local environment exactly.

4. **[go-dev](./plugins/go-dev)** (and future `*-dev` plugins) encodes language-specific best practices: idiomatic patterns, error handling, testing conventions, and build system detection. These are the standards that the Makefile targets and hook checks enforce.

The result: you run `git commit` and the hooks verify everything locally. Push, and CI runs the same checks. No broken builds, no forgotten linters, no drift between local and CI.

## Quick Start

### Install a Plugin

```bash
# Add the marketplace
/plugin marketplace add jaeyeom/claude-toolbox

# Install plugins you need
/plugin install gabyx-githooks-setup
/plugin install makefile-workflow
/plugin install ci-workflow
/plugin install go-dev
/plugin install next-action
/plugin install git-guardrails

# Or browse available plugins
/plugin
```

## Available Plugins

### Workflow Plugins

| Plugin | Description | Type |
| --- | --- | --- |
| [gabyx-githooks-setup](./plugins/gabyx-githooks-setup) | Set up shared Git hooks using [gabyx/Githooks](https://github.com/gabyx/Githooks) manager | Skill |
| [makefile-workflow](./plugins/makefile-workflow) | Consistent `check`, `format`, `lint`, `test`, and `build` Makefile targets | Skill |
| [ci-workflow](./plugins/ci-workflow) | GitHub Actions CI workflows that mirror local Makefile targets | Skill |
| [go-dev](./plugins/go-dev) | Go development expertise — idiomatic patterns, testing, build system detection | Skill |
| [create-lang-dev-skill](./plugins/create-lang-dev-skill) | Create language-specific dev skills by mining PR reviews and codebase conventions | Skill |
| [biome-vcs-integration](./plugins/biome-vcs-integration) | Configure Biome to respect `.gitignore` via VCS integration | Skill |
| [claude-md](./plugins/claude-md) | Write effective CLAUDE.md files containing only tacit knowledge | Skill |

### Task Management Plugins

| Plugin | Description | Type |
| --- | --- | --- |
| [todo](./plugins/todo) | Manage a TODO.md file with priorities and task tracking | Skill |
| [next-action](./plugins/next-action) | Find the next highest-priority action from TODO files, code TODOs, and GitHub issues | Skill |
| [gh-issue-resolver](./plugins/gh-issue-resolver) | Resolve GitHub issues with dependency checking, investigation, and automatic commits | Skill |

### Jira Plugins

| Plugin | Description | Type |
| --- | --- | --- |
| [jira-commands](./plugins/jira-commands) | Slash commands for creating bugs, tasks, resolving issues, and planning projects | Command |
| [jira-edit-description](./plugins/jira-edit-description) | Jira issue description editor with proper wiki markup formatting | Skill |

### Safety & Security Plugins

| Plugin | Description | Type |
| --- | --- | --- |
| [pre-commit-lint](./plugins/pre-commit-lint) | Pre-commit hook that runs linters before Claude Code commits | Hook |
| [semgrep-review](./plugins/semgrep-review) | Triage semgrep findings — fix real issues, suppress false positives | Skill |
| [git-guardrails](./plugins/git-guardrails) | Block dangerous git and find commands (`--no-verify`, bulk `git add`, `find -exec`) | Hook |
| [sandbox-helpers](./plugins/sandbox-helpers) | Warn about macOS sandbox TLS failures for Go CLI tools and suggest workarounds | Hook |

### Other Plugins

| Plugin | Description | Type |
| --- | --- | --- |
| [apply-figma-make](./plugins/apply-figma-make) | Apply Figma Make exported designs to website pages | Skill |
| [cloudflare-macos-fix](./plugins/cloudflare-macos-fix) | Fix sharp module installation failure on macOS Apple Silicon for Cloudflare Workers | Skill |

## Plugin Structure

Each plugin follows the Claude Code plugin format and lives under `plugins/<plugin-name>/`:

```
.claude-plugin/
└── marketplace.json         # Marketplace registry (lists all plugins)

plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata (REQUIRED)
├── README.md                # Plugin documentation (REQUIRED)
├── commands/                # Slash commands (optional)
│   └── <command-name>.md
├── skills/                  # Skills (optional)
│   └── <skill-name>/
│       └── SKILL.md
├── agents/                  # Subagents (optional)
│   └── <agent-name>.md
├── hooks/                   # Hook scripts (optional)
│   └── *.sh
├── settings.json            # Hook configuration (optional)
└── .mcp.json                # MCP server config (optional)
```

## Component Formats

### Commands (`commands/<name>.md`)

```yaml
---
description: Brief description for /help
argument-hint: [arg1] [--option]
allowed-tools: Read, Grep, Bash
---

Instructions for the command...
```

### Skills (`skills/<name>/SKILL.md`)

```yaml
---
name: skill-name
description: When to use this skill (for auto-discovery)
allowed-tools: Read, Grep, Glob
---
Instructions for the skill...
```

### Agents (`agents/<name>.md`)

```yaml
---
name: agent-name
description: When to invoke this agent. Include "use proactively" for auto-invocation.
tools: Bash, Read, Grep, Glob
model: sonnet
---
Agent system prompt...
```

### Hooks (`settings.json`)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [{ "type": "command", "command": "script.sh" }]
      }
    ]
  }
}
```

### MCP Servers (`.mcp.json`)

```json
{
  "server-name": {
    "command": "uvx",
    "args": ["mcp-server-name", "--option", "value"]
  }
}
```

## Creating Your Own Plugin

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed instructions.

## Guides

- **[Vibecoding Setup Guide](./docs/vibecoding-setup-guide.md)** — How to combine plugins into a productive workflow, with recommended bundles and an end-to-end example.

## Reference Documentation

See [docs/claude/](./docs/claude/) for official Claude Code documentation:

- [Skills](./docs/claude/skills.md) - Agent skills format
- [Slash Commands](./docs/claude/slash-commands.md) - Command format
- [Subagents](./docs/claude/sub-agents.md) - Agent format
- [Hooks](./docs/claude/hooks-guide.md) - Hook configuration

## License

MIT
