# Installing jaeyeom/Githooks

This guide covers installing the [jaeyeom/Githooks](https://github.com/jaeyeom/Githooks) hook manager.

## Installation methods

### Quick install (recommended)

The bootstrap script downloads the release from GitHub, verifies checksums, and launches the installer:

```bash
curl -sL https://raw.githubusercontent.com/jaeyeom/Githooks/main/scripts/install.sh | bash
```

For non-interactive installation (no prompts):

```bash
curl -sL https://raw.githubusercontent.com/jaeyeom/Githooks/main/scripts/install.sh | bash -s -- -- --non-interactive
```

`scripts/install.sh` downloads release binaries from `jaeyeom/githooks`. The fork publishes no GitHub releases yet, so this install fails until a release with assets is published.

### Nix

```bash
nix profile install "github:jaeyeom/Githooks?dir=nix"
githooks-cli installer
```

> **Note:** The fork has no release tags, so this tracks the default branch.

### Ansible

There is a ready-made playbook at [`jaeyeom/experimental`](https://github.com/jaeyeom/experimental) under `devtools/setup-dev/ansible/githooks-cli.yml`. That playbook:

1. Checks whether `githooks-cli` is already on `$PATH`.
2. Falls back to `git hooks --version` to detect an existing install.
3. Downloads and runs the official install script with `--non-interactive` if neither is found.

Usage (assuming the playbook and its dependencies are checked out):

```bash
ansible-playbook devtools/setup-dev/ansible/githooks-cli.yml
```

## Post-install verification

After installation, confirm:

```bash
git hooks --version
```

You should see a version string like `Githooks vX.Y.Z`.

## Uninstallation

```bash
git hooks uninstaller
```

## References

- [jaeyeom/Githooks README](https://github.com/jaeyeom/Githooks)
- [jaeyeom/experimental Ansible playbook](https://github.com/jaeyeom/experimental/blob/main/devtools/setup-dev/ansible/githooks-cli.yml)
