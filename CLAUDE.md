# Claude Toolbox — Development Conventions

## Versioning

- **Bump the version** in both `plugin.json` and `marketplace.json` when making meaningful changes to a plugin (new features, behavior changes, bug fixes).
- Use [semver](https://semver.org/): patch for fixes, minor for features, major for breaking changes.
- Commit the version bump separately with the message pattern: `chore(<plugin-name>): bump version to X.Y.Z`.

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
