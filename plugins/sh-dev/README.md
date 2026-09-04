# POSIX Shell Glue Plugin

Expert knowledge for POSIX shell glue. The golden rule is **do not grow
shell**: thin orchestration can stay in `sh`; logic with tests lives in the
project's language. When glue stays, it is strict POSIX (`#!/bin/sh`), not
bash.

## Components

| Component | Type  | Description                                           |
| --------- | ----- | ----------------------------------------------------- |
| `sh-dev`  | Skill | Guides when to leave shell and how to keep POSIX glue |

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install sh-dev
```

## Usage

The skill activates automatically when you write or review shell:

- "Write a bootstrap script that installs the runtime then runs the app"
- "Add a Makefile target that retries a JSON API call"
- "Parse these logs in a shell script"
- "Review this GitHub Actions run: block"

## What It Covers

- **Golden rule**: thin glue stays; parsing, retries, arrays, and anything
  you'd unit-test leave shell
- **Replacement language**: the project's language (`go-dev` / `python-dev`
  if those skills apply); do not invent a new stack
- **Dialect**: `#!/bin/sh`, `shellcheck -s sh`; no bash, `pipefail`, `local`,
  or arrays
- **Portability**: POSIX `TMPDIR` (fallback `/tmp`), not `$TMP`/`$TEMP` or a
  hardcoded `/tmp`; GNU options like `sed -i` are a leave-shell signal
- **Surfaces**: `.sh` files, Makefile recipes, GitHub Actions `run:` blocks,
  plugin/git hooks, and one-liners about to become a file
- **Bootstrap**: allowed when no runtime exists yet; keep it thin and hand off
