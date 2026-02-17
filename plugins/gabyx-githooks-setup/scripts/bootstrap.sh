#!/usr/bin/env bash
# Bootstrap script for gabyx/Githooks with jaeyeom/shared-githooks.
#
# Installs the githooks manager, configures global shared hooks, sets up
# trust and non-interactive mode, and activates hooks in the current repo
# (if inside one).
#
# Usage:
#   ./bootstrap.sh              # Install + configure + activate in current repo
#   ./bootstrap.sh --global     # Install + configure only (skip repo activation)
#
# Environment variables:
#   SHARED_HOOKS_URL   Override the shared hooks repo URL
#                      (default: https://github.com/jaeyeom/shared-githooks.git)
#   SHARED_HOOKS_NS    Override the namespace trust pattern
#                      (default: ns:jaeyeom-shared-githooks/**)

set -euo pipefail

SHARED_HOOKS_URL="${SHARED_HOOKS_URL:-https://github.com/jaeyeom/shared-githooks.git}"
SHARED_HOOKS_NS="${SHARED_HOOKS_NS:-ns:jaeyeom-shared-githooks/**}"
GLOBAL_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL_ONLY=true ;;
    --help|-h)
      sed -n '2,/^$/s/^# \?//p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; }

# ------------------------------------------------------------------
# 0. Ensure required tools are available (needed by the Githooks installer)
# ------------------------------------------------------------------

# ensure_tool CMD GO_PKG GO_BIN
#   If CMD is missing, install GO_PKG via "go install" and symlink GO_BIN as CMD.
ensure_tool() {
  local cmd="$1" go_pkg="$2" go_bin="$3"
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd already available: $(command -v "$cmd")"
    return
  fi
  if command -v go &>/dev/null; then
    info "$cmd not found — installing $go_bin via Go"
    go install "$go_pkg"

    local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    export PATH="$gobin:$PATH"

    if command -v "$go_bin" &>/dev/null; then
      ln -sf "$gobin/$go_bin" "$gobin/$cmd"
      ok "$go_bin installed and symlinked as $cmd"
    else
      fail "$go_bin installation failed"
      exit 1
    fi
  else
    fail "$cmd is required but not found, and go is not available to install $go_bin"
    exit 1
  fi
}

ensure_tool jq    github.com/itchyny/gojq/cmd/gojq@latest        gojq
ensure_tool unzip github.com/jaeyeom/gozip/cmd/gounzip@latest    gounzip

# ------------------------------------------------------------------
# 1. Install gabyx/Githooks if missing
# ------------------------------------------------------------------
info "Checking for gabyx/Githooks"
if git hooks --version &>/dev/null; then
  ok "Already installed: $(git hooks --version)"
else
  info "Installing gabyx/Githooks (non-interactive)"
  curl -sL https://raw.githubusercontent.com/gabyx/githooks/main/scripts/install.sh \
    | bash -s -- -- --non-interactive
  if ! git hooks --version &>/dev/null; then
    fail "Installation failed — git hooks not found on PATH"
    exit 1
  fi
  ok "Installed: $(git hooks --version)"
fi

# ------------------------------------------------------------------
# 2. Global configuration
# ------------------------------------------------------------------
info "Configuring global settings"

# Enable non-interactive runner so hooks never prompt.
git hooks config non-interactive-runner --enable --global
ok "Non-interactive runner enabled globally"

# Register the shared hooks repo globally (skip if already present).
existing=$(git config --global --get-all githooks.shared 2>/dev/null || true)
if echo "$existing" | grep -qF "$SHARED_HOOKS_URL"; then
  ok "Shared hooks repo already registered globally"
else
  git config --global --add githooks.shared "$SHARED_HOOKS_URL"
  ok "Registered shared hooks repo: $SHARED_HOOKS_URL"
fi

# ------------------------------------------------------------------
# 3. Activate in the current repo (unless --global)
# ------------------------------------------------------------------
if [ "$GLOBAL_ONLY" = true ]; then
  info "Skipping repo activation (--global mode)"
else
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    info "Activating githooks in current repo"

    git hooks install
    ok "Githooks installed in repo"

    # Remove replaced hooks to avoid duplicate checks.
    replaced=$(find "$(git rev-parse --git-dir)/hooks" -name '*.replaced.githook' 2>/dev/null || true)
    if [ -n "$replaced" ]; then
      warn "Removing replaced hooks (shared hooks cover these):"
      echo "$replaced" | while read -r f; do
        rm -f "$f"
        ok "Removed $(basename "$f")"
      done
    fi

    # Pull the latest shared hooks.
    git hooks shared update
    ok "Shared hooks updated"

    # Trust the namespace.
    git hooks trust hooks --pattern "$SHARED_HOOKS_NS"
    ok "Trusted namespace: $SHARED_HOOKS_NS"
  else
    warn "Not inside a git repo — skipping repo activation"
  fi
fi

info "Done"
