---
name: claude-md
description: Write effective CLAUDE.md files containing only tacit knowledge. Use when asked to create, review, or improve a CLAUDE.md file, or when setting up project context for AI agents. Enforces the "tacit knowledge only" quality bar — rejects content derivable from code, linters, or tooling.
argument-hint: "[path-or-action]"
autouse: false
---

# CLAUDE.md Skill

Write or review CLAUDE.md files that contain **only tacit knowledge** — information an AI agent cannot derive by reading the codebase, running tools, or inspecting configuration files.

## Core Principle

> If a linter, compiler, `ls`, or `grep` can tell the agent the same thing, it does not belong in CLAUDE.md.

CLAUDE.md transfers understanding that lives in engineers' heads: architectural invariants, non-obvious constraints, known violations awaiting cleanup, and workflow gotchas that require tribal knowledge.

## Supported Actions

- **Create**: Write a new CLAUDE.md for a directory
- **Review**: Evaluate an existing CLAUDE.md against the quality bar
- **Improve**: Refactor an existing CLAUDE.md to remove derivable content and strengthen tacit knowledge

## Step 1 — Determine Action and Scope

Parse the user's request:

- If they specify a directory path, scope to that directory.
- If no path, default to the project root.
- Determine action: **create**, **review**, or **improve**.

CLAUDE.md files can be placed in any directory to cover that subtree. A subdirectory CLAUDE.md supplements (does not replace) parent CLAUDE.md files.

## Step 2 — Gather Context

Before writing or reviewing, understand the codebase:

1. **Read existing CLAUDE.md files** in the target directory and its parents.
2. **Inspect the directory** — run `ls`, read key config files (`Makefile`, `package.json`, `go.mod`, `BUILD`, `.eslintrc`, `tsconfig.json`, etc.).
3. **Identify what tooling already covers** — linter rules, formatter configs, CI pipelines, type systems.
4. **Mine PR review comments** — extract tacit knowledge from code review history (see Step 2a).
5. **Talk to the user** — ask what non-obvious constraints, gotchas, or architectural decisions exist that the code doesn't express.

### Step 2a — Mine PR Review Comments

PR code reviews are one of the richest sources of tacit knowledge. Reviewers often explain *why* something is wrong in ways that never make it into documentation. Mine this knowledge with `gh`:

```bash
# Recent merged PRs touching the target directory
gh pr list --state merged --limit 30 --json number,title,url

# Review comments on a specific PR
gh api repos/{owner}/{repo}/pulls/{number}/comments --jq '.[] | {path, body, diff_hunk}'

# Review-level comments (general PR feedback, not inline)
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[] | select(.state != "APPROVED") | {body, state}'
```

**What to look for in review comments:**

| Signal | Example | Extracts To |
|---|---|---|
| **"Don't do X because..."** | "Don't import `pkg/internal` from here — it breaks the dependency boundary" | Architectural boundary |
| **"This broke prod when..."** | "Last time someone changed this serialization, the mobile app crashed for 2 hours" | Operational gotcha |
| **"The convention is..."** | "We always put migration SQL in `migrations/` not inline — the deploy pipeline expects it there" | Workflow procedure |
| **"This needs to match..."** | "This enum must stay in sync with the proto definition in repo X" | Cross-team constraint |
| **Repeated corrections** | Same feedback given across multiple PRs | Undocumented rule worth capturing |
| **"Why" explanations** | "We use X instead of Y because Y has a memory leak under Z conditions" | Non-obvious design rationale |

**Process:**

1. Fetch the last 20–30 merged PRs touching the target directory.
2. For each PR, read inline review comments and review-level feedback.
3. Filter for comments that explain *constraints*, *boundaries*, *gotchas*, or *rationale* — skip style nits and typo fixes.
4. Group recurring themes — if the same feedback appears in 2+ PRs, it is almost certainly undocumented tacit knowledge.
5. Apply the quality bar (Step 3) to each extracted item before including it.

**Limitations:** Only mine reviews if the repo is hosted on GitHub and `gh` is authenticated. Skip this step if `gh auth status` fails or the repo has no PR history.

## Step 3 — Apply the Quality Bar

Every piece of content must pass this checklist:

| Check | Question |
|---|---|
| **Tacit knowledge** | Would an agent reading source code and tool configs miss this? |
| **Non-derivable** | Can `ls`, `grep`, linter output, or config files reproduce this? |
| **Architectural invariant** | Does it describe a rule not enforced by tooling? |
| **Known violations** | If documenting a rule, are existing violations called out? |
| **Actionable** | Does it give concrete steps, not vague guidance? |
| **Not code explanation** | Does it avoid restating what functions do? |
| **Concise** | Uses tables, short bullets, or headings — not prose walls? |

### The Natural Language Execution Test

> If you gave this CLAUDE.md to a competent engineer who has never seen the codebase, would they avoid a mistake they would otherwise make?

If **yes**, keep it. If **no** — because tooling or code review would catch it — remove it.

## Step 4 — Write or Revise Content

### Content That Belongs

| Category | Example |
|---|---|
| **Architectural boundaries** | "Vendor formats must be parsed only inside `topomap/` — all other packages use `topomap.Graph`" |
| **Non-obvious design rationale** | "Shortest paths are precomputed with Dijkstra because the graph is static and small" |
| **Operational gotchas** | "Run `ms_local_ctl down` when done — Cloud SQL Proxy impersonation accounts are limited" |
| **Workflow procedures** | Step-by-step for tasks the code can't express (e.g., "how to add a new vendor format") |
| **Cross-team constraints** | "Service X owns the schema — changes require their review even though we have write access" |
| **Non-obvious environment setup** | "Must run `gcloud auth` with impersonation flag before local dev works" |
| **Migration context** | "Package `oldauth` is deprecated — new code must use `auth/v2`. Known users: [list]" |
| **PR review wisdom** | Recurring reviewer feedback that reveals undocumented rules, boundaries, or gotchas |

### Content to Reject

| Anti-Pattern | Why It Fails | Alternative |
|---|---|---|
| Lint rules | Derivable from linter config | Let the linter do its job |
| Directory listings (names only) | Derivable from `ls` | OK if adding constraints or relationships |
| Code explanations | Derivable from reading code | Document *why*, not *what* |
| Language style guides | Derivable from formatter config | Only project-specific deviations |
| Dependency lists | Derivable from `go.mod`/`package.json` | Only surprising choices and why |
| API endpoint catalogs | Derivable from specs/routes | Only non-obvious auth, rate limits, ordering |
| Build commands alone | Derivable from `Makefile`/CI | Only alongside non-obvious flags or env setup |

## Step 5 — Structure the File

Use this structure (include only sections with genuine content):

```markdown
# <Directory or Project Name>

## Build / Test / Run

<!-- Only non-obvious commands, flags, or environment requirements -->
<!-- Skip if Makefile/CI config is self-explanatory -->

## Architecture

<!-- Boundaries, invariants, import rules not enforced by tooling -->
<!-- Include known violations and migration status -->

## Conventions

<!-- Project-specific rules that deviate from community norms -->
<!-- Only rules NOT enforced by linters/formatters -->

## Gotchas

<!-- Things that will bite you if nobody tells you -->
<!-- Operational, environmental, or cross-team surprises -->
```

**Formatting rules:**

- Use tables for structured comparisons.
- Use short bullet points, not paragraphs.
- Prefer imperative mood ("Run X", "Do not import Y").
- Keep total length under 200 lines — if longer, split into subdirectory CLAUDE.md files.

## Step 6 — Review Mode

When reviewing an existing CLAUDE.md, evaluate each section:

1. **For each item**, ask: "Can an agent derive this from the codebase?"
2. **Flag** items that are derivable with a brief explanation of how.
3. **Flag** items that are vague or non-actionable.
4. **Suggest** tacit knowledge that is missing based on your codebase exploration.
5. **Output a verdict**: items to keep, items to remove, items to add.

Format the review as:

```
## CLAUDE.md Review: <path>

### Keep (tacit knowledge)
- <item> — <why it belongs>

### Remove (derivable)
- <item> — derivable via <tool/file>

### Add (missing tacit knowledge)
- <suggested item> — <why an agent would miss this>
```
