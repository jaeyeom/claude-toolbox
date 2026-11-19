#!/bin/sh
set -eu
script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
exec python3 "$script_dir/cleanup_worktree_disk.py" verify "$@"
