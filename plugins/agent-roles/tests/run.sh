#!/bin/bash
# Static checks for the agent-roles plugin: role skill frontmatter, links to
# the shared conventions, no copies of the conventions, and the private-name
# denylist.
# Usage: plugins/agent-roles/tests/run.sh
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DENYLIST="$PLUGIN_DIR/tests/denylist.txt"
CONVENTIONS="$PLUGIN_DIR/references/conventions.md"

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() {
	fail=$((fail + 1))
	echo "FAIL: $*"
}

# check <failure message> <command...>
check() {
	local msg=$1
	shift
	if "$@"; then ok; else bad "$msg"; fi
}
in_text() { grep -q "${@:3}" -e "$1" <<<"$2"; }

# One line per paragraph or list item of a Markdown file, whitespace
# collapsed. Headings and code fences are skipped.
units() {
	awk '
		function flush() { if (u != "") print u; u = "" }
		/^```/ || /^#/ { flush(); next }
		/^[[:space:]]*$/ { flush(); next }
		/^[[:space:]]*- / { flush(); sub(/^[[:space:]]*- /, "") }
		{ gsub(/^[[:space:]]+|[[:space:]]+$/, ""); u = (u == "" ? $0 : u " " $0) }
		END { flush() }
	' "$1"
}
flat() { tr '\n' ' ' <"$1" | tr -s '[:space:]' ' '; }

frontmatter() { awk 'NR == 1 && /^---$/ { on = 1; next } on && /^---$/ { exit } on' "$1"; }

check "missing references/conventions.md" test -f "$CONVENTIONS"

skills=()
for f in "$PLUGIN_DIR"/skills/*/SKILL.md; do
	[[ -f $f ]] && skills+=("$f")
done
check "no role skills under skills/" test ${#skills[@]} -gt 0

for f in ${skills[@]+"${skills[@]}"}; do
	rel=${f#"$PLUGIN_DIR"/}
	role=$(basename "$(dirname "$f")")
	fm=$(frontmatter "$f")

	check "$rel: name is not '$role'" in_text "name: $role" "$fm" -x
	check "$rel: empty or missing description" in_text '^description: *[^ ]' "$fm" -E
	check "$rel: missing 'disable-model-invocation: true'" \
		in_text 'disable-model-invocation: true' "$fm" -x

	links=$(grep -oE '\]\([^)]*conventions\.md\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
	check "$rel: does not link references/conventions.md" test -n "$links"
	while IFS= read -r link; do
		[[ -z $link ]] && continue
		target=$(cd "$(dirname "$f")" && cd "$(dirname "$link")" 2>/dev/null && pwd)/$(basename "$link")
		if [[ $target == "$CONVENTIONS" ]]; then ok; else bad "$rel: link '$link' does not resolve to references/conventions.md"; fi
	done <<<"$links"

	body=$(flat "$f")
	copied=""
	while IFS= read -r unit; do
		((${#unit} >= 60)) || continue
		if [[ $body == *"$unit"* ]]; then copied+=$'\n'"  $unit"; fi
	done < <(units "$CONVENTIONS")
	check "$rel: copies conventions.md instead of linking it:$copied" test -z "$copied"
done

while IFS= read -r pattern; do
	[[ -z $pattern || $pattern == \#* ]] && continue
	hits=$(grep -rnE --exclude-dir=tests -e "$pattern" "$PLUGIN_DIR" || true)
	if [[ -z $hits ]]; then ok; else bad "denylist pattern '$pattern' matched:"$'\n'"$hits"; fi
done <"$DENYLIST"

echo "agent-roles tests: $pass passed, $fail failed"
((fail == 0))
