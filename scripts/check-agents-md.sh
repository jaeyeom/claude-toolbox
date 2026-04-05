#!/usr/bin/env bash
#
# check-agents-md.sh - Validate AGENTS.md compatibility
#
# For each CLAUDE.md containing the <!-- agents-md-compat --> opt-in marker,
# verifies that a sibling AGENTS.md symlink exists and points to CLAUDE.md.
#
# Exit code: 0 on success, 1 on any error. Warnings don't fail.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

errors=0
error() {
	echo "ERROR: $*" >&2
	errors=$((errors + 1))
}

info() {
	echo "  $*"
}

# ---------------------------------------------------------------------------
# Find all CLAUDE.md files and check for opt-in marker
# ---------------------------------------------------------------------------
found=0

while IFS= read -r -d '' claude_md; do
	dir="$(dirname "$claude_md")"
	rel_dir="${dir#"$REPO_ROOT"/}"
	[[ "$dir" == "$REPO_ROOT" ]] && rel_dir="."

	if ! grep -qF '<!-- agents-md-compat -->' "$claude_md"; then
		continue
	fi

	found=$((found + 1))
	agents_md="$dir/AGENTS.md"

	if [[ ! -e "$agents_md" ]]; then
		error "$rel_dir: AGENTS.md missing (CLAUDE.md has agents-md-compat marker)"
	elif [[ ! -L "$agents_md" ]]; then
		error "$rel_dir: AGENTS.md exists but is not a symlink (should be a symlink to CLAUDE.md)"
	else
		resolved_agents="$(cd "$dir" && realpath "$(readlink AGENTS.md)")"
		resolved_claude="$(realpath "$claude_md")"
		if [[ "$resolved_agents" != "$resolved_claude" ]]; then
			target="$(readlink "$agents_md")"
			error "$rel_dir: AGENTS.md symlink resolves to '$resolved_agents' instead of '$resolved_claude'"
		else
			target="$(readlink "$agents_md")"
			info "$rel_dir: AGENTS.md -> $target (OK)"
		fi
	fi
done < <(find "$REPO_ROOT" -name CLAUDE.md -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $found -eq 0 ]]; then
	info "No CLAUDE.md files with agents-md-compat marker found. Nothing to check."
fi

if [[ $errors -gt 0 ]]; then
	echo ""
	echo "AGENTS.md check: $errors error(s)"
	exit 1
fi

if [[ $found -gt 0 ]]; then
	echo "AGENTS.md check: all $found opted-in file(s) OK"
fi

exit 0
