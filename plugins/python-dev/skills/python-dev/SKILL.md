---
name: python-dev
description: Expert knowledge for Python development. Includes uv, ruff, pytest, type hints, and test doubles (dependency injection, freezegun, monkeypatch). Use when writing, testing, or building Python code.
---

# Python Development Skill

Use this skill when the user **writes, modifies, tests, or builds Python code**.

## 1. Toolchain

Prefer **uv + ruff + pytest + pyproject.toml**. If the repo already uses poetry,
pip, Black, a Makefile, or Bazel, use that — do not add a parallel toolchain.

If `make test` / `make lint` / `make format` exist, run those.

Do not invent `setup.py` or `requirements.txt` when `pyproject.toml` exists.

## 2. Linting and Formatting

Use Ruff for lint and format. If the project already formats with Black, keep
Black.

**Do not add `# noqa` carelessly:**

- **First**: Understand why Ruff is complaining.
- **Second**: Fix the code to comply.
- **Only as last resort**: `# noqa: RULE` with a comment explaining why.

```python
# BAD - suppressing without understanding
x = compute_value()  # noqa: F841

# ACCEPTABLE - fix requires out-of-scope changes
legacy_name = load()  # noqa: N816  # vendor field name; rename in a follow-up
```

**When `# noqa` might be appropriate:**
- Fix requires significant unrelated changes out of scope
- False positive
- Matching an external API that requires a specific name

**When `# noqa` is NOT appropriate:**
- "I don't understand why it's complaining"
- "It's easier than fixing"
- The fix is within scope of the current change

## 3. Type Checking

Annotate public functions, methods, and dataclasses. Prefer modern syntax:

```python
def fetch_user(user_id: str) -> User | None: ...
def names(users: list[User]) -> dict[str, User]: ...
```

Use `list[str]`, `dict[str, int]`, and `X | None` — not `List`, `Dict`, or
`Optional` from `typing` unless the project's Python version requires them.

If the repo already runs **mypy** or **pyright/basedpyright**, run that checker
the way the project does. Do not add a second type checker.

If there is no type checker, still write accurate annotations. Do not add a
type-checker dependency unless the user asks or the change is introducing
tooling.

## 4. Code Style

### Exceptions: raise or handle, not both

Logging an exception and re-raising it duplicates logs at every layer. Either
convert/wrap and raise, or handle it here.

```python
# BAD - logs AND re-raises
except OSError as err:
    logging.error("read failed: %s", err)
    raise

# GOOD - wrap with context
except OSError as err:
    raise ConfigError(f"cannot read {path}") from err

# GOOD - handle here
except FileNotFoundError:
    return default_config()
```

Always use `raise ... from err` when wrapping. No bare `except:`. Catch the
narrowest exception that is correct.

### Logging

Use stdlib `logging`. Do not `print` in library code.

```python
logger = logging.getLogger(__name__)
logger.info("starting sync", extra={"user_id": user_id})
```

If the project already uses a structured logger (structlog, loguru), follow
that project. Do not introduce a new logging library.

### Structured data

- **Internal values:** `@dataclass`, or a plain class if it has real behavior.
- **External I/O** (API payloads, config files, wire formats): the project's
  schema library (pydantic, msgspec, …) if it already has one. Do not add
  pydantic just to hold fields.

### Imports

Import modules, not types, classes, or functions:

```python
import datetime
import freezegun

now = datetime.datetime.now(datetime.UTC)
```

Do not `from datetime import datetime, UTC` or
`from freezegun import freeze_time`.

**Exception:** symbols from `typing`, `collections.abc`, and
`typing_extensions` that exist to support type annotations
(`from typing import Protocol`, `from collections.abc import Callable`).

### Functions and modules

- Public names are documented when behavior is not obvious from the signature.
- Avoid module-level mutable state. Pass collaborators in.

## 5. Testing

Use **pytest**. Prefer `pytest.mark.parametrize` over handwritten loops. Name
tests `test_<behavior>`.

### Test doubles: inject, freeze, then patch

```
Need to control a collaborator or the clock in a test?
  │
  ├─ We own the code? ──────────────────────► Inject it
  │                                           (constructor arg, function arg,
  │                                            protocol / callable)
  │
  ├─ Time comes from third-party code        ► freezegun
  │  we cannot inject into?
  │
  └─ Anything else we cannot inject?         ► monkeypatch / unittest.mock
                                               LAST RESORT only
```

**Code we own must be injectable.** If a test needs a fake clock, fake clock
the production API — do not patch `datetime`. Same for HTTP clients, clocks,
UUIDs, random, the filesystem, and the current user: accept them as
dependencies.

```python
import datetime
from typing import Protocol


class Clock(Protocol):
    def now(self) -> datetime.datetime: ...


class SystemClock:
    def now(self) -> datetime.datetime:
        return datetime.datetime.now(datetime.UTC)


class TokenService:
    def __init__(self, clock: Clock) -> None:
        self._clock = clock

    def is_expired(self, expires_at: datetime.datetime) -> bool:
        return self._clock.now() >= expires_at
```

```python
import datetime

from myproject import tokens


class FrozenClock:
    def __init__(self, instant: datetime.datetime) -> None:
        self._instant = instant

    def now(self) -> datetime.datetime:
        return self._instant


def test_is_expired() -> None:
    clock = FrozenClock(datetime.datetime(2024, 1, 15, 12, 0, tzinfo=datetime.UTC))
    service = tokens.TokenService(clock)
    assert service.is_expired(datetime.datetime(2024, 1, 15, 11, 0, tzinfo=datetime.UTC))
```

For a single function, a `now` callable is enough:

```python
import datetime
from collections.abc import Callable


def is_expired(
    expires_at: datetime.datetime,
    *,
    now: Callable[[], datetime.datetime] | None = None,
) -> bool:
    current = now() if now is not None else datetime.datetime.now(datetime.UTC)
    return current >= expires_at
```

A pytest fixture that **builds the SUT with fakes** is dependency injection.
A pytest fixture that only calls `monkeypatch.setattr` is still monkeypatching.

### Third-party time: freezegun

When a library you do not control calls `datetime.now` / `time.time` internally
and exposes no clock argument, use **freezegun**. Do not `monkeypatch` datetime
yourself in that situation.

```python
import freezegun


@freezegun.freeze_time("2024-01-15T12:00:00Z")
def test_third_party_token_not_expired() -> None:
    token = jwt.encode({"exp": 1_705_327_200}, "secret", algorithm="HS256")
    jwt.decode(token, "secret", algorithms=["HS256"])
```

Add freezegun as a **dev** dependency (`uv add --dev freezegun`) only when a
test needs it. Do not use freezegun for code you own — inject a clock instead.

freezegun patches time. That is allowed **only** for time originating in
third-party code you cannot inject into. It is not a license to skip DI in
first-party code.

### monkeypatch is last resort

Use `monkeypatch` or `unittest.mock.patch` only when all of these are true:

1. You cannot change the production API (or changing it is out of scope).
2. The value is not "current time" in third-party code (that is freezegun).
3. There is no seam you can pass a fake through.

```python
# LAST RESORT - vendor helper with no injection point, and not about time
import pytest

def test_legacy_vendor_id(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("vendor_sdk.ids.generate", lambda: "fixed-id")
    assert create_record().id == "fixed-id"
```

If you reach for monkeypatch on **your** module's `datetime`, `time`, `uuid`,
`random`, or a client class you own, stop. Add a constructor/function argument
and inject a fake.

### Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's only a test; patching is faster" | The test is telling you the API is hard to test. Inject. |
| "I'll add a clock parameter later" | Add it now. The test is the reason. |
| "freezegun is also monkeypatching, so skip both" | freezegun is the tool for third-party time. DI is the tool for our time. |
| "The class calls datetime.now in many places" | One clock dependency replaces all of them. Do not patch `datetime`. |
| "A fixture that monkeypatches is cleaner" | A fixture that only patches is still monkeypatch. |
| "unittest.mock.Mock is the pytest way" | pytest does not require mocks. Inject fakes you control. |
| "Third-party code, but I can patch its datetime" | Use freezegun for time. Do not hand-roll datetime patches. |

### Red flags — stop and inject (or freezegun)

- `monkeypatch.setattr` on `datetime`, `time`, `uuid`, or a class you own
- `unittest.mock.patch("...datetime")` / `patch("...time.time")`
- `MagicMock` for a collaborator whose source you can edit
- "I'll refactor to DI in a follow-up"
- Using freezegun on first-party code that could take a `clock` / `now`

**All of these mean: change the production API (or use freezegun for
third-party time). Do not ship the patch.**

## 6. Dependencies

Add runtime deps with `uv add`, dev deps with `uv add --dev`. Pin via the
lockfile (`uv.lock`). Do not add packages to `requirements.txt` in a uv
project.

Greenfield defaults: `uv`, `ruff`, `pytest`. Add `freezegun` as a dev
dependency only when a test needs it.

Do not add `pytest-mock` just to make patching easier. If tests need
`pytest-mock` / `unittest.mock` / `monkeypatch`, first check whether injection
or freezegun applies.
