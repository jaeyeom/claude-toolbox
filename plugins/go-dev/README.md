# Go Development Plugin

Expert knowledge for Go development. Provides idiomatic Go patterns, error handling, testing, package naming conventions, and build system detection for both the standard Go toolchain and Bazel.

## Components

| Component | Type  | Description                                          |
| --------- | ----- | ---------------------------------------------------- |
| `go-dev`  | Skill | Guides Go development with idiomatic best practices |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install go-dev
```

## Usage

The skill activates automatically when you work with Go code:

- "Write a Go HTTP handler with proper error handling"
- "Create table-driven tests for this function"
- "Set up a new Go package for user authentication"
- "Build and test this Go project"

## What It Covers

- **Build system detection**: Automatically detects Go toolchain, Bazel, or Makefile and adapts commands
- **Package naming**: Lowercase, no underscores or hyphens
- **Error handling**: Handle OR return, never both; proper wrapping with `%w`
- **Testing**: Table-driven tests, race detector, test helpers
- **Logging**: Structured logging with `log/slog`
- **Interfaces**: Define where used, not where implemented
- **Linting**: `go vet`, `golangci-lint`, and Bazel nogo support
