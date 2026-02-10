---
name: makefile-workflow
description: Design or update Makefiles with consistent build, format, lint, test, and check-* targets. Use when a user asks for a Makefile, build automation, or project workflow targets for Go, Node, Bazel, or mixed stacks.
autouse: false
---

# Makefile Workflow

Create or refine Makefiles that encode a reliable developer workflow. Mirror the project's existing tooling (Go, Node, Bazel, Supabase, etc.) and use low-noise output for successful runs.

## Instructions

1. Ask for essentials if missing:
   - Primary language(s) and tooling (Go, Node, Bazel, Python, etc.)
   - Lint/format/test commands already in use
   - Whether the project wants `all`, `check`, and `fix` targets
2. Start with a clear, consistent target taxonomy:
   - `all`: full local workflow (format + fix + tests + build + check-* targets)
   - `check`: CI-friendly checks (no mutation), prefer `check-*` targets
   - `format` + `check-format`
   - `lint` + `fix`
   - `test`, `build`, `coverage`, `clean`
3. Use the stricter naming convention for non-mutating checks:
   - Prefer `check-*` over names like `type-check`, `bundle-check`
   - Example: `check-astro`, `check-bundle`
4. Reduce output noise for successful runs:
   - If the repo has `scripts/quiet-run.sh`, wrap commands like:
     `@./scripts/quiet-run.sh "Label" <command>`
   - Only use it where the project already does; don't invent a helper without asking.
5. Use `.PHONY` for non-file targets and group related sections with comments.
6. Keep shell-safe loops and cross-platform sed where needed:
   - Prefer `rg` for file lists.
   - Avoid scanning `node_modules` or vendor directories.
7. For Go projects, include `golangci-lint` verification hashes if `.golangci.yml` is present.
8. For frontend projects, prefer `npm run <task>` or `pnpm run <task>` to preserve project scripts.
9. If generation or formatting changes files, add `check-generated` or `check-format` that fails on a dirty git diff.
10. For large repos, consider stamp files to avoid repeated work.
11. Ensure Makefiles work correctly with `make -j` (parallel execution):
    - Targets that modify files (e.g., `format`, `fix`) must declare dependencies to prevent concurrent writes. For example, `fix` should depend on `format` since both write to the same files.
    - Validation or check targets that run after writes should depend on the write targets. For example, `validate-full` should depend on `fix`.
    - Read-only targets (e.g., `check-format`, `lint`, `test`) are safe to run in parallel and need no extra ordering.
    - If correct ordering cannot be expressed through dependencies, add `.NOTPARALLEL` to the Makefile.

## Recommended target patterns

### Minimal workflow
- `all`: `format fix test build`
- `check`: `check-format lint test build`
- Parallel-safety deps: `fix: format` (both mutate files)

### Go + linters
- `lint-golangci`, `fix-golangci`, `verify-golangci-config`
- `coverage`, `coverage-html`, `coverage-report`, `clean-coverage`

### Frontend + Supabase
- `check-astro`, `check-bundle`, `test-e2e`, `db-push`, `db-reset`, `db-status`, `db-gen-types`

## Output expectations

When asked to create or update a Makefile:
- Produce a ready-to-run Makefile tailored to the project.
- Preserve existing targets and semantics; only add or adjust as needed.
- Call out any assumptions (package manager, tools, coverage thresholds).
