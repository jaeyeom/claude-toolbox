---
name: biome-vcs-integration
description: >
  Configure Biome to respect .gitignore via VCS integration so that untracked
  and ignored files are skipped during format and lint. Use when the user
  encounters Biome errors on .gitignore'd files, CI failures from local-only
  files, or asks how to exclude files from Biome. Trigger on keywords: "biome
  gitignore", "biome ignore files", "biome vcs", "biome skip untracked",
  "biome CI failure local file", "biome settings.local.json",
  "useIgnoreFile", "clientKind".
---

# Biome VCS Integration

## Problem

Biome does **not** automatically skip `.gitignore`'d files. This causes CI
failures and false positives when local-only files (e.g.,
`.claude/settings.local.json`) don't match Biome's formatting rules.

The fix is non-obvious: you need to enable Biome's VCS integration explicitly
in `biome.json`.

## Diagnosis

Check for these symptoms before applying the fix:

1. Biome reports errors on files that are listed in `.gitignore`.
2. CI fails on files that only exist locally (untracked).
3. Running `biome check` or `biome format` processes files you expected to be
   ignored.

Verify with:

```bash
# Check if the file causing errors is gitignored
git check-ignore -v <problematic-file>
```

If `git check-ignore` confirms the file is ignored but Biome still processes
it, VCS integration is the fix.

## Fix

### Step 1 — Enable VCS integration in biome.json

Add or merge the `vcs` section into the project's `biome.json` (or
`biome.jsonc`):

```json
{
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true
  }
}
```

**Important:** The `clientKind` field is **required**. Omitting it causes a
Biome config validation error.

### Step 2 — Remove redundant manual exclusions (if any)

With VCS integration enabled, manual exclusions for `.gitignore`'d paths are
redundant. Check the `files` section for patterns that duplicate `.gitignore`
entries and remove them.

**Biome v1.x** — uses the `ignore` key:

```json
{
  "files": {
    "ignore": [".claude/settings.local.json"]
  }
}
```

Remove entries that `.gitignore` already covers.

**Biome v2.x** — uses `includes` with `!` negation patterns (the old `ignore`
key no longer exists):

```json
{
  "files": {
    "includes": ["!.claude/settings.local.json"]
  }
}
```

Remove `!` negation entries that `.gitignore` already covers.

### Step 3 — Verify

```bash
# Confirm Biome now skips gitignored files
biome check .
```

The previously-erroring gitignored files should no longer appear in output.

## Biome v2.x Migration Notes

If migrating from Biome v1.x to v2.x while applying this fix:

- `files.ignore` is replaced by `files.includes` with `!` prefix for
  exclusions.
- The `vcs` config section works the same in both versions.
- Run `biome migrate` for automated config migration.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Missing `clientKind` | Always include `"clientKind": "git"` — it's required |
| Nested `.gitignore` files | Biome respects nested `.gitignore` files when VCS integration is enabled; ensure `useIgnoreFile` is `true` and each subdirectory's `.gitignore` is committed |
| `biome.jsonc` vs `biome.json` | VCS config works in both; use whichever the project already has |

## Reference

- [Biome VCS integration docs](https://biomejs.dev/reference/configuration/#vcs)
