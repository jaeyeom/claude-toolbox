---
name: docsync
description: Use when documentation may be stale after a code change; when finishing a feature, fix, or pull request; or when asked to sync docs, review stale docs, check which document sections need updating, or run docsync. Also use when a repo has a docsync.yml mapping.
autouse: false
---

# Docsync

`docsync` reports which docs a change likely made stale. The CLI does not
edit. This skill runs the matcher, patches clear factual drift, and asks
before large rewrites.

## Prerequisites

`docsync` on PATH. If missing:

```bash
go install github.com/jaeyeom/experimental/devtools/docsync/cmd/docsync@latest
```

Flags: `docsync --help`. Always `--json --exit-zero` so implicated docs are
not a failed command. Exit 2/3 are still real errors.

## Workflow

1. **Change set**
   - Finishing a feature/fix/PR: `docsync check --base <upstream-default> --json --exit-zero`.
     `<upstream-default>` is `origin/HEAD`'s branch, else `origin/main`,
     else `main`. `--base REF` is `git diff --name-only REF...HEAD`
     (merge-base).
   - Named files: `docsync check --files PATH --json --exit-zero` (repeat
     `--files`).
   - "Against main": `--base` that ref.
2. **Missing mapping (exit 3).** Thin bootstrap: a small `docsync.yml` from
   obvious code↔doc pairs (README/`docs/` pointing at a package, a recently
   touched file with a clearly matching doc). Write it, `docsync validate`,
   re-run check. Do not invent full coverage. If nothing is obvious, ask.
3. **All clear.** Stop. Say so.
4. **Each `affected` item.** Read `path` (the `section` heading if present)
   against `triggered_by` and `why`.
   - Clear factual drift (renamed flag, new field, command changed) → patch
     that section.
   - Still accurate → leave it.
   - Large rewrite, tone/structure, or maybe-intentional → ask.
5. **`unmatched_files`.** Mention as coverage gaps. Add a rule only during
   bootstrap when the pair is obvious.

## Glob gotchas (when writing `docsync.yml`)

Matching is root-anchored. No implicit `**/`.

| Pattern | Matches | Does not match |
| --- | --- | --- |
| `config/schema.go` | that file only | `src/config/schema.go` |
| `**/schema.go` | any `schema.go` | — |
| `src/**/*.go` | Go files under `src/` | — |
| `src/**.go` | invalid | bare `**` must be a path segment |

`version` must be `1`. Unknown YAML keys are errors. `docs[].path` must
exist on disk.

## Report

| Path | Section | Verdict | Action |
| --- | --- | --- | --- |
| `docs/api.md` | Authentication | stale | patched TTL |
| `docs/config.md` | — | accurate | left alone |
| `docs/design.md` | Overview | maybe-intentional | asked |

## Common mistakes

| Mistake | Reality |
| --- | --- |
| Grep docs instead of running `docsync` | The mapping is the index; run the CLI |
| `--base HEAD~1` or unstaged-only on a finishing step | Use `--base <upstream-default>` |
| Treating check exit 1 as failure | `--exit-zero`; read `affected` |
| Rewriting a whole design doc | Patch factual drift; ask otherwise |
| Filling every unmatched file into the map | Coverage gaps are notes, not a mapping project |
