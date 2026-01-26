# Claude Toolbox

A curated marketplace of Claude Code plugins.

## Quick Start

### Install a Plugin

```bash
# Install from this marketplace
/plugin install jaeyeom/claude-toolbox/plugins/makefile-workflow

# Or browse available plugins
/plugin
```

## Available Plugins

| Plugin                                           | Description                | Components |
| ------------------------------------------------ | -------------------------- | ---------- |
| [pre-commit-lint](./plugins/pre-commit-lint)     | Pre-commit linting hook    | Hook       |
| [makefile-workflow](./plugins/makefile-workflow) | Makefile workflow guidance | Skill      |

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
└── .mcp.json               # MCP server config (optional)
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

## Reference Documentation

See [docs/claude/](./docs/claude/) for official Claude Code documentation:

- [Skills](./docs/claude/skills.md) - Agent skills format
- [Slash Commands](./docs/claude/slash-commands.md) - Command format
- [Subagents](./docs/claude/sub-agents.md) - Agent format
- [Hooks](./docs/claude/hooks-guide.md) - Hook configuration

## License

MIT
