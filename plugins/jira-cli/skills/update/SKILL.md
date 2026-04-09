---
name: update
description: Update a Jira ticket description after investigating the codebase
argument-hint: <PROJ-123>
---

Update Jira ticket with the following steps

1. Read Jira issue $ARGUMENTS with `jira issue view $ARGUMENTS` command.
2. Investigate further with the given information and the code base in the repo.
   Use web search tools if available and necessary.
3. Write the updated task description content in a temporary file:
   - Use actual newlines, not `\n` escape sequences and backslash escapes.
   - Use Jira wiki markup formatting (see the `edit-description` skill for
     detailed formatting rules).
   - Jira supports code blocks with `{code:language}...{code}` syntax
   - Common language options: java, go, python, javascript, bash, etc.
4. Update a Jira ticket using jira command:
   `jira issue edit $ARGUMENTS -s"Summary Text" -b"$(cat description.txt)" --no-input`
