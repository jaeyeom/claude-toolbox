---
name: gabyx-githooks-setup
description: Set up shared Git hooks using gabyx/Githooks (not standard git hooks). Use when a user asks to set up githooks, apply shared hooks, or configure hook repositories in a project.
autouse: false
---

# Githooks Setup (gabyx/Githooks)

Set up and configure shared Git hooks using the [gabyx/Githooks](https://github.com/gabyx/Githooks) manager. This is **not** the standard `git config core.hooksPath` system — it is a dedicated hooks manager that supports shared hook repositories, parallel execution, trust verification, and more.

## Important

The `git hooks` CLI (note the space) is provided by gabyx/Githooks. Do **not** confuse it with standard git hook configuration. All commands below assume Githooks is already installed on the system.

## Instructions

### 1. Determine the user's intent

Ask which setup the user wants:

- **Global shared hooks** — The shared hook repository (`jaeyeom/shared-githooks`) is already registered in the global Githooks configuration. Just activate Githooks in the current repo.
- **Repo-specific shared hooks** — Add a `.githooks/.shared.yaml` file so the repo pulls hooks from a specific shared repository, independent of the user's global config.

### 2. Global shared hooks (already configured globally)

When the shared hook repository is already in the global list (`git config --global --get-all githooks.shared`), all you need is:

```bash
git hooks install
```

This activates Githooks in the current repository. It rewires `.git/hooks` to the Githooks runner, which then discovers and executes both local (`.githooks/`) and globally-configured shared hooks.

After installation, update shared hooks:

```bash
git hooks shared update
```

Verify with:

```bash
git hooks list
```

### 3. Repo-specific shared hooks

To configure a shared hook repository for a single repo without depending on global config:

1. Create the shared config file:

```yaml
# .githooks/.shared.yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

2. Install Githooks in the repo (if not already active):

```bash
git hooks install
```

3. Pull the shared hooks:

```bash
git hooks shared update
```

4. Commit `.githooks/.shared.yaml` so other contributors get the same hooks.

### 4. Useful commands

| Command | Purpose |
|---------|---------|
| `git hooks install` | Activate Githooks in current repo |
| `git hooks uninstall` | Remove Githooks from current repo |
| `git hooks shared update` | Pull latest shared hook repositories |
| `git hooks list` | Show all hooks that will run and their status |
| `git hooks config` | Manage Githooks settings |
| `git hooks ignore add` | Exclude specific hooks by pattern |
| `git hooks shared root ns:<namespace>` | Show shared repo root for a namespace |

### 5. Trust and verification

Githooks verifies hook checksums. When new or modified hooks are detected, it prompts for trust confirmation. To pre-trust all hooks in a repo, create a `.githooks/trust-all` file.

### 6. Shared hook repository structure

Shared repos organize hooks as:

```
<repo>/.githooks/<hook-type>/<script>
```

For example:
```
.githooks/pre-commit/format-check.sh
.githooks/commit-msg/conventional-commits.sh
```

Each shared repo can declare a namespace via `.githooks/.namespace` to avoid naming conflicts.
