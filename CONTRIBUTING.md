# Contributing to Claude Toolbox

Thank you for your interest in contributing! This guide will help you create and submit plugins.

## Getting Started

1. Fork this repository
2. Clone your fork locally
3. Create a new branch for your plugin
4. Follow the structure below
5. Submit a pull request

## Plugin Structure

Each plugin is a directory under `plugins/` following the official Claude Code format.

The root `.claude-plugin/marketplace.json` is the marketplace registry that lists all available plugins.

```
.claude-plugin/
└── marketplace.json         # Marketplace registry (lists all plugins)

plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata (REQUIRED)
├── commands/                # Slash commands (optional)
│   └── my-command.md
├── skills/                  # Skills (optional)
│   └── my-skill/
│       └── SKILL.md
├── agents/                  # Subagents (optional)
│   └── my-agent.md
├── hooks/                   # Hook scripts (optional)
│   └── script.sh
├── settings.json            # Hook configuration (optional)
├── .mcp.json               # MCP server config (optional)
└── README.md               # Documentation (REQUIRED)
```

## Required Files

### `.claude-plugin/plugin.json`

Every plugin must have this metadata file:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Brief description of what the plugin does",
  "author": {
    "name": "Your Name"
  },
  "repository": "https://github.com/your-username/your-repo",
  "license": "MIT",
  "keywords": ["relevant", "keywords"]
}
```

### `README.md`

Document your plugin with:
- What the plugin does
- Installation instructions
- Usage examples
- Configuration options

## Component Formats

### Commands (`commands/<name>.md`)

Slash commands are user-invoked via `/command-name`:

```markdown
---
description: Brief description shown in /help
argument-hint: [arg1] [--option]
allowed-tools: Read, Grep, Bash
model: claude-3-5-sonnet-20241022
---

# Command Instructions

What this command does and how to execute it.

Use $ARGUMENTS to access user input.
```

**Frontmatter fields:**
- `description` - Shown in `/help` (required)
- `argument-hint` - Usage hint for arguments
- `allowed-tools` - Tools the command can use
- `model` - Specific model to use
- `disable-model-invocation` - Prevent auto-invocation

### Skills (`skills/<name>/SKILL.md`)

Skills are model-invoked (Claude decides when to use them):

```markdown
---
name: my-skill
description: What this skill does and when Claude should use it
allowed-tools: Read, Grep, Glob
---

# Skill Instructions

Detailed instructions for Claude when this skill activates.
```

**Frontmatter fields:**
- `name` - Unique identifier (lowercase, hyphens, max 64 chars)
- `description` - When to use this skill (max 1024 chars)
- `allowed-tools` - Restrict available tools

**Key difference from commands:** Skills activate automatically based on context.

### Agents (`agents/<name>.md`)

Subagents are specialized AI assistants for specific tasks:

```markdown
---
name: my-agent
description: When to invoke this agent. Use "proactively" for auto-invocation.
tools: Bash, Read, Grep, Glob
model: sonnet
permissionMode: default
---

You are a specialized agent for [specific task].

## When Invoked

1. First step
2. Second step
3. ...

## Output Format

How to format results...
```

**Frontmatter fields:**
- `name` - Unique identifier
- `description` - When to use (include "proactively" for auto-use)
- `tools` - Comma-separated tool list (omit to inherit all)
- `model` - `sonnet`, `opus`, `haiku`, or `inherit`
- `permissionMode` - `default`, `acceptEdits`, `bypassPermissions`, `plan`
- `skills` - Skills to auto-load

### Hooks (`settings.json`)

Hooks run shell commands at specific events:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "path/to/script.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write \"$file_path\""
          }
        ]
      }
    ]
  }
}
```

**Hook events:**
- `PreToolUse` - Before tool calls (can block)
- `PostToolUse` - After tool calls
- `Notification` - When notifications sent
- `Stop` - When Claude finishes responding

**Hook types:**
- `command` - Run shell command
- `prompt` - Send prompt to Claude

### MCP Servers (`.mcp.json`)

Connect to external tools via Model Context Protocol:

```json
{
  "server-name": {
    "command": "uvx",
    "args": ["mcp-server-package", "--option", "value"],
    "env": {
      "API_KEY": "${MCP_API_KEY}"
    }
  }
}
```

## Guidelines

### Quality Standards

- **Tested**: Verify your plugin works with current Claude Code
- **Documented**: Include clear usage instructions
- **Focused**: Each plugin should have a clear purpose
- **Secure**: No hardcoded credentials

### Naming Conventions

- Plugin names: lowercase with hyphens (`my-plugin-name`)
- Be descriptive but concise
- Avoid generic names like `helper` or `utils`

### Versioning

Follow [Semantic Versioning](https://semver.org/):
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## Submitting Your Plugin

1. Create your plugin under `plugins/`
2. Test it locally with Claude Code
3. Commit and push to your fork
4. Create a pull request with:
   - Clear title: `Add <plugin-name> plugin`
   - Description of what the plugin does
   - Any special requirements

## Questions?

- Open an issue for questions or suggestions
- Check existing plugins for examples
- See [docs/claude/](./docs/claude/) for official documentation
