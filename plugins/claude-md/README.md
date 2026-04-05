# claude-md

Write effective CLAUDE.md files containing only tacit knowledge that AI agents
cannot derive from the codebase.

## Features

- **Tacit knowledge enforcement** — Rejects content derivable from linters,
  config files, `ls`, or `grep`. Only genuine tribal knowledge belongs.
- **Create, review, improve** — Supports writing new CLAUDE.md files, reviewing
  existing ones against the quality bar, and refactoring to remove derivable
  content.
- **Directory scoping** — CLAUDE.md files can target any directory subtree.
  Subdirectory files supplement parent files.
- **PR review mining** — Extracts tacit knowledge from code review comments on
  merged PRs. Recurring reviewer feedback often reveals undocumented rules.
- **Structured review output** — Review mode produces a keep/remove/add verdict
  with explanations for each item.

## Usage

```
/claude-md                  # Create a CLAUDE.md for the project root
/claude-md review           # Review the existing CLAUDE.md
/claude-md improve          # Refactor to strengthen tacit knowledge
/claude-md path/to/dir      # Scope to a specific directory
```

## Quality Bar

Every item in a CLAUDE.md must pass:

- Would an agent reading source code and tool configs miss this?
- Does it describe a rule not enforced by tooling?
- Does it give concrete steps, not vague guidance?

See the skill for the full checklist, good/bad examples, and anti-pattern table.

## AGENTS.md Compatibility

The skill supports optional AGENTS.md symlink creation for tools that look for
`AGENTS.md` instead of `CLAUDE.md`. To opt in, add `<!-- agents-md-compat -->`
anywhere in your CLAUDE.md. The skill will then offer to create an `AGENTS.md`
symlink pointing to `CLAUDE.md`. A separate `scripts/check-agents-md.sh`
validator enforces this convention in CI.
