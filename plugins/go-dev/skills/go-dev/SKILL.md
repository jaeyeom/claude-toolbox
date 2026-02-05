---
name: go-dev
description: Expert knowledge for Go development. Includes idiomatic patterns, error handling, testing, package naming, and build system detection (go toolchain, Bazel, Makefile). Use when writing, testing, or building Go code.
---

# Go Development Skill

Use this skill when the user **writes, modifies, tests, or builds Go code**.

## 1. Build System Detection

Detect the project's build system and use the appropriate commands. **Do not assume one build system over another.**

### Standard Go Toolchain (default)

Use when no `BUILD`, `BUILD.bazel`, or `WORKSPACE` files are present:

```bash
go build ./...
go test ./...
go test -race ./...
go vet ./...
```

### Bazel Projects

Use when `BUILD`, `BUILD.bazel`, or `WORKSPACE` files are present. **Do not use `go build` or `go test` directly** in Bazel projects — generated code (protobufs, etc.) may not resolve with the standard toolchain.

```bash
# Build and test
bazel build //path/to:target
bazel test //path/to:target_test

# Query targets
bazel query 'kind("go_library", //path/to/package/...)'
bazel query 'kind("go_test", //path/to/package/...)'
```

### Makefile Projects

Use when a `Makefile` is present with Go-related targets:

```bash
make build
make test
make lint
```

## 2. Linting

### Standard Go Toolchain

Use `go vet` and `golangci-lint` if available:

```bash
go vet ./...
golangci-lint run ./...
```

### Bazel Nogo

In Bazel projects, nogo analyzers run during `bazel build`. These are **compilation errors, not warnings**.

**Do not add `//nolint` directives carelessly:**

- **First**: Understand why the linter is complaining.
- **Second**: Fix the code to comply.
- **Only as last resort**: Add `//nolint:<analyzer>` with a comment explaining why.

```go
// BAD - suppressing without understanding
//nolint:ineffassign
x = computeValue()

// ACCEPTABLE - fix requires out-of-scope changes
//nolint:lintername // TODO: Requires updating callers across multiple packages
```

**When `//nolint` might be appropriate:**
- Fix requires significant unrelated changes out of scope
- Linter false positive (e.g., function used via reflection)
- Implementing an external interface that requires a specific pattern

**When `//nolint` is NOT appropriate:**
- "I don't understand why it's complaining"
- "It's easier than fixing"
- "It is needed in the future"
- The fix is within scope of the current change

### Common Analyzers

| Analyzer      | Purpose                                |
|---------------|----------------------------------------|
| `godot`       | Comments should end with a period.     |
| `ineffassign` | Detects ineffectual assignments.       |
| `staticcheck` | Various Go best practices.             |
| `govet`       | Unreachable code, format mismatches.   |
| `errcheck`    | Unchecked error return values.         |
| `gosimple`    | Suggests code simplifications.         |

### Unused Interfaces? Delete Them

If a linter reports an unused interface, **delete the interface** rather than adding artificial usage:

```go
// BAD - artificial usage to silence the linter
var _ MyInterface = (*MyImpl)(nil)

// GOOD - just delete the unused interface entirely
```

Interfaces should be defined where they are used. If nothing uses it, it shouldn't exist.

## 3. Gazelle (Bazel Projects Only)

Use Gazelle to manage BUILD files when the project has Gazelle configured:

```bash
# Generate/update BUILD files for a directory
bazel run //:gazelle -- update path/to/package

# Fix BUILD files
bazel run //:gazelle -- fix path/to/package

# Update deps from go.mod
bazel run //:gazelle -- update-repos -from_file=go.mod

# Format BUILD files (if buildifier is configured)
bazel run //:buildifier
```

### Adding External Dependencies (Bazel)

1. Add to `go.mod`: `go get github.com/external/package`
2. Tidy: `go mod tidy`
3. Sync to Bazel: `bazel run //:gazelle -- update-repos -from_file=go.mod`
4. Regenerate BUILD files: `bazel run //:gazelle -- update path/to/package`

### Adding External Dependencies (Standard)

1. Add: `go get github.com/external/package`
2. Tidy: `go mod tidy`

## 4. Directory and Package Naming

**Directory names are hard to change later.** Get them right from the start.

### Go Package Naming Convention

| Rule               | Good          | Bad                      |
|--------------------|---------------|--------------------------|
| Lowercase only     | `datastore`   | `dataStore`, `DataStore` |
| No underscores     | `loguploader` | `log_uploader`           |
| No hyphens         | `apiserver`   | `api-server`             |
| Short, clear names | `health`      | `healthcheckservice`     |

### Directory Structure

```
myproject/
├── cmd/                    # Entry points
│   └── myapp/
│       └── main.go
├── internal/               # Private packages
│   └── auth/
│       ├── auth.go
│       └── auth_test.go
├── pkg/                    # Public packages (optional)
│   └── client/
│       └── client.go
├── go.mod
└── go.sum
```

### Package Documentation

Put package-level documentation in a file named after the package or in `doc.go`:

```go
// Package health provides health checking functionality for services.
//
// It supports multiple health check types including liveness and readiness
// probes compatible with Kubernetes.
package health
```

## 5. Code Style

### Error Handling: Handle OR Return, Not Both

Either handle the error or return it, but not both. Logging at error level and returning duplicates logs.

```go
// BAD - logs error AND returns it (duplicates logs)
if err != nil {
    slog.Error("operation failed", "reason", err)
    return err
}

// GOOD - just return (let caller decide how to handle)
if err != nil {
    return fmt.Errorf("operation failed: %w", err)
}

// GOOD - handle it here (don't return the error)
if err != nil {
    slog.Error("operation failed, using fallback", "reason", err)
    return fallbackValue, nil
}
```

**Exception:** Log at service/process boundaries where you don't control the caller.

### Error Wrapping

Use standard library patterns:

```go
// Wrap with context
return fmt.Errorf("failed to fetch user: %w", err)

// Join multiple independent errors
return errors.Join(err1, err2)
```

### Logging

Use `log/slog` for structured logging:

```go
slog.Info("starting operation", "param", val)
slog.Debug("detailed info for debugging", "state", s)
slog.Error("operation failed", "err", err, "userID", id)
```

### Interfaces

Define interfaces where they are **used**, not where implemented:

```go
// In the consumer package, not the provider
type Storage interface {
    Save(ctx context.Context, data []byte) error
}
```

### Context

- First parameter of functions that do I/O or may be cancelled.
- Never store in structs.
- Use `context.WithTimeout` or `context.WithCancel` to manage lifetimes.

```go
func (s *Service) Process(ctx context.Context, req *Request) error {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    return s.db.Query(ctx, req.ID)
}
```

## 6. Testing

### Run Tests with Race Detector

```bash
# Standard Go
go test -race ./...

# Bazel
bazel test //path/to:target_test --@io_bazel_rules_go//go/config:race
```

### Table-Driven Tests

Always include the test case name in failure messages:

```go
func TestParse(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {name: "valid number", input: "42", want: 42},
        {name: "negative", input: "-1", want: -1},
        {name: "invalid", input: "abc", wantErr: true},
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            got, err := Parse(tc.input)
            if (err != nil) != tc.wantErr {
                t.Fatalf("Parse(%q) error = %v, wantErr %v", tc.input, err, tc.wantErr)
            }
            if got != tc.want {
                t.Errorf("Parse(%q) = %d, want %d", tc.input, got, tc.want)
            }
        })
    }
}
```

### Test Helpers

Use `t.Helper()` in test helper functions so failures report the caller's line:

```go
func assertEqual(t *testing.T, got, want any) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}
```

## 7. Formatting

### Standard Go

```bash
gofmt -w .
# or stricter
gofumpt -w .
# or with import grouping
goimports -w .
```

### Bazel

Check if the project has a format target:

```bash
bazel run //:format        # Write changes
bazel run //:format.check  # Dry run
```
