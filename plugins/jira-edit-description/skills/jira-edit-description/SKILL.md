---
name: jira-edit-description
description: Edit JIRA issue descriptions using the jira CLI tool. Use when the user asks to update, modify, or edit a JIRA issue description, or when creating detailed documentation for JIRA tickets.
---

# JIRA Issue Description Editor

## Overview

This skill helps you edit JIRA issue descriptions using the `jira` CLI tool. It's particularly useful for creating comprehensive, well-formatted descriptions with proper Jira wiki markup.

## Instructions

### 1. Create Description Content in a Temporary File

Always write the description content to a temporary file first. This avoids issues with special characters, newlines, and formatting.

**Important formatting rules:**

- Use actual newlines, NOT `\n` escape sequences
- Use Jira wiki markup syntax (not Markdown)
- Common Jira markup:
  - Headers: `h2.`, `h3.`, `h4.`
  - Bold: `*text*`
  - Italic: `_text_`
  - Bullet lists: `* item` or `- item`
  - Numbered lists: Use explicit numbers (`1.`, `2.`, `3.`) — do NOT use `#` as it gets misinterpreted as Markdown H1 headings
  - Code blocks: `{code:language}...{code}` (e.g., `{code:python}`, `{code:bash}`)
  - Links: `[Link Text|URL]`

**Example:**

```bash
# Write to a temporary file
cat > /tmp/jira_description.txt << 'EOF'
h2. Background

This change improves logging practices.

h3. Problem

{code:python}
# Bad example
logger.info('value: {}'.format(x))
{code}

References:
* [Python Docs|https://docs.python.org/3/howto/logging.html]
EOF
```

### 2. Update the JIRA Issue

Use the `jira issue edit` command with the `-b` flag and command substitution:

```bash
jira issue edit ISSUE-KEY -b"$(cat /tmp/jira_description.txt)" --no-input
```

**Key points:**

- Use `-b"$(cat description_file.txt)"` to read from file
- Always include `--no-input` flag to skip interactive prompts
- The issue key format is typically `PROJECT-####` (e.g., `PROJ-1745`, `SYS-123`)

### 3. Verify the Update

Optionally verify the change:

```bash
jira issue view ISSUE-KEY
```

## Common Jira Markup Reference

| Element       | Syntax                    | Example                     |
| ------------- | ------------------------- | --------------------------- |
| Header 2      | `h2. Title`               | h2. Background              |
| Header 3      | `h3. Title`               | h3. Problem                 |
| Bold          | `*text*`                  | _important_                 |
| Italic        | `_text_`                  | _emphasis_                  |
| Bullet        | `* item` or `- item`      | \* First item               |
| Code block    | `{code:lang}...{code}`    | {code:python}print(){code}  |
| No format     | `{noformat}...{noformat}` | {noformat}C:\path{noformat} |
| Link          | `[Text\|URL]`             | [Docs\|https://example.com] |
| Numbered list | `1. item`                 | 1. Step one                 |

## Examples

### Example 1: Simple Description Update

User request: _"Update PROJ-123 description with the problem statement"_

```bash
# 1. Create description file
cat > /tmp/desc.txt << 'EOF'
h2. Problem

The API timeout is set too low, causing failures under load.

h3. Solution

Increase timeout from 5s to 30s.
EOF

# 2. Update issue
jira issue edit PROJ-123 -b"$(cat /tmp/desc.txt)" --no-input

# 3. Verify
jira issue view PROJ-123
```

### Example 2: Technical Description with Code

User request: _"Add implementation details to SYS-456"_

```bash
cat > /tmp/desc.txt << 'EOF'
h2. Implementation

h3. Changes

Fixed logging format in controller:

{code:python}
# Before
logger.info('value: {}'.format(x))

# After
logger.info('value: %s', x)
{code}

h3. Testing

All unit tests passed.

h2. References

* [Style Guide|https://internal.example.com/guide]
EOF

jira issue edit SYS-456 -b"$(cat /tmp/desc.txt)" --no-input
```

### Example 3: Multi-section Documentation

User request: _"Create comprehensive docs for PROJ-789"_

```bash
cat > /tmp/desc.txt << 'EOF'
h2. Background

Context and motivation for this change.

h3. Problem

* Issue 1: Description
* Issue 2: Description

h3. Solution

Proposed solution with benefits:
* Benefit 1
* Benefit 2

h2. Implementation

h3. Changes Made

Modified files:
* file1.py: 5 changes
* file2.py: 3 changes

h3. Testing

{code:bash}
# Run tests
pytest tests/
{code}

h2. References

* [Documentation|https://docs.example.com]
* [Ticket|https://jira.example.com/browse/PROJ-789]
EOF

jira issue edit PROJ-789 -b"$(cat /tmp/desc.txt)" --no-input
```

## Tips and Best Practices

1. **Always use a temporary file** - Never try to pass the description directly as a string argument
2. **Use heredoc syntax** (`cat > file << 'EOF'`) for multi-line content to avoid escaping issues
3. **Wrap special characters** - Use `{noformat}` or `{code}` blocks when including:
   - File paths with backslashes (e.g., `C:\Users\...`)
   - Variable/function names with underscores (e.g., `my_function_name`)
   - Any literal text that shouldn't be interpreted as wiki markup
4. **Test markup** - View the issue after updating to verify formatting looks correct
5. **Code blocks** - Always specify language for syntax highlighting (`{code:python}`, `{code:bash}`, etc.)
6. **Links** - Use descriptive text: `[Python Docs|URL]` not just the bare URL
7. **Structure** - Use headers (h2, h3) to organize long descriptions

## Common Issues

### Issue: Unwanted backslash escaping (e.g., `\_` instead of `_`)

**Problem:** Jira's wiki markup renderer automatically escapes certain characters (underscores, asterisks, backslashes) when updating via the REST API, which can cause unwanted escape sequences like `\_` or `\\` to appear in the description.

**Why it happens:** The Jira CLI communicates through the Jira REST API, which applies Atlassian wiki markup escaping to preserve formatting consistency. Characters like `_` might be interpreted as formatting (italic), so Jira escapes them.

**Solutions:**

1. **Use `{noformat}` blocks for literal text** (RECOMMENDED)

   ```
   When you need to display literal paths, code, or special characters:

   {noformat}
   C:\temp\file.txt
   variable_name_with_underscores
   {noformat}
   ```

   This tells Jira to suppress wiki rendering and display text literally.

2. **Use `{code}` blocks for code snippets**

   ```
   {code:python}
   def my_function_name():
       pass
   {code}
   ```

   Code blocks also prevent escaping and provide syntax highlighting.

3. **Avoid using special characters in plain text sections**
   - In regular text (not in code/noformat blocks), avoid underscores in identifiers
   - Use CamelCase instead of snake_case in prose
   - Or explicitly use the blocks mentioned above

**Example of proper usage:**

```
h2. Implementation

Modified the following function names:

{noformat}
- get_user_data()
- process_file_path()
{noformat}

File path: {noformat}C:\Users\Developer\project\src{noformat}
```

### Issue: Special characters breaking the command

**Solution:** Always use a file, never inline strings

### Issue: Newlines not preserved

**Solution:** Use heredoc (`<< 'EOF'`) or ensure actual newlines in file

### Issue: Code blocks not rendering

**Solution:** Verify `{code:language}...{code}` syntax with proper language tag

## Related Commands

- View issue: `jira issue view ISSUE-KEY`
- Edit other fields: `jira issue edit ISSUE-KEY -s"Summary" -yPriority`
- Get help: `jira issue edit --help`
