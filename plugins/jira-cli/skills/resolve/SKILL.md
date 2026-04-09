---
name: resolve
description: Investigate and resolve a Jira issue by reading the ticket, checking blockers, and making code changes
argument-hint: <PROJ-123>
---

Resolve Jira issue with the following steps

1. Read Jira issue $ARGUMENTS with `jira issue view $ARGUMENTS` command.
2. See if there are unresolved "IS BLOCKED BY" issues. If so, reject the request
   and stop.
3. Update the Jira ticket status with `jira issue move $ARGUMENTS "In Progress"`
   command.
4. Investigate and take appropriate actions to resolve the issue following the
   Jira issue description. Run `rg TICKET` from the repo root to search the
   ticket in the whole repo. If that's a TODO or FIXME comments, that's a good
   pointer for you and you may want to delete or modify them.
5. Review the code changes you've made and see if there are unnecessary comments
   that just repeat the code.
6. If you made a code change, please git commit with the proper commit log.
7. Do not mark the Jira issue as done. Leave it.
