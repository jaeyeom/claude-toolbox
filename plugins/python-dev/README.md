# Python Development Plugin

Expert knowledge for Python development. Provides uv/ruff/pytest defaults,
type hints, exception handling, and a testing rule: inject dependencies you
own, use freezegun for time in third-party code you cannot inject, and treat
monkeypatch as last resort.

## Components

| Component    | Type  | Description                                             |
| ------------ | ----- | ------------------------------------------------------- |
| `python-dev` | Skill | Guides Python development with modern toolchain defaults |

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install python-dev
```

## Usage

The skill activates automatically when you work with Python code:

- "Write a pytest for this service"
- "Add a clock so we can test expiry without monkeypatch"
- "Set up uv and ruff for this project"
- "This third-party JWT helper reads datetime.now — freeze time in the test"

## What It Covers

- **Toolchain**: Prefer `uv`, `ruff`, `pytest`, and `pyproject.toml`; fall back
  to poetry/pip, black, or Makefile/Bazel when the repo already uses them
- **Linting and formatting**: `ruff check` and `ruff format`; no `# noqa`
  without understanding
- **Type hints**: Modern syntax (`list[str]`, `X | None`) on public APIs
- **Exceptions**: Raise or handle, not both; `raise ... from err`
- **Testing**: Dependency injection for code you own; `freezegun` for
  third-party time; `monkeypatch` only as last resort
