# Claude Toolbox — Development Conventions

## Versioning

- **Bump the version** in both `plugin.json` and `marketplace.json` when making meaningful changes to a plugin (new features, behavior changes, bug fixes).
- Use [semver](https://semver.org/): patch for fixes, minor for features, major for breaking changes.
- Commit the version bump separately with the message pattern: `chore(<plugin-name>): bump version to X.Y.Z`. If the version was already bumped in the feature/fix commit, do **not** create a separate version-bump commit (it would be a no-op).

## Commit Messages

- Follow [Conventional Commits](https://www.conventionalcommits.org/) with a plugin scope: `feat(<plugin-name>): ...`, `fix(<plugin-name>): ...`, `chore(<plugin-name>): ...`.
- Keep the subject line at 72 characters or fewer (enforced by a commit-msg hook).

## Git Hooks

- **NEVER** skip, disable, or bypass git hooks (e.g. `GITHOOKS_SKIP_UNTRUSTED_HOOKS`, `GITHOOKS_DISABLE`, `--no-verify`) without explicit user permission.
- If a hook fails due to untrusted hooks, ask the user how to proceed rather than silently skipping.
- Shared hooks from `jaeyeom-shared-githooks` are trusted via `git hooks trust hooks --pattern "ns:jaeyeom-shared-githooks/**"`.

## Validation

- A pre-commit hook runs `make -j check` which includes Biome formatting/linting and `scripts/validate-marketplace.sh`.
- The marketplace validator checks: plugin.json fields, directory/marketplace sync, name and version consistency, SKILL.md frontmatter, and hook script executability.

## Plugin Hooks

- Define hooks in `hooks/hooks.json` (not `settings.json`). Use the wrapper format: `{"hooks": {"PreToolUse": [...]}}`.
- Use `${CLAUDE_PLUGIN_ROOT}` (not `$CLAUDE_PLUGIN_DIR`) to reference files relative to the plugin directory.

## Pull requests
This repository squash-merges with the pull request title and description
as the commit message. HTML comments (`<!-- ... -->`) in the PR body are
copied into `git log` even though GitHub hides them in the rendered
description.

When creating or updating a PR:
- Do not copy `<!-- ... -->` hints from a PR template into the submitted
  body. They are compose-time hints only.
- Delete unused optional sections instead of leaving them empty.

A workflow calls
`jaeyeom/experimental/.github/workflows/strip-pr-html-comments.yml` as a
backstop.

## Pull requests
This repository squash-merges with the pull request title and description
as the commit message. HTML comments (`<!-- ... -->`) in the PR body are
copied into `git log` even though GitHub hides them in the rendered
description.

When creating or updating a PR:
- Do not copy `<!-- ... -->` hints from a PR template into the submitted
  body. They are compose-time hints only.
- Delete unused optional sections instead of leaving them empty.

A workflow calls
`jaeyeom/experimental/.github/workflows/strip-pr-html-comments.yml` as a
backstop.

## Task Sources
- Local: TODO.md
- GitHub Issues: state open, repo jaeyeom/claude-toolbox

<!-- agents-md-compat -->
