# Gabyx Githooks Setup Plugin

A skill for setting up shared Git hooks using [gabyx/Githooks](https://github.com/gabyx/Githooks) manager.

## Components

| Component              | Type  | Description                                         |
| ---------------------- | ----- | --------------------------------------------------- |
| `gabyx-githooks-setup` | Skill | Guides setup of shared hooks via gabyx/Githooks CLI |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install gabyx-githooks-setup
```

## Prerequisites

[gabyx/Githooks](https://github.com/gabyx/Githooks) must be installed on the system. See the project README for installation instructions.

## Usage

Ask to set up githooks and the skill will apply:

- "Set up githooks in this repo"
- "Apply shared githooks to this project"
- "Add repo-specific shared hooks for this project"
