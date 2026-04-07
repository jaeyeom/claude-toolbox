# Protocol Buffer Development Plugin

Expert knowledge for Protocol Buffer development. Provides style guidelines, documentation best practices, backward compatibility rules, design patterns, and build system detection for buf and Bazel projects.

## Components

| Component      | Type  | Description                                              |
| -------------- | ----- | -------------------------------------------------------- |
| `protobuf-dev` | Skill | Guides proto development with best practices and patterns |

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install protobuf-dev
```

## Usage

The skill activates automatically when you work with `.proto` files:

- "Create a proto message for user profiles"
- "Add an RPC service with proper error documentation"
- "Review this proto file for backward compatibility"
- "Set up proto linting for this project"

## What It Covers

- **Build system detection**: Automatically detects buf or Bazel and adapts commands
- **Proto file style**: Naming conventions, file structure, proto3 best practices
- **Documentation**: Fine-print contract philosophy with example values and zero-value behavior
- **Backward compatibility**: Field number immutability, package name stability, deprecation protocol
- **Design patterns**: Enums over booleans, nested messages, Well Known Types
- **Linting**: buf lint, Bazel proto lint integration
- **Formatting**: buf format, clang-format
