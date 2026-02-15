# CI Workflow Plugin

Generate GitHub Actions CI workflows that mirror local Makefile targets for consistent local and CI behavior.

## Components

| Component     | Type  | Description                                              |
| ------------- | ----- | -------------------------------------------------------- |
| `ci-workflow` | Skill | Guides generation of GitHub Actions CI workflow files     |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install ci-workflow
```

## Usage

Ask for CI setup and the skill will apply:

- "Set up GitHub Actions CI for this repo"
- "Create a CI workflow that runs our Makefile targets"
- "Add continuous integration to this project"
- "Generate a CI/CD pipeline for this Go project"

## How It Works

1. **Detects** your project context: Makefile presence, language stack (Go, Node.js), existing workflows
2. **Chooses** a strategy: Makefile-first (preferred) or direct commands as fallback
3. **Generates** `.github/workflows/ci.yml` with concurrency control, pinned action versions, and version-from-file
4. **Validates** YAML syntax, referenced Makefile targets, and action versions
5. **Explains** what was generated and how to customize further

## Works With

- [makefile-workflow](../makefile-workflow/) — Create the Makefile targets that CI will call
- [gabyx-githooks-setup](../gabyx-githooks-setup/) — Enforce hooks locally that CI validates
