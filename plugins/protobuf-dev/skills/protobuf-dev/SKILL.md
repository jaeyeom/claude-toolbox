---
name: protobuf-dev
description: Expert knowledge for Protocol Buffer development. Includes style guidelines, backward compatibility, design patterns, and build system detection (buf, Bazel). Use when creating, modifying, or reviewing .proto files or proto build rules.
---

# Protocol Buffer Development Skill

Use this skill when the user **creates, modifies, or reviews `.proto` files or proto build rules**.

## 1. Build System Detection

Detect the project's build system and use the appropriate commands. **Do not assume one build system over another.**

### buf (default)

Use when a `buf.yaml` or `buf.gen.yaml` is present:

```bash
buf lint
buf format -w
buf generate          # generate code from protos
buf breaking --against '.git#branch=main'
```

### Bazel Projects

Use when `BUILD`, `BUILD.bazel`, or `WORKSPACE` files are present:

```python
load("@rules_proto//proto:defs.bzl", "proto_library")

proto_library(
    name = "example_proto",
    srcs = ["example.proto"],
)
```

Multi-language targets follow this pattern:

```python
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@rules_cc//cc:defs.bzl", "cc_proto_library")

proto_library(
    name = "example_proto",
    srcs = ["example.proto"],
)

cc_proto_library(
    name = "example_cc_proto",
    deps = [":example_proto"],
)

go_proto_library(
    name = "example_go_proto",
    importpath = "example.com/path/to/example_proto",
    protos = [":example_proto"],
)
```

## 2. Proto File Style

### Required File Structure

```protobuf
edition = "2024";

package mycompany.myservice.v1;

// Language-specific options
option go_package = "example.com/path/to/package/name_proto";
option java_package = "com.example.myservice.v1";

// Imports (sorted alphabetically)
import "google/protobuf/timestamp.proto";

// Messages and enums (alphabetically ordered)
```

### Naming Conventions

| Element        | Style                  | Example            |
|----------------|------------------------|--------------------|
| Message names  | PascalCase             | `UserProfile`      |
| Field names    | snake_case             | `user_name`        |
| Enum names     | PascalCase             | `StatusCode`       |
| Enum values    | SCREAMING_SNAKE_CASE   | `STATUS_ACTIVE`    |
| Enum zero value| Must end with `_UNKNOWN` or `_UNSPECIFIED` | `STATUS_UNKNOWN = 0` |
| Service names  | PascalCase             | `UserService`      |
| RPC names      | PascalCase             | `GetUser`          |

## 3. Documentation: The Fine-Print Contract

**Write protobuf comments like detailed fine-print contracts.** Proto files are high-level interfaces shared across services and across time. Anyone writing code that uses this interface should have a crystal-clear understanding of the expected values.

**Base rule:** When other developers read your code just by looking at the field name and type, they should know exactly what values to expect. If not, use a better name or add more comments/examples.

### Document Everything

All of these **MUST** have documentation comments:
- Messages
- Fields
- Enums
- Enum values
- Services and RPCs

### Include Example Values

Always show example values when the format isn't obvious:

```protobuf
// Bad - unclear format
string timestamp = 1;
string software_version = 2;

// Good - with examples
// Represents process error codes as a 3-character string.
// E.g. "001", "022"
string error_code = 1;

// The unique device identifier. E.g. "device-abc123"
string device_id = 2;

// Software version in release format. E.g. "22.01", "release-22.01"
string software_version = 3;
```

### Specify Zero or Missing Value Behavior

By default, unset scalar fields are indistinguishable from zero values (implicit field presence). **Document what empty/zero means:**

```protobuf
// The user's preferred language code (ISO 639-1).
// E.g. "en", "ko". Empty string means the system default will be used.
string language_code = 1;

// Maximum retry attempts. Zero means no retries (fail immediately).
int32 max_retries = 2;

// Optional deadline for the operation.
// If not set (null), the operation has no timeout.
google.protobuf.Timestamp deadline = 3;
```

### RPC Error Documentation

For RPC services, **document possible error codes and failure conditions:**

```protobuf
service DeviceService {
  // GetStatus returns the current device status.
  //
  // Errors:
  //   - NOT_FOUND: Device with the given ID does not exist.
  //   - UNAVAILABLE: Device is offline or unreachable.
  //   - PERMISSION_DENIED: Caller lacks permission to access this device.
  rpc GetStatus(GetStatusRequest) returns (GetStatusResponse);

  // ExecuteCommand sends a command to the device.
  //
  // Errors:
  //   - INVALID_ARGUMENT: Command parameters are malformed.
  //   - FAILED_PRECONDITION: Device is not in a state to execute command
  //     (e.g., emergency stop is active).
  //   - DEADLINE_EXCEEDED: Device did not respond within timeout.
  rpc ExecuteCommand(ExecuteCommandRequest) returns (ExecuteCommandResponse);
}
```

### Complete Example

```protobuf
// UserProfile represents a user's public profile information.
message UserProfile {
  // The unique identifier for the user. E.g. "user-abc123"
  // Empty string is invalid and should never occur.
  string user_id = 1;

  // User's display name. E.g. "John Doe"
  // Empty string means the user has not set a display name.
  string display_name = 2;

  // Status indicates the user's current account status.
  enum Status {
    // STATUS_UNKNOWN is the default unset value.
    // Treat as an error if received.
    STATUS_UNKNOWN = 0;
    // STATUS_ACTIVE indicates the user is active and can use the system.
    STATUS_ACTIVE = 1;
    // STATUS_SUSPENDED indicates the user is temporarily suspended.
    STATUS_SUSPENDED = 2;
  }

  // Current account status. STATUS_UNKNOWN should never be set explicitly.
  Status status = 3;
}
```

## 4. Backward Compatibility

### Never Change Field Numbers

Field numbers are part of the wire format. Changing them breaks all existing serialized data and communicating peers.

If you delete a field, **reserve** both the field number and name:

```protobuf
message UserProfile {
  reserved 3, 7;
  reserved "old_field", "legacy_name";
  // ...
}
```

Do not reorganize or renumber fields. Field numbers are not meant to be sequential or tidy.

### Never Change Package or Message Names

The protobuf package path is orthogonal to language-specific import paths (e.g., `go_package`, `java_package`). Changing the protobuf package or message name is risky because:

- `google.protobuf.Any` encodes the full type URL (e.g., `type.googleapis.com/mypackage.MyMessage`). If sender and receiver use different proto versions, unmarshaling fails.
- Adding a `package` line where none existed is equally risky.

```protobuf
edition = "2024";
package mycompany.myservice.v1;  // Changing this breaks Any compatibility
```

### Field Name Changes

Field names are backward compatible for the **binary** wire format. However, they can break:
- JSON serialization (field names are used as JSON keys)
- Text proto format
- Field masks

Treat field name changes with caution in APIs that use JSON or text proto.

### Deprecation Protocol

When deprecating a field:

1. Mark it with `[deprecated = true]` and add a comment explaining:
   - **Why** it is deprecated
   - **What replaces it** (the recommended alternative)
   - **When** it will be removed (if known)
2. Ensure it **still works** — deprecation does not mean removal
3. No new code should depend on it

```protobuf
// DEPRECATED: Use display_name instead. Will be removed in v2.
// The user's full name.
string full_name = 3 [deprecated = true];
```

When ready to remove, delete the field and reserve both the number and name.

## 5. Design Patterns

### Prefer Enums Over Booleans

Boolean fields often grow beyond two states, and they have backward compatibility problems.

**The expansion problem:**

```protobuf
// Bad - what if we add bzip, zstd later?
bool compressed = 2;

// Good - extensible
enum Compression {
  COMPRESSION_UNSPECIFIED = 0;
  COMPRESSION_NONE = 1;
  COMPRESSION_GZIP = 2;
  COMPRESSION_ZSTD = 3;
}
Compression compression = 2;
```

**The backward compatibility problem:**

```protobuf
// Bad - old servers won't set this field, so the zero value (false)
// is indistinguishable from an explicit "not successful"
bool success = 2;

// Good - old servers return UNSPECIFIED, which clients can handle
enum Result {
  RESULT_UNSPECIFIED = 0;
  RESULT_SUCCESS = 1;
  RESULT_FAILURE = 2;
}
Result result = 2;
```

Code handling an enum can detect unknown values and fail explicitly, rather than silently misinterpreting a default `false`.

### Prefer Nested Over Flattened Messages

Group related fields into sub-messages for clarity and reusability:

```protobuf
// Good - nested structure
message MachineMetrics {
  // Primary key identifying which device these metrics belong to.
  string device_id = 1;

  // Process represents a single OS process on the device.
  message Process {
    // The process ID. E.g. 12345
    int32 pid = 1;
    // Effective user name of the process owner. E.g. "appuser"
    string user = 2;
    // CPU usage percentage (2 decimal points). E.g. 99.99
    float cpu_used_percentage = 3;
  }

  // Running processes on the device.
  repeated Process processes = 2;
}
```

### Use Well Known Types

Prefer Well Known Types over hand-rolled equivalents.

#### Timestamp

Use `google.protobuf.Timestamp` instead of strings for time points:

```protobuf
// Bad - ambiguous format, no type safety
string timestamp = 1;

// Good - standard type with language-specific utility functions
google.protobuf.Timestamp created_at = 1;
```

`Timestamp` serializes to RFC 3339 in JSON (e.g., `"2024-01-15T07:34:51.119Z"`) and to an efficient binary format on the wire. All supported languages provide utility functions for conversion.

If you must use a string for a timestamp, use RFC 3339 or ISO 8601 and document the format explicitly.

#### Duration

Use `google.protobuf.Duration` for time spans:

```protobuf
// Bad
int64 timeout_ms = 1;

// Good
google.protobuf.Duration timeout = 1;
```

#### Any

Use `google.protobuf.Any` for polymorphic message fields. Be aware that `Any` encodes the full type URL, so all possible message types must be available in the type registry at deserialization time.

```protobuf
import "google/protobuf/any.proto";

message Event {
  google.protobuf.Timestamp time = 1;
  // The event payload. All possible event types must be registered.
  google.protobuf.Any payload = 2;
}
```

#### Other Useful WKTs

| Type | Use For |
|------|---------|
| `google.protobuf.Struct` | Arbitrary JSON-like data |
| `google.protobuf.FieldMask` | Partial updates |
| `google.protobuf.Empty` | RPCs with no request/response payload |
| `google.protobuf.StringValue` (wrappers) | Distinguishing "unset" from zero with implicit presence |

## 6. Linting

### buf lint (recommended)

```bash
buf lint
```

Configure rules in `buf.yaml`:

```yaml
version: v2
lint:
  use:
    - STANDARD
    - COMMENTS
```

The `COMMENTS` rule set enforces documentation on messages, fields, enums, enum values, services, and RPCs.

### Bazel Integration

Projects using Bazel may have custom lint test rules. Check the project's build rules for proto lint targets and follow the existing pattern:

```python
# Example pattern - actual rule names vary by project
proto_library(
    name = "example_proto",
    srcs = ["example.proto"],
)

# Check project's build_rules/ or tools/ for the actual lint rule
proto_lint_test(
    name = "example_proto_lint",
    protos = [":example_proto"],
)
```

**Naming convention:** `{name}_proto` for the library, `{name}_proto_lint` for the lint test.

## 7. Formatting

### buf format

```bash
buf format -w          # Write changes
buf format -d          # Diff (dry run)
```

### clang-format

Some projects use `clang-format` for proto files:

```bash
clang-format -i *.proto
```

### Bazel

Check if the project has a format target:

```bash
bazel run //:format    # Project-specific target name
```

## 8. JSON Serialization Gotchas

When serializing proto messages to JSON, be aware of these common pitfalls:

- **Default value stripping:** By default, fields with zero/default values are omitted from JSON output. Use your language's "include default values" option if you need them.
- **Field name casing:** Proto JSON uses camelCase by default (e.g., `user_name` becomes `userName`). Use the "preserve proto field names" option if downstream systems expect snake_case.
- **Any type registry:** When using `google.protobuf.Any` with JSON, all possible message types must be available in the type registry, or deserialization will fail.
