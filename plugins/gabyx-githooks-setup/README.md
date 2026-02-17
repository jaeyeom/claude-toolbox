# Gabyx Githooks Setup Plugin

A skill for setting up shared Git hooks using [gabyx/Githooks](https://github.com/gabyx/Githooks) manager.

## Components

| Component              | Type   | Description                                         |
| ---------------------- | ------ | --------------------------------------------------- |
| `gabyx-githooks-setup` | Skill  | Guides setup of shared hooks via gabyx/Githooks CLI |
| `scripts/bootstrap.sh` | Script | Standalone bootstrap for cloud/CI environments      |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install gabyx-githooks-setup
```

## Prerequisites

[gabyx/Githooks](https://github.com/gabyx/Githooks) must be installed on the system. The bootstrap script handles this automatically; the skill refers to `INSTALL.md` for manual methods.

## Usage

### Skill (interactive, via Claude)

Ask to set up githooks and the skill will apply:

- "Set up githooks in this repo"
- "Apply shared githooks to this project"
- "Add repo-specific shared hooks for this project"

### Bootstrap script (non-interactive)

For cloud environments, CI, or any case where you want a one-command setup without Claude:

```bash
# Install + configure globally + activate in the current repo
./scripts/bootstrap.sh

# Install + configure globally only (no repo activation)
./scripts/bootstrap.sh --global
```

The script:

1. Installs gabyx/Githooks if missing (non-interactive).
2. Enables the non-interactive runner globally.
3. Registers `jaeyeom/shared-githooks` as a global shared hooks repo.
4. If inside a git repo (and `--global` is not set): activates hooks, removes replaced hooks, updates shared hooks, and trusts the `jaeyeom-shared-githooks` namespace.

Override the shared hooks repo or namespace via environment variables:

```bash
SHARED_HOOKS_URL=https://github.com/you/your-hooks.git \
SHARED_HOOKS_NS="ns:your-namespace/**" \
  ./scripts/bootstrap.sh
```
