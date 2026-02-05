# semgrep-review

A Claude Code skill for analyzing semgrep static analysis findings, fixing real
security issues, and suppressing false positives with properly documented
`nosemgrep` comments.

## What It Does

- Triages semgrep findings into real vulnerabilities vs false positives
- Fixes real issues using framework-native escaping (Hono, React, etc.)
- Suppresses false positives with correctly formatted `nosemgrep` comments
- Documents rationale for every suppression
- Handles tricky cases like comments inside template literals

## Install

```bash
claude /install-plugin github:jaeyeom/claude-toolbox/plugins/semgrep-review
```

## Usage

Run a semgrep scan and ask Claude to review the results:

```
semgrep found 7 issues, can you analyze them?
```

Or paste semgrep output directly and ask for analysis.

The skill activates automatically when semgrep findings are discussed.

## What You Get

1. **Triage table** - Each finding classified as real issue or false positive
   with rationale
2. **Framework-native fixes** - Real issues fixed using the project's own
   escaping mechanisms (e.g., Hono `html` template literals instead of custom
   `escapeHtml()`)
3. **Proper suppressions** - False positives suppressed with:
   - Correct short rule IDs (not full dotted paths)
   - Rationale comments explaining why each suppression is safe
   - Correct placement even inside template literals
4. **Verification** - Semgrep re-run to confirm 0 findings

## Key Lessons Encoded

- `nosemgrep` uses **short rule IDs** (e.g., `detected-private-key`), not full
  paths
- Comments must be on the **same line** or **the line immediately above** the
  finding
- Inside template literal `${}` expressions, use `/* */` or `//` JS comments
- Prefer framework auto-escaping over custom escape functions
- When removing `raw()` wrappers, watch for leftover extra `)` characters
