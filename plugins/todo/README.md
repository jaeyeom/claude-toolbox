# Todo

A Claude Code skill for managing a `TODO.md` file at the project root with
priority-based task tracking.

## Features

- Add tasks with High, Medium, or Low priority
- Mark tasks as complete or remove them
- List all tasks with a completion summary
- Work on the next highest-priority item automatically

## Installation

```text
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install todo
```

## Usage

Then use `/todo` followed by a command:

- `/todo add high Implement user auth` - Add a high-priority task
- `/todo add Fix typo in README` - Add a medium-priority task (default)
- `/todo done Implement user auth` - Mark a task as complete
- `/todo remove Fix typo` - Remove a task
- `/todo list` - Show all tasks
- `/todo next` - Work on the next highest-priority task
- `/todo` - Show all tasks (default)

## TODO.md Format

```markdown
# TODO

## High Priority
- [ ] Implement user auth
- [x] Set up database schema

## Medium Priority
- [ ] Add logging

## Low Priority
- [ ] Refactor utils
```
