---
name: new-task
description: Create a new Jira task with proper wiki markup formatting
argument-hint: <PROJECT or EPIC-123>
---

Create Jira task with the following steps

1. First, write the task description content in a temporary file:
   - Use actual newlines, not `\n` escape sequences and backslash escapes.
   - Use Jira wiki markup formatting (see the `edit-description` skill for
     detailed formatting rules).
   - Jira supports code blocks with `{code:language}...{code}` syntax
   - Common language options: java, go, python, javascript, bash, etc.

2. Create a task using jira command:
   - If the $ARGUMENTS looks like a project name without number, run the command
     `jira issue create -tTask -s"Summary Text" -b"$(cat description.txt)" -p$ARGUMENTS`.
   - If the $ARGUMENTS looks like a ticket name with the number, run the command
     `jira issue create -tTask -s"Summary Text" -b"$(cat description.txt)" -P$ARGUMENTS`
     to create a task under the given Epic.
   - Use the email address from `jira me` to set the assignee:
     `-a"$(jira me --raw | jq -r '.emailAddress')"`.
