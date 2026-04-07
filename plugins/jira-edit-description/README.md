# Jira Edit Description

A Claude Code skill for editing Jira issue descriptions with proper wiki markup
formatting using the `jira` CLI tool.

## Features

- Write well-formatted Jira descriptions using wiki markup
- Handle special characters, code blocks, and multi-section docs
- Avoid common pitfalls (backslash escaping, numbered list `#` issues)
- Complete markup reference and troubleshooting guide

## Prerequisites

- [jira CLI](https://github.com/ankitpokhrel/jira-cli) installed and configured

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install jira-edit-description
```

## Usage

The skill activates automatically when you ask to edit or update a Jira issue
description. It guides Claude to use temporary files and proper wiki markup
syntax.
