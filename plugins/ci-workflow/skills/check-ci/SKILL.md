---
name: check-ci
description: Diagnose CI failures by inspecting GitHub Actions run logs, identifying root causes, and suggesting fixes. Use when CI is failing, a workflow run failed, checks are red, or the user asks "why is CI failing" or "fix CI".
autouse: false
---

# Check CI

Diagnose GitHub Actions CI failures, identify root causes, and suggest
targeted fixes.

## Prerequisites

- The `gh` CLI must be authenticated (`gh auth status`)
- The repository must have GitHub Actions workflows

## Step 1 — Identify the failing run

Check the most recent workflow runs:

```bash
gh run list --limit 5
```

If the user provided a specific run ID or PR number, use that directly:

```bash
gh run view <run-id>
gh pr checks <pr-number>
```

If multiple workflows exist, ask the user which one to investigate, or
check all failed ones.

## Step 2 — Get failure details

For the failing run, get the detailed log:

```bash
gh run view <run-id> --log-failed
```

This shows only the log output from failed steps. Parse the output to
identify:

- **Which step failed** (e.g., "Run checks", "Run make check")
- **The specific error message** (e.g., biome format diff, lint error, test failure)
- **The failing file(s) and line(s)** if available

## Step 3 — Classify the failure

Map the failure to one of these categories and suggest the appropriate fix:

| Failure type | Indicators | Fix command |
| --- | --- | --- |
| Formatting | `biome format`, `Formatter would have printed`, diff output | `make format` |
| Linting | `biome lint`, `lint error`, rule names | `make fix` |
| Validation | `validate-marketplace.sh`, version mismatch, missing fields | Fix the specific field, then `make validate` |
| Test failure | `go test`, `npm test`, assertion errors | Read the test, fix the code, re-run tests |
| Build failure | `go build`, `npm run build`, compilation errors | Fix the source code |
| Workflow config | YAML syntax, action version, missing setup step | Fix `.github/workflows/*.yml` |

## Step 4 — Apply the fix

For auto-fixable issues (formatting, linting):

```bash
make fix        # Runs biome format --write and biome check --write
make validate   # Verifies marketplace consistency
make check      # Confirms all checks pass locally
```

For manual fixes (test failures, build errors, validation issues):

1. Explain what is wrong and where
2. Suggest the specific code change needed
3. After the fix, run `make check` to verify locally before committing

## Step 5 — Verify locally

Always run the full check suite before committing:

```bash
make check
```

This mirrors what CI runs and catches issues before pushing.

## Step 6 — Report

Summarize:

- What failed and why
- What was fixed
- Whether `make check` now passes locally
- Remind the user to commit and push the fix

## Common patterns

### Biome formatting failures

These are the most common CI failures in this repo. The fix is always:

```bash
make format    # auto-fix formatting
make check     # verify
```

### Version mismatch

If `validate-marketplace.sh` reports version mismatch between
`plugin.json` and `marketplace.json`, update both files to the same
version.

### Missing marketplace entry

If a new plugin directory exists but is not in `marketplace.json`, add
the entry. Use `make validate` to check.

## Cross-plugin synergy

- [ci-workflow](../ci-workflow/) — Generate CI workflows that this skill diagnoses
- [makefile-workflow](../../makefile-workflow/) — Create the Makefile targets that CI calls
