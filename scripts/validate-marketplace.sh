#!/usr/bin/env bash
#
# validate-marketplace.sh - Comprehensive marketplace validation
#
# Checks:
#   - Required files (README.md, entrypoint) and plugin.json fields
#   - JSON validity and duplicate plugin name detection
#   - Marketplace <-> directory sync
#   - Name/version consistency between plugin.json and marketplace.json
#   - SKILL.md / command / agent frontmatter
#   - Hook script executability
#   - settings.json event name validity
#   - Source path validity in marketplace.json
#
# Requirements: bash 4+, jq
# Exit code: 0 on success, 1 on any error. Warnings don't fail.

set -euo pipefail

# Resolve repo root (script lives in scripts/)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS_DIR="$REPO_ROOT/plugins"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

errors=0
warnings=0

error() {
  echo "ERROR: $*" >&2
  errors=$((errors + 1))
}

warn() {
  echo "WARNING: $*" >&2
  warnings=$((warnings + 1))
}

info() {
  echo "  $*"
}

# ---------------------------------------------------------------------------
# Pre-flight: jq must be available
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "FATAL: jq is required but not found. Install it first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Pre-flight: marketplace.json must exist
# ---------------------------------------------------------------------------
if [[ ! -f "$MARKETPLACE" ]]; then
  echo "FATAL: marketplace.json not found at $MARKETPLACE" >&2
  exit 1
fi

echo "=== Marketplace Validation ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Required files and plugin.json fields
# ---------------------------------------------------------------------------
echo "--- Checking required files and plugin.json fields ---"

plugin_count=0
declare -a all_plugin_names=()
for plugin_json in "$PLUGINS_DIR"/*/.claude-plugin/plugin.json; do
  [[ -f "$plugin_json" ]] || continue
  plugin_count=$((plugin_count + 1))
  plugin_dir="$(dirname "$plugin_json")/.."

  # JSON validity
  if ! jq empty "$plugin_json" 2>/dev/null; then
    error "$plugin_json: invalid JSON"
    continue
  fi

  # README.md must exist
  if [[ ! -f "$plugin_dir/README.md" ]]; then
    error "$plugin_dir: missing README.md"
  fi

  # Entrypoint must exist if specified
  entrypoint=$(jq -r '.entrypoint // empty' "$plugin_json")
  if [[ -n "$entrypoint" ]] && [[ ! -f "$plugin_dir/$entrypoint" ]]; then
    error "$plugin_json: entrypoint '$entrypoint' not found"
  fi

  # Required fields
  name=$(jq -r '.name // empty' "$plugin_json")
  version=$(jq -r '.version // empty' "$plugin_json")
  description=$(jq -r '.description // empty' "$plugin_json")
  license=$(jq -r '.license // empty' "$plugin_json")
  if [[ -z "$name" ]] || [[ -z "$version" ]] || [[ -z "$description" ]] || [[ -z "$license" ]]; then
    error "$plugin_json: missing required field(s) (need name, version, description, license)"
  fi

  # Name format
  if [[ -n "$name" ]] && ! [[ "$name" =~ ^[a-z0-9-]+$ ]]; then
    error "$plugin_json: invalid plugin name '$name' (only lowercase, numbers, hyphens)"
  fi

  # Semver format
  if [[ -n "$version" ]] && ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "$plugin_json: invalid version '$version' (expected semver)"
  fi

  all_plugin_names+=("$name")
done

# Duplicate names
dupes=$(printf '%s\n' "${all_plugin_names[@]}" | sort | uniq -d)
if [[ -n "$dupes" ]]; then
  error "Duplicate plugin names found: $dupes"
fi

info "Checked $plugin_count plugin(s)"
echo ""

# ---------------------------------------------------------------------------
# 2. Marketplace <-> directory sync
# ---------------------------------------------------------------------------
echo "--- Checking marketplace <-> directory sync ---"

# Collect plugin directory names
declare -a dir_plugins=()
if [[ -d "$PLUGINS_DIR" ]]; then
  for d in "$PLUGINS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    dir_plugins+=("$(basename "$d")")
  done
fi

# Collect marketplace entry names
mapfile -t market_plugins < <(jq -r '.plugins[].name' "$MARKETPLACE")

# Every directory must have a marketplace entry
for dp in "${dir_plugins[@]}"; do
  found=false
  for mp in "${market_plugins[@]}"; do
    if [[ "$dp" == "$mp" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == "false" ]]; then
    error "Plugin directory '$dp' has no matching entry in marketplace.json"
  fi
done

# Every marketplace entry must have a directory
for mp in "${market_plugins[@]}"; do
  if [[ ! -d "$PLUGINS_DIR/$mp" ]]; then
    error "Marketplace entry '$mp' has no matching directory under plugins/"
  fi
done

info "Directories: ${dir_plugins[*]}"
info "Marketplace: ${market_plugins[*]}"
echo ""

# ---------------------------------------------------------------------------
# 3. Name consistency: plugin.json name == directory name == marketplace name
# ---------------------------------------------------------------------------
echo "--- Checking name consistency ---"

for dp in "${dir_plugins[@]}"; do
  plugin_json="$PLUGINS_DIR/$dp/.claude-plugin/plugin.json"
  if [[ ! -f "$plugin_json" ]]; then
    error "Plugin '$dp' is missing .claude-plugin/plugin.json"
    continue
  fi

  pj_name=$(jq -r '.name // empty' "$plugin_json")
  if [[ -z "$pj_name" ]]; then
    error "Plugin '$dp': plugin.json has no 'name' field"
    continue
  fi

  if [[ "$pj_name" != "$dp" ]]; then
    error "Plugin '$dp': plugin.json name '$pj_name' does not match directory name '$dp'"
  fi

  # Check marketplace entry name matches
  mp_name=$(jq -r --arg dp "$dp" '.plugins[] | select(.name == $dp) | .name // empty' "$MARKETPLACE")
  if [[ -n "$mp_name" ]] && [[ "$mp_name" != "$pj_name" ]]; then
    error "Plugin '$dp': marketplace name '$mp_name' does not match plugin.json name '$pj_name'"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# 4. Version consistency: if both plugin.json and marketplace.json have a
#    version, they must match
# ---------------------------------------------------------------------------
echo "--- Checking version consistency ---"

for dp in "${dir_plugins[@]}"; do
  plugin_json="$PLUGINS_DIR/$dp/.claude-plugin/plugin.json"
  [[ -f "$plugin_json" ]] || continue

  pj_version=$(jq -r '.version // empty' "$plugin_json")
  mp_version=$(jq -r --arg dp "$dp" '.plugins[] | select(.name == $dp) | .version // empty' "$MARKETPLACE")

  if [[ -n "$pj_version" ]] && [[ -n "$mp_version" ]] && [[ "$pj_version" != "$mp_version" ]]; then
    error "Plugin '$dp': version mismatch - plugin.json=$pj_version, marketplace.json=$mp_version"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# 5. SKILL.md frontmatter: must have 'description' in YAML frontmatter
# ---------------------------------------------------------------------------
echo "--- Checking SKILL.md frontmatter ---"

skill_count=0
while IFS= read -r -d '' skill_md; do
  skill_count=$((skill_count + 1))
  # Extract YAML frontmatter between --- markers
  if ! head -1 "$skill_md" | grep -q '^---$'; then
    error "$skill_md: missing YAML frontmatter (no opening ---)"
    continue
  fi

  # Extract the frontmatter block (between first and second ---)
  frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')
  if [[ -z "$frontmatter" ]]; then
    error "$skill_md: empty YAML frontmatter"
    continue
  fi

  if ! echo "$frontmatter" | grep -q '^description:'; then
    error "$skill_md: missing required 'description' field in frontmatter"
  fi
done < <(find "$PLUGINS_DIR" -path '*/skills/*/SKILL.md' -print0 2>/dev/null)

info "Checked $skill_count SKILL.md file(s)"
echo ""

# ---------------------------------------------------------------------------
# 6. Command .md frontmatter: must have 'description' field
# ---------------------------------------------------------------------------
echo "--- Checking command .md frontmatter ---"

cmd_count=0
while IFS= read -r -d '' cmd_md; do
  cmd_count=$((cmd_count + 1))
  if ! head -1 "$cmd_md" | grep -q '^---$'; then
    error "$cmd_md: missing YAML frontmatter (no opening ---)"
    continue
  fi

  frontmatter=$(sed -n '2,/^---$/p' "$cmd_md" | sed '$d')
  if [[ -z "$frontmatter" ]]; then
    error "$cmd_md: empty YAML frontmatter"
    continue
  fi

  if ! echo "$frontmatter" | grep -q '^description:'; then
    error "$cmd_md: missing required 'description' field in frontmatter"
  fi
done < <(find "$PLUGINS_DIR" -path '*/commands/*.md' -print0 2>/dev/null)

info "Checked $cmd_count command .md file(s)"
echo ""

# ---------------------------------------------------------------------------
# 7. Agent .md frontmatter: must have 'name' and 'description' fields
# ---------------------------------------------------------------------------
echo "--- Checking agent .md frontmatter ---"

agent_count=0
while IFS= read -r -d '' agent_md; do
  agent_count=$((agent_count + 1))
  if ! head -1 "$agent_md" | grep -q '^---$'; then
    error "$agent_md: missing YAML frontmatter (no opening ---)"
    continue
  fi

  frontmatter=$(sed -n '2,/^---$/p' "$agent_md" | sed '$d')
  if [[ -z "$frontmatter" ]]; then
    error "$agent_md: empty YAML frontmatter"
    continue
  fi

  if ! echo "$frontmatter" | grep -q '^name:'; then
    error "$agent_md: missing required 'name' field in frontmatter"
  fi
  if ! echo "$frontmatter" | grep -q '^description:'; then
    error "$agent_md: missing required 'description' field in frontmatter"
  fi
done < <(find "$PLUGINS_DIR" -path '*/agents/*.md' -print0 2>/dev/null)

info "Checked $agent_count agent .md file(s)"
echo ""

# ---------------------------------------------------------------------------
# 8. Hook script executability
# ---------------------------------------------------------------------------
echo "--- Checking hook script executability ---"

hook_count=0
while IFS= read -r -d '' hook_sh; do
  hook_count=$((hook_count + 1))
  if [[ ! -x "$hook_sh" ]]; then
    error "$hook_sh: not executable (chmod +x needed)"
  fi
done < <(find "$PLUGINS_DIR" -path '*/hooks/*.sh' -print0 2>/dev/null)

info "Checked $hook_count hook script(s)"
echo ""

# ---------------------------------------------------------------------------
# 9. settings.json event name validation
# ---------------------------------------------------------------------------
echo "--- Checking settings.json event names ---"

# Valid hook event names from Claude Code documentation
valid_events="PreToolUse PostToolUse PostToolUseFailure Notification Stop"

settings_count=0
while IFS= read -r -d '' settings_file; do
  settings_count=$((settings_count + 1))

  # Extract all top-level keys under .hooks
  mapfile -t events < <(jq -r '.hooks // {} | keys[]' "$settings_file" 2>/dev/null)
  for event in "${events[@]}"; do
    found=false
    for valid in $valid_events; do
      if [[ "$event" == "$valid" ]]; then
        found=true
        break
      fi
    done
    if [[ "$found" == "false" ]]; then
      error "$settings_file: unknown hook event name '$event' (valid: $valid_events)"
    fi
  done
done < <(find "$PLUGINS_DIR" -name 'settings.json' -print0 2>/dev/null)

info "Checked $settings_count settings.json file(s)"
echo ""

# ---------------------------------------------------------------------------
# 10. Source path validity: marketplace source paths must exist on disk
# ---------------------------------------------------------------------------
echo "--- Checking marketplace source paths ---"

mapfile -t sources < <(jq -r '.plugins[].source' "$MARKETPLACE")
for src in "${sources[@]}"; do
  # Resolve relative to repo root
  resolved="$REPO_ROOT/${src#./}"
  if [[ ! -d "$resolved" ]]; then
    error "Marketplace source path '$src' does not exist on disk (expected $resolved)"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Validation Summary ==="
echo "  Errors:   $errors"
echo "  Warnings: $warnings"

if [[ $errors -gt 0 ]]; then
  echo ""
  echo "FAILED: $errors error(s) found."
  exit 1
fi

echo ""
echo "PASSED: All checks passed."
exit 0
