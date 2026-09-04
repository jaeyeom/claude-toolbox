---
name: sh-dev
description: Expert knowledge for POSIX shell glue. Includes when to leave shell, POSIX dialect, quoting, thin bootstrap, and portability. Use when writing, editing, or reviewing shell scripts, POSIX sh, bash, Makefile recipes, GitHub Actions run: blocks, plugin/git hooks, temp files, TMPDIR, /tmp, or mktemp.
---

# Shell Development Skill

Use this skill when the user **writes, modifies, reviews, or generates shell**
— standalone `.sh` files, Makefile recipes, GitHub Actions `run:` blocks,
plugin/git hooks, or a one-liner about to become a file.

This is on top of ordinary modern shell practice (quoting, `set -eu`,
`shellcheck`), not a replacement for it.

## 1. Golden rule: do not grow shell

Shell is glue. Logic with tests lives in the project's language.

```
About to write shell?
  │
  ├─ Thin orchestration only?     ► POSIX sh is OK
  │  (cd, env, existence checks,    `#!/bin/sh`
  │   a few ifs, exec a binary)     `shellcheck -s sh`
  │
  ├─ Bootstrap, no runtime yet?   ► Thin POSIX sh, then hand off
  │
  └─ Anything else?               ► Leave shell
     JSON/CSV/XML/regex parsing     Project language + tests
     retries, timeouts, concurrency (**REQUIRED:** go-dev / python-dev
     arrays, maps, real control flow  if those skills apply)
     would want a unit test
     needs a bashism to be correct
```

Needing a bashism is a signal to leave, not a license to use bash. Do not
invent a new stack for a helper.

`makefile-workflow` and `ci-workflow` still own target taxonomy and CI shape.
This skill owns whether the shell in those places is allowed to grow.

## 2. Stay vs leave

| Stay in POSIX sh | Leave shell |
| ---------------- | ----------- |
| Thin glue: cd, env, `command -v`, exec | JSON / CSV / XML / regex-heavy parsing |
| A few `if`s / existence checks | retries, timeouts, concurrency |
| Bootstrap until a runtime exists | arrays, maps, non-trivial control flow |
| | anything you'd unit-test |
| | needs `pipefail`, arrays, `[[ ]]`, `local` |

### BAD — shell that should have left

```sh
#!/bin/bash
set -euo pipefail
# parse JSON logs, retry curl, accumulate failures in an array
```

Write this in the project language with tests.

### GOOD — thin POSIX glue

```sh
#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "python3 is required" >&2
  exit 1
fi
exec python3 -m mypkg.cli "$@"
```

## 3. POSIX quick reference

When glue stays in shell:

- Shebang: `#!/bin/sh` (not bash)
- Lint: `shellcheck -s sh`
- `set -eu`. No `pipefail`, no `local`, no arrays, no `[[ ]]`
- Quote everything. `printf` not `echo`. `command -v` not `which`
- Temp files: `mktemp` + `trap`. `mktemp` honors POSIX `TMPDIR`. If you
  must build a path, `"${TMPDIR:-/tmp}"`. `$TMP`/`$TEMP` are Windows, not
  POSIX. Do not hardcode `/tmp`. Do not use `mktemp -t` (GNU/BSD disagree).
- Pipelines: check them explicitly, or don't write a pipeline. If you need
  `pipefail`, leave shell.
- Don't assume GNU: `sed -i`, `readlink -f`, and `seq` are a leave-shell
  signal, same as bashisms.

```sh
# BAD
foo | bar >out

# GOOD — last status only is POSIX; avoid the pipeline
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT INT TERM
foo >"$tmp"
bar <"$tmp" >out
```

## 4. Bootstrap: thin, then hand off

Shell still shines when no other language is available yet (install a runtime,
fetch a tool). Keep that script as thin as possible: detect, install or fail,
exec the real program. Do not accrete features in the bootstrap file.

## 5. Rationalizations

| Excuse | Reality |
| ------ | ------- |
| "It's just a hook / Makefile / CI `run:` block" | Same rule. Surface doesn't grant complexity. |
| "I'll rewrite it later" | Write it in the project language now. |
| "POSIX is too limited, so I'll use bash" | The limit is the signal. Leave shell. |
| "Makefile isn't a shell script" | Recipes are shell. This skill applies. |
| "Bash is already on the machine" | New agent-written shell is POSIX sh, or not shell. |
| "I need arrays / pipefail / local" | Leave shell. |
| "It's only 80 lines" | Length follows complexity. Parsing and retries leave. |
| "`$TMP` is more portable than `/tmp`" | `$TMP` is Windows. POSIX is `TMPDIR`, fallback `/tmp`. |
| "`sed -i` / `seq` is on every machine" | GNU vs BSD. Leave shell, or POSIX subset. |

## 6. Red flags — stop and leave shell (or shrink)

- `#!/usr/bin/env bash` or `#!/bin/bash` on new scripts
- `set -o pipefail`, `[[ ]]`, arrays, `local`
- `jq` loops, retry loops, JSON/CSV parsing in shell
- Logic embedded in a Makefile recipe or GitHub Actions `run:` block
- "I'll add tests later" for a shell script
- Bootstrap that grew past detect / install / exec
- Hardcoded `/tmp`, `$TMP`, `$TEMP`, `mktemp -t`
- `sed -i`, `readlink -f`, `seq` (GNU; leave or POSIX subset)

**All of these mean: extract to the project language with tests, or shrink to
thin POSIX glue.**
