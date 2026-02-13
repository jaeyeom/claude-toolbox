---
name: gabyx-githooks-setup
description: Set up shared Git hooks using gabyx/Githooks (not standard git hooks). Use when a user asks to set up githooks, apply shared hooks, or configure hook repositories in a project.
autouse: false
---

# Githooks Setup (gabyx/Githooks)

Set up and configure shared Git hooks using the [gabyx/Githooks](https://github.com/gabyx/Githooks) manager. This is **not** the standard `git config core.hooksPath` system — it is a dedicated hooks manager that supports shared hook repositories, parallel execution, trust verification, and more.

## Important

The `git hooks` CLI (note the space) is provided by gabyx/Githooks. Do **not** confuse it with standard git hook configuration.

## Instructions

### 0. Verify Githooks is installed

Before proceeding, check whether gabyx/Githooks is installed:

```bash
git hooks --version 2>/dev/null
```

If this command fails or is not found, Githooks is **not** installed. Refer to `INSTALL.md` in this skill directory for installation methods, then return here to continue setup.

### 1. Determine the user's intent

Ask which setup the user wants:

- **Global shared hooks** — A shared hook repository is already registered in the global Githooks configuration. Just activate Githooks in the current repo.
- **Repo-specific shared hooks** — Add a `.githooks/.shared.yaml` file so the repo pulls hooks from a specific shared repository, independent of the user's global config.

If the user doesn't already have a shared hook repository in mind, ask if they'd like to use [`jaeyeom/shared-githooks`](https://github.com/jaeyeom/shared-githooks) (authored by the same person who wrote this plugin). It includes pre-commit checks (whitespace, non-ASCII filenames, Go linting) and commit-msg checks (subject length, conventional format). The user should review its contents before opting in.

### 2. Global shared hooks (already configured globally)

When the shared hook repository is already in the global list (`git config --global --get-all githooks.shared`), all you need is:

```bash
git hooks install
```

This activates Githooks in the current repository. It rewires `.git/hooks` to the Githooks runner, which then discovers and executes both local (`.githooks/`) and globally-configured shared hooks.

After installation, check for replaced hooks (see section 2a below), then update shared hooks:

```bash
git hooks shared update
```

Verify with:

```bash
git hooks list
```

### 2a. Check for replaced hooks

When `git hooks install` finds existing hook scripts in `.git/hooks/`, it renames them to `*.replaced.githook` (e.g., `pre-commit` → `pre-commit.replaced.githook`). The Githooks runner executes these **in addition to** shared hooks, which causes duplicate checks if the shared hooks already cover the same functionality.

After running `git hooks install`, check for replaced hooks:

```bash
ls .git/hooks/*.replaced.githook 2>/dev/null
```

If any are found:

1. **List them** to the user and explain that these are pre-existing hook scripts that Githooks renamed and will continue to execute alongside shared hooks.
2. **Recommend removal** if the shared hooks repository already covers the same hook types (e.g., if shared hooks include `pre-commit` checks and there is a `pre-commit.replaced.githook`, the pre-commit checks will run twice). Provide the specific `rm` commands, for example:

```bash
rm .git/hooks/pre-commit.replaced.githook
rm .git/hooks/commit-msg.replaced.githook
rm .git/hooks/pre-push.replaced.githook
```

3. If the user is unsure whether the replaced hooks are redundant, suggest running `git hooks list` to see all hooks that will execute, and comparing the replaced hook contents against the shared hooks.

### 3. Repo-specific shared hooks

To configure a shared hook repository for a single repo without depending on global config:

1. Create the shared config file (replace the URL with the chosen shared hook repository):

```yaml
# .githooks/.shared.yaml
version: 1
urls:
  - "https://github.com/<owner>/<shared-hooks-repo>.git@main"
```

2. Install Githooks in the repo (if not already active):

```bash
git hooks install
```

3. Check for replaced hooks (see section 2a above) and remove any that are redundant with the shared hooks.

4. Pull the shared hooks:

```bash
git hooks shared update
```

5. Commit `.githooks/.shared.yaml` so other contributors get the same hooks.

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

### 5. Updating shared hooks

Shared hook repositories update automatically after `post-merge` (i.e., `git pull`). To update manually:

```bash
git hooks shared update
```

This pulls the latest from all configured shared hook repositories (both global and repo-specific). Run this after upstream hooks are updated to get fixes.

**Note:** `git hooks shared update` only updates **shared** hooks. Local hooks in the repo's own `.githooks/` directory are part of the repo itself and are updated via normal `git pull`/`git checkout`.

On servers with multiple users, disable automatic updates to avoid parallel invocations:

```bash
git hooks config disable-shared-hooks-update --set
```

### 6. Trust and non-interactive mode

Githooks verifies hook checksums. When new or modified hooks are detected, it prompts for trust confirmation. This can block non-interactive operations like `git commit --amend --no-edit` or CI pipelines.

**Non-interactive runner (recommended for local development):**

```bash
git hooks config non-interactive-runner --enable --global
```

This takes default answers for all non-fatal prompts without warnings.

**Trusting a specific shared hook repository (recommended):**

Prefer trusting hooks selectively by namespace rather than trusting everything blindly. Each shared hook repo has a namespace (defined in `.githooks/.namespace`, or a SHA1 prefix of its URL if not set). Use `git hooks list` to see namespace paths, then trust by pattern:

```bash
# See namespace paths for all hooks
git hooks list

# Trust all hooks from a specific shared repo by namespace
git hooks trust hooks --pattern "ns:jaeyeom-shared-githooks/**"
```

This is safer than `trust-all` because it only trusts hooks from a known, authored source. When the shared repo updates, you may need to re-run this command to trust the new checksums.

**Other trust options:**

| Method | Scope | Effect |
|--------|-------|--------|
| `git hooks trust hooks --pattern "ns:<namespace>/**"` | Per-repo, per-user | Trusts hooks matching a namespace pattern — **preferred approach** |
| `git hooks trust hooks --all` | Per-repo, per-user | Trusts all currently active hooks |
| `git hooks trust` | Per-repo, per-user | Marks repo as trusted for the current user (each collaborator should run this locally) |
| `.githooks/trust-all` file | Per-repo | Marks repo as trusted — do **not** commit this file; add it to `.gitignore` instead, as trust is a per-user security decision |
| `git hooks config trust-all --accept` | Per-repo | Auto-accepts **all** current and future hooks (use with caution — prefer namespace-based trust instead) |
| `git hooks config trust-all --reset` | Per-repo | Reverts trust-all decision |
| `GITHOOKS_SKIP_UNTRUSTED_HOOKS=true` | Per-session | Skips untrusted hooks silently |
| `GITHOOKS_DISABLE=1` | Per-session | Disables all Githooks entirely |

**For CI/automation**, either set `GITHOOKS_DISABLE=1` to skip hooks, or use `non-interactive-runner` with `trust-all --accept` to run hooks without prompts.

### 7. Shared hook repository structure

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
