#!/usr/bin/env bash
# scan-code-todos.sh — Scan source code for TODO/FIXME/HACK/XXX comments,
# score them by priority, and output the top results as JSON.
#
# Usage: scan-code-todos.sh [--limit N] [directory]
#   --limit N   Show top N results (default: 20)
#   directory   Directory to scan (default: current directory)
#
# Output: JSON array sorted by score (descending), each entry:
#   { "tag", "tracker_id", "assignee", "description", "file", "line", "score" }

set -euo pipefail

LIMIT=20
DIR="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--limit)
		LIMIT="$2"
		shift 2
		;;
	--limit=*)
		LIMIT="${1#--limit=}"
		shift
		;;
	*)
		DIR="$1"
		shift
		;;
	esac
done

# Require rg (ripgrep)
if ! command -v rg &>/dev/null; then
	echo '[]'
	exit 0
fi

# Scan and parse into tab-separated records: score\tfile\tline\ttag\ttracker_id\tassignee\tdescription
# Then sort and emit JSON.
{ rg --vimgrep '(//|#|/\*|\*|--|;;)\s*(TODO|FIXME|HACK|XXX)\b' \
	--type-not json --type-not lock --type-not markdown \
	--glob '!vendor/' \
	--glob '!node_modules/' \
	--glob '!third_party/' \
	--glob '!generated/' \
	--glob '!*.min.*' \
	--glob '!*.lock' \
	--glob '!scan-code-todos.sh' \
	"$DIR" 2>/dev/null || true; } |
	sort -t: -k1,1 -k2,2n -u |
	while IFS= read -r raw_line; do
		# Parse vimgrep format: file:line:col:text
		# Extract file (everything up to first :<digits>:<digits>:)
		if [[ ! "$raw_line" =~ ^(.+):([0-9]+):[0-9]+:(.*)$ ]]; then
			continue
		fi
		file="${BASH_REMATCH[1]}"
		line="${BASH_REMATCH[2]}"
		text="${BASH_REMATCH[3]}"

		# Determine tag (highest urgency first)
		tag=""
		upper_text="${text^^}"
		if [[ "$upper_text" == *FIXME* ]]; then
			tag="FIXME"
		elif [[ "$upper_text" == *XXX* ]]; then
			tag="XXX"
		elif [[ "$upper_text" == *HACK* ]]; then
			tag="HACK"
		elif [[ "$upper_text" == *TODO* ]]; then
			tag="TODO"
		else
			continue
		fi

		# Extract parenthesized qualifier: TAG(something)
		tracker_id=""
		assignee=""
		paren_re="${tag}[(]([^)]+)[)]"
		if [[ "$text" =~ $paren_re ]]; then
			qual="${BASH_REMATCH[1]}"
			# Tracker ID patterns: PRJ-123, #42, gh-15, JIRA-456
			if [[ "$qual" =~ ^#?[A-Z]+-[0-9]+$ ]] || [[ "$qual" =~ ^#[0-9]+$ ]] || [[ "$qual" =~ ^gh-[0-9]+$ ]]; then
				tracker_id="$qual"
			elif [[ "${qual^^}" == P[0-9] ]] || [[ "${qual^^}" == URGENT ]] || [[ "${qual^^}" == HIGH ]] || [[ "${qual^^}" == MEDIUM ]] || [[ "${qual^^}" == LOW ]]; then
				: # priority marker, handled by scoring below
			elif [[ "$qual" =~ ^@?[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
				assignee="$qual"
			else
				tracker_id="$qual"
			fi
		fi

		# Check for bare #123 in text if no tracker_id yet
		if [[ -z "$tracker_id" ]] && [[ "$text" =~ \#([0-9]+) ]]; then
			tracker_id="#${BASH_REMATCH[1]}"
		fi

		# Extract description: text after the tag and optional (qualifier)
		desc="$text"
		# Remove everything up to and including the tag (and optional qualifier)
		desc="${desc#*"$tag"}"
		# Remove optional parenthesized qualifier
		qual_re='^[(][^)]*[)](.*)'
		if [[ "$desc" =~ $qual_re ]]; then
			desc="${BASH_REMATCH[1]}"
		fi
		# Remove leading colons, spaces, dashes
		desc="${desc#"${desc%%[! :.-]*}"}"
		# Remove trailing whitespace and punctuation
		desc="${desc%"${desc##*[! .:!*/\-]}"}"
		# Remove leading comment markers
		desc="${desc#"${desc%%[!/ *#]*}"}"

		# Compute score
		score=35 # plain TODO baseline
		case "$tag" in
		FIXME | XXX) score=80 ;;
		HACK) score=60 ;;
		esac

		# Priority markers
		if { [[ "$upper_text" == *P0* ]] || [[ "$upper_text" == *URGENT* ]]; } && ((score < 70)); then
			score=70
		elif { [[ "$upper_text" == *P1* ]] || [[ "$upper_text" == *HIGH* ]]; } && ((score < 60)); then
			score=60
		fi

		# Security keyword boost
		lower_text="${text,,}"
		for kw in security vulnerability crash "data loss" "race condition" injection overflow; do
			if [[ "$lower_text" == *"$kw"* ]] && ((score < 80)); then
				score=80
				break
			fi
		done

		# Tracker ID bonus
		if [[ -n "$tracker_id" ]] && ((score < 50)); then
			score=50
		fi

		# Escape for JSON
		desc="${desc//\\/\\\\}"
		desc="${desc//\"/\\\"}"
		desc="${desc//$'\t'/\\t}"
		file="${file//\\/\\\\}"
		file="${file//\"/\\\"}"
		tracker_id="${tracker_id//\"/\\\"}"
		assignee="${assignee//\"/\\\"}"

		# Output as tab-separated for sorting: score first for sort -rn
		printf '%d\t%s\t%d\t%s\t%s\t%s\t%s\n' \
			"$score" "$file" "$line" "$tag" "$tracker_id" "$assignee" "$desc"
	done |
	sort -t$'\t' -k1,1rn |
	head -n "$LIMIT" |
	awk -F'\t' '
BEGIN { printf "[\n" }
{
  if (NR > 1) printf ",\n"
  printf "  {\"tag\": \"%s\", \"tracker_id\": \"%s\", \"assignee\": \"%s\", " \
         "\"description\": \"%s\", \"file\": \"%s\", \"line\": %s, \"score\": %s}",
         $4, $5, $6, $7, $2, $3, $1
}
END { printf "\n]\n" }
'
