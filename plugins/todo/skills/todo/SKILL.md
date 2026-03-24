---
name: todo
description: Manage a TODO.md file at the project root. Add, complete, remove, and list tasks with priority levels. Use when the user says /todo or asks to manage tasks, todos, or action items.
---

# Todo Manager

Manage a `TODO.md` file at the project root using markdown checkboxes grouped by priority.

## File Format

```markdown
# TODO

## High Priority
- [ ] Incomplete task
- [x] Completed task

## Medium Priority
- [ ] Another task

## Low Priority
- [ ] Low priority task
```

## Commands

Parse the user's intent from their message. Supported actions:

### add [priority] [description]

Add a new item. Default priority is Medium if not specified.

1. Read `TODO.md` (create it with the `# TODO` header and all three priority sections if it doesn't exist)
2. Add `- [ ] description` under the matching priority section
3. If the priority section doesn't exist, create it in order: High, Medium, Low

### done [description or number]

Mark an item as complete.

1. Read `TODO.md`
2. Find the matching item by description substring or by counting incomplete items (1-indexed)
3. Change `- [ ]` to `- [x]`

### remove [description or number]

Remove an item entirely.

1. Read `TODO.md`
2. Find the matching item by description substring or by counting all items (1-indexed)
3. Delete the line

### list

Show current todos with a summary.

1. Read `TODO.md`
2. Display the contents
3. Print a summary line: `X of Y tasks complete`

### next / work

Work on the next highest-priority incomplete item.

1. Read `TODO.md`
2. Find the first `- [ ]` item, scanning sections in order: High, Medium, Low
3. Display the selected item to the user
4. Begin working on it (implement the change, fix the bug, etc.)
5. After completing the work, mark the item as `- [x]` in `TODO.md`

## Rules

- Always read `TODO.md` before making any changes
- Preserve all existing content and formatting
- Within each section, keep incomplete items before completed items
- When creating `TODO.md`, include all three sections (High, Medium, Low) even if empty
- If the user just says `/todo` with no arguments, run `list`
