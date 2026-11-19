#!/usr/bin/env bash

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/cleanup-worktree-disk/config"
BAZEL_OUTPUT_ROOT="${CLEANUP_WORKTREE_BAZEL_ROOT:-}"
FRESH_HOURS=24
PROTECT_PATTERNS=""
REPOS=""
EXTRA_CONFIG=""

load_config() {
	local key value
	if [ -f "$CONFIG_FILE" ]; then
		while IFS='=' read -r key value || [ -n "$key" ]; do
			case "$key" in ''|\#*) continue ;; esac
			case "$key" in
				repos) REPOS=$value ;;
				bazel_output_root) BAZEL_OUTPUT_ROOT=$value ;;
				protect) PROTECT_PATTERNS=$value ;;
				fresh_hours) FRESH_HOURS=$value ;;
				extra.*) EXTRA_CONFIG="${EXTRA_CONFIG}${key#extra.}=$value
" ;;
				*) printf 'Unknown config key: %s\n' "$key" >&2; return 1 ;;
			esac
		done < "$CONFIG_FILE"
	fi
	if [ -z "$BAZEL_OUTPUT_ROOT" ]; then
		case "$(uname -s)" in
			Darwin) BAZEL_OUTPUT_ROOT="/private/var/tmp/_bazel_$(id -un)" ;;
			Linux) BAZEL_OUTPUT_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/bazel/_bazel_$(id -un)" ;;
			*) printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2; return 1 ;;
		esac
	fi
	case "$FRESH_HOURS" in ''|*[!0-9]*) printf 'fresh_hours must be a non-negative integer\n' >&2; return 1 ;; esac
	if [ -z "$REPOS" ]; then REPOS=$(git rev-parse --show-toplevel); fi
}

stat_mtime() {
	if [ "$(uname -s)" = Darwin ]; then stat -f '%m' "$1"; else stat -c '%Y' "$1"; fi
}

is_protected() {
	local candidate pattern
	candidate=$1
	while IFS= read -r pattern; do
		[ -n "$pattern" ] || continue
		# shellcheck disable=SC2053
		[[ "$candidate" == $pattern ]] && return 0
	done <<EOF
$(printf '%s' "$PROTECT_PATTERNS" | tr ':' '\n')
EOF
	return 1
}
