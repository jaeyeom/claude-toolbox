---
name: create-lang-dev-skill
description: Create a language-specific development skill by mining PR reviews, codebase conventions, build system patterns, and team documentation. Use when the user wants to create a new lang-dev skill (e.g., rust-dev, go-dev, python-dev) for their project.
---

# Create Language-Dev Skill

Use this skill when the user wants to **create a new language-specific development skill** for their project (e.g., rust-dev, go-dev, python-dev, java-dev).

## Overview

A lang-dev skill captures the conventions that live in reviewers' heads — the patterns that linters and formatters can't enforce. This skill guides you through a systematic process to extract those conventions and produce a high-quality skill file.

**Target output:** The final skill file should be **under 500 lines** — scannable, not encyclopedic. Keep this constraint in mind throughout every phase so you collect the most impactful conventions rather than exhaustively cataloging everything.

## Phase 1: Discovery — Understand the Landscape

### 1.1 Find the language footprint

Identify all files for the target language and map the directory structure.

```
- Count total files (e.g., *.rs, *.go, *.py)
- Identify major modules/packages/crates
- Map the directory tree by domain (CLI tools, libraries, services, etc.)
```

**What to look for:**
- How many files exist? (< 50 = small footprint, 50-500 = medium, 500+ = large)
- Are they concentrated in one area or spread across the repo?
- Is there a workspace/monorepo structure?

#### Monorepo considerations

If the project is a monorepo with multiple packages, services, or crates:
- Determine whether conventions are **repo-wide** or **per-package**. Some monorepos have different teams and styles per subdirectory.
- Check for a top-level build config (e.g., root `Cargo.toml` workspace, Go workspace `go.work`, Bazel `WORKSPACE`) that unifies builds.
- Ask the user whether the skill should cover the **entire repo** or a **specific subtree**. Scoping to a subtree keeps the skill focused and under the 500-line target.
- When mining PRs later (Phase 2), filter by the relevant path prefix to avoid mixing conventions from unrelated parts of the repo.

### 1.2 Identify the build system

Determine how the language is built, tested, linted, and formatted. **Do not assume** — verify each claim against actual config files and CI pipelines.

**Check these in order:**
1. Build config files (BUILD/BUILD.bazel, Makefile, package.json, pyproject.toml, go.mod, etc.)
2. CI pipeline configs (.circleci/, .github/workflows/, Jenkinsfile, etc.)
3. Formatter/linter configs (.eslintrc, .golangci.yml, clippy.toml, ruff.toml, etc.)
4. Root-level scripts or Makefiles that wrap build commands

**Key questions to answer:**
- What is the canonical build command? (e.g., `bazel build`, `go build`, `npm run build`)
- What is the canonical test command?
- What is the canonical lint command? Is linting separate or integrated into the build?
- What is the canonical format command?
- Can the native language toolchain be used (e.g., `cargo test`, `go test`), or must you use the build system (e.g., `bazel test`)? **Verify this — don't assume.**

### 1.3 Ask for team documentation

**Always ask the user** if they have internal documentation. This is often the most valuable source.

Prompt the user with:
> Do you have any of the following for this language?
> - Wiki/Confluence pages about development conventions
> - Style guides or coding standards documents
> - Onboarding docs for new developers
> - ADRs (Architecture Decision Records)
> - README files in language-specific directories
>
> These are often the most authoritative source for conventions that go beyond linters.

If documentation exists, use it as the **primary source of truth** — it overrides patterns inferred from code alone.

## Phase 2: Mine PR Reviews — The Core Value

This is where the most valuable, non-obvious conventions live. Linters catch syntax; PR reviews catch design.

### 2.1 Find PRs that touch the target language

The examples below use the GitHub `gh` CLI. If the project uses **GitLab** (`glab`), **Bitbucket**, or another platform, adapt the commands to the equivalent API. The key data you need is the same: a list of merged PRs with their review comments.

```bash
# Get recent merged PRs (adjust owner/repo)
gh pr list --state merged --limit 100 --json number,title,files

# Filter for PRs touching the target language files
# Look for .rs, .go, .py, .java, .ts, etc.
```

**Target: 15-30 PRs with substantive review comments.** If fewer exist, the language may be too new in the project for a full skill — supplement with `git log --all --follow` history and `git blame` archaeology on key files to surface conventions that predate formal code review. Note this limitation in the final skill.

### 2.2 Extract review comments

```bash
# Get the repo owner/name
gh repo view --json owner,name

# For each PR, get inline review comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
```

### 2.3 Categorize comments

Classify each comment into one of these buckets. **Ignore** anything that a linter or formatter would catch automatically.

| Category | What to Look For |
|----------|-----------------|
| **String/formatting patterns** | Format string conventions, logging patterns |
| **Error handling** | Error propagation style, context/wrapping, fail-fast vs. graceful |
| **Architecture** | Module organization, separation of concerns, layer boundaries |
| **Naming** | Semantic naming rules, domain-specific terminology, URL/API naming |
| **Type design** | Generic vs. concrete types, ownership/borrowing, interface design |
| **Testing** | Test expectations, test isolation, mocking patterns, what to test |
| **Logging/observability** | Which logging framework, structured vs. unstructured, log levels |
| **Configuration** | Hardcoded vs. configurable, defaults, env vars vs. flags |
| **Dependencies** | Preferred libraries, version management, internal vs. external |
| **Code organization** | File layout, module boundaries, shared code extraction |
| **Build system** | Build target patterns, visibility rules, CI integration |
| **Documentation** | Doc comment expectations, what needs docs, example requirements |
| **Performance** | Unnecessary allocations, cloning, concurrency patterns |
| **Security** | Input validation, secret handling, auth patterns |

These are common categories, but let the actual PR comments drive the taxonomy. Create new categories if a project has a dominant pattern not listed here (e.g., "migration patterns" for a database-heavy project, or "FFI boundaries" for a mixed-language codebase).

### 2.4 Count and rank

For each category, record:
- **Frequency**: How many times it appeared across PRs
- **Reviewers**: Which reviewers raised it (identifies subject-matter experts)
- **Example quotes**: Direct quotes from the most clear/representative comments

**Rank categories by frequency.** The top 5-7 categories become the core sections of the skill.

## Phase 3: Verify — Trust but Check

**Every claim in the skill must be verified against the actual codebase or documentation.**

### 3.1 Verify build commands

First, **inspect configuration files** (BUILD files, Makefiles, CI configs, `package.json` scripts, etc.) to verify every command you plan to document. Check that:
- The build target exists
- The target name is correct (e.g., `:lib_test` vs `:my_crate_test`)
- The format command includes this language
- Linting is integrated into the build or is a separate step

If inspection alone is ambiguous, run the commands to confirm — but prefer reading config files as the primary verification method, since running commands may have side effects or require environment setup.

### 3.2 Verify conventions against code

For each convention from PR reviews, check if the codebase actually follows it:
- Search for counter-examples (code that violates the convention)
- If violations are widespread, the convention may be aspirational, not enforced — note this
- If violations are rare and recent PRs fix them, the convention is real

### 3.3 Cross-reference with documentation

If the user provided wiki/docs, check for contradictions between:
- What PR reviewers say
- What the documentation says
- What the code actually does

**Documentation wins** over inferred patterns. Note contradictions for the user.

## Phase 4: Write the Skill File

### 4.1 Structure

Follow this template:

```markdown
---
name: {lang}-dev
description: Expert knowledge for {Language} development in {Project}. Includes {key topics}. Use when writing, testing, or building {Language} code.
---

# {Language} Development Skill

Use this skill when the user **writes, modifies, tests, or builds {Language} code**.

## 1. The Golden Rule: {Most Important Build/Workflow Rule}
{Build system, canonical commands, what NOT to do}

## 2. {Highest-Frequency Convention, e.g., Error Handling}
{BAD/GOOD examples, rationale}

## 3. {Second-Highest Convention, e.g., Naming}
{BAD/GOOD examples, rationale}

## 4. {Third Convention, e.g., Testing Patterns}
{BAD/GOOD examples, rationale}

## 5. {Fourth Convention, e.g., Architecture/Module Boundaries}
{BAD/GOOD examples, rationale}

## 6. {Fifth Convention, e.g., Logging/Observability}
{BAD/GOOD examples, rationale}

## 7. Workspace and Dependency Management
{How to add dependencies, version management, preferred libraries}

## 8. Advanced Topics (Read These Files)
{DO NOT GUESS — read the authoritative source}
```

Adjust the number of convention sections (2-6 above) based on what the PR review mining actually found. The numbered structure is a guide, not a straitjacket — use as many or as few convention sections as the data supports.

### 4.2 Writing guidelines

**DO:**
- Lead with the build system — it's the most common source of confusion
- Rank convention sections by PR review frequency (most common first)
- Include BAD/GOOD code examples for every convention
- Use actual project examples when possible (anonymize if needed)
- Note when a convention is aspirational vs. enforced
- Include a "Read These Files" section for topics too detailed to inline
- Keep it under 500 lines — skills should be scannable, not encyclopedic

**DON'T:**
- Don't document what linters/formatters already enforce
- Don't guess build commands — verify them against BUILD files and CI
- Don't include language basics (the reader already knows the language)
- Don't present inferred patterns as rules without verification
- Don't mix up aspirational conventions with enforced ones
- Don't include team-specific names or internal URLs (for publishable skills)

### 4.3 The "Read These Files" section

Every skill should end with pointers to authoritative files for advanced topics. This prevents the LLM from guessing. You can also embed inline references (e.g., "See `path/to/file` for details") throughout the skill where contextually appropriate.

```markdown
## Advanced Topics (Read These Files)

**DO NOT GUESS** on advanced topics. Read the authoritative source:

### `build/ci-config.yaml`
Read this file when:
- User asks about CI pipeline behavior
- User needs to add a new build target or test job

### `.golangci.yml` (or equivalent linter config)
Read this file when:
- User asks which linters are enabled and why
- User wants to suppress or configure a specific lint rule

### `docs/architecture.md`
Read this file when:
- User asks about module boundaries or layering
- User proposes a new package or significant refactor
```

## Phase 5: Review with the User

Before finalizing, present the skill to the user and ask:

1. **Are the build commands correct?** (Most common error source)
2. **Are there conventions I missed?** (User often knows unwritten rules)
3. **Do you have internal docs that contradict anything here?**
4. **Is anything documented as a rule that's actually aspirational?**

## Checklist

Before declaring the skill complete:

- [ ] Build/test/lint/format commands verified against actual config files
- [ ] Top 5+ convention categories identified from PR reviews
- [ ] Each convention has BAD/GOOD code examples
- [ ] No conventions that linters/formatters already enforce
- [ ] Cross-referenced with team documentation (if available)
- [ ] "Read These Files" section for advanced topics
- [ ] Under 500 lines
- [ ] User reviewed and confirmed accuracy
