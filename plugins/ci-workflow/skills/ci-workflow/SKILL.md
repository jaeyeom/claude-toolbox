---
name: ci-workflow
description: Generate GitHub Actions CI workflows that call Makefile targets for consistent local and CI behavior. Use when a user asks about CI setup, GitHub Actions, continuous integration, or CI/CD pipelines.
autouse: false
---

# CI Workflow

Generate GitHub Actions workflows that mirror local Makefile targets so local and CI behavior stay identical. Supports Go, Node.js, and combined stacks.

## Instructions

### Step 1 — Detect project context

Before generating anything, check the repository:

- **Makefile**: Does one exist? Which targets does it expose (`check`, `test`, `build`, `lint`, `format`)?
- **Existing workflows**: Is there already a `.github/workflows/` directory? If so, read existing files to avoid conflicts.
- **Language stack**: Look for `go.mod` (Go), `package.json` (Node.js), or both.
- **Go version**: Check `go.mod` for the `go` directive; use that version in the matrix.
- **Go linter config**: Check for `.golangci.yml` or `.golangci.yaml` to confirm golangci-lint usage.
- **Node version**: Check `.nvmrc`, `.node-version`, or `engines` in `package.json`.

### Step 2 — Choose strategy

| Makefile? | Language | Strategy |
|-----------|----------|----------|
| Yes | Go | Makefile-first: `make check`, `make test`, `make build` |
| Yes | Node.js | Makefile-first: `make check`, `make test`, `make build` |
| Yes | Go + Node.js | Makefile-first: single `make check` covers both |
| No | Go | Direct commands: `golangci-lint run`, `go test`, `go build` |
| No | Node.js | Direct commands: `npm ci`, `npm run lint`, `npm test`, `npm run build` |
| No | Go + Node.js | Direct commands for each language in separate steps |

**Makefile-first is preferred** because it keeps CI and local behavior identical. If no Makefile exists, suggest creating one with `makefile-workflow` first.

### Step 3 — Generate workflow

Create `.github/workflows/ci.yml` using the patterns below.

#### Go + Makefile (recommended)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - run: make check

      - run: make build
```

#### Go without Makefile

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - uses: golangci/golangci-lint-action@v6

      - run: go test ./...

      - run: go build ./...
```

#### Node.js + Makefile

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          cache: npm

      - run: npm ci

      - run: make check

      - run: make build
```

#### Node.js without Makefile

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          cache: npm

      - run: npm ci

      - run: npm run lint

      - run: npm test

      - run: npm run build
```

#### Combined Go + Node.js

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          cache: npm

      - run: npm ci

      - run: make check

      - run: make build
```

### Step 4 — Validate

After generating the workflow file:

1. **YAML syntax**: Confirm the file is valid YAML (no tab indentation, correct nesting).
2. **Referenced targets**: If using Makefile-first strategy, verify the Makefile actually exposes the targets called in the workflow (e.g., `check`, `build`).
3. **Action versions**: Use pinned major versions (`actions/checkout@v4`, `actions/setup-go@v5`, `actions/setup-node@v4`).
4. **Version sources**: Confirm `go-version-file` / `node-version-file` point to files that exist.

### Step 5 — Explain

After generating, summarize:

- Which strategy was chosen and why
- What each workflow step does
- How to trigger the workflow (push to main, open a PR)
- How to customize further (see table below)

## Customization

| Need | How |
|------|-----|
| Matrix builds | Add `strategy.matrix` with Go or Node version arrays |
| Separate jobs per language | Split into `go:` and `node:` jobs under `jobs:` |
| Release on tag | Add `on: push: tags: ['v*']` trigger with a `release` job |
| Coverage upload | Add a step after tests: `uses: codecov/codecov-action@v4` |
| Caching Go modules | `actions/setup-go@v5` caches by default; no extra step needed |
| Caching Node modules | Use `cache: npm` (or `pnpm`) in `actions/setup-node@v4` |
| Branch protection | Recommend requiring the `ci` job to pass before merging |

## Best practices

- **Concurrency control**: Always include the `concurrency` block to cancel redundant runs on the same branch.
- **Pin action versions**: Use `@v4` not `@main` for stability; dependabot can update these.
- **Version from file**: Prefer `go-version-file: go.mod` and `node-version-file: .nvmrc` over hardcoded version strings so CI tracks the same version developers use locally.
- **Minimal permissions**: Set `permissions: contents: read` at the workflow level; escalate per-job only when needed.
- **Branch protection**: After the workflow is running, suggest enabling required status checks on the `ci` job.

## Cross-plugin synergy

If the project has no Makefile, suggest using the `makefile-workflow` plugin to create one first. This ensures both local (`make check`) and CI (`make check`) use the same commands, reducing drift between environments.
