---
name: new-bug
description: Create a new Jira bug report with proper wiki markup formatting
---

Report Jira bug with the following steps

1. First, write the bug report content in a temporary file:
   - Use actual newlines, not `\n` escape sequences and backslash escapes.
   - Use Jira wiki markup formatting (see the `jira-edit-description` skill for
     detailed formatting rules).
   - Jira supports code blocks with `{code:language}...{code}` syntax
   - Common language options: java, go, python, javascript, bash, etc.

2. Create a bug using jira command:
   - If the $ARGUMENTS looks like a project name without number, run the command
     `jira issue create -tBug -s"Summary Text" -b"$(cat description.txt)" -p$ARGUMENTS`.
   - If the $ARGUMENTS looks like a ticket name with the number, run the command
     `jira issue create -tBug -s"Summary Text" -b"$(cat description.txt)" -P$ARGUMENTS`
     to create a bug under the given Epic.
   - Use the email address from `jira me` to set the assignee:
     `-a"$(jira me --raw | jq -r '.emailAddress')"`.
