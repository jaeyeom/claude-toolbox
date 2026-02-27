# Create Language-Dev Skill Plugin

Create language-specific development skills (e.g., rust-dev, go-dev, python-dev) by systematically mining PR reviews, codebase conventions, build system patterns, and team documentation.

## Components

| Component              | Type  | Description                                                       |
| ---------------------- | ----- | ----------------------------------------------------------------- |
| `create-lang-dev-skill` | Skill | Guides creation of a lang-dev skill from PR reviews and codebase |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install create-lang-dev-skill
```

## Usage

Activate the skill when you want to create a new development skill for a language:

- "Create a Rust development skill for this project"
- "Build a Python dev skill from our PR reviews"
- "Generate a Go development skill capturing our team conventions"
- "Mine our Java PR comments to create a dev skill"

## What It Covers

1. **Discovery** - Map language footprint, build system, and team documentation
2. **PR Mining** - Extract conventions from review comments and rank by frequency
3. **Verification** - Cross-check every claim against actual code and config files
4. **Writing** - Produce a structured, scannable skill file under 500 lines
5. **Review** - Validate accuracy with the user before finalizing
