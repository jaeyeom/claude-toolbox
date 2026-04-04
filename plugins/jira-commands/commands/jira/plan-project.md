---
name: plan-project
description: Plan a project by reading a design document and creating Jira tasks with dependencies
---

Plan a project with the following steps

1. First, read the design document at $ARGUMENTS and read rules in your memory.
2. Write the implementation plan listing up 10 to 20 Jira tasks in plan.md file.
   Also write up the task dependencies in the file.
3. Write each Jira task description content in a file in docs/project directory
   with enough background and context to conduct the task. Use web search tools
   if available and necessary.
   - Use actual newlines, not `\n` escape sequences and backslash escapes.
   - Use Jira wiki markup formatting (see the `jira-edit-description` skill for
     detailed formatting rules).
   - Jira supports code blocks with `{code:language}...{code}` syntax
   - Common language options: java, go, python, javascript, bash, etc.
