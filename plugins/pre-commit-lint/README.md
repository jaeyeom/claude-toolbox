# Pre-Commit Lint Plugin

Automatically run linters before Claude Code commits changes.

## Components

| Component         | Type   | Description                    |
| ----------------- | ------ | ------------------------------ |
| `PreToolUse` hook | Hook   | Runs linters before git commit |
| `lint.sh`         | Script | Multi-language linting script  |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install pre-commit-lint
```

After installation, copy the hook script to your project:

```bash
mkdir -p .claude/hooks
cp ~/.claude/plugins/pre-commit-lint/hooks/lint.sh .claude/hooks/
chmod +x .claude/hooks/lint.sh
```

## Supported Languages

| Language              | Linters               |
| --------------------- | --------------------- |
| JavaScript/TypeScript | ESLint, Biome         |
| Python                | Ruff, Flake8          |
| Go                    | golangci-lint, go vet |
| Rust                  | Clippy                |

## How It Works

1. Hook triggers before `git commit` commands
2. Script detects staged file types
3. Runs appropriate linters for each language (report-only)
4. Blocks commit if linting fails
5. Allows commit if all checks pass

## Configuration

The hook uses your project's existing linter configuration:

- `.eslintrc.*` for ESLint
- `biome.json` for Biome
- `ruff.toml` or `pyproject.toml` for Ruff
- `.golangci.yml` for golangci-lint

## Customization

Edit `.claude/hooks/lint.sh` to:

- Add additional linters
- Change linter flags
- Skip certain file types

## License

MIT
