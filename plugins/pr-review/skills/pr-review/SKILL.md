---

name: pr-review
description: Review someone else's GitHub pull request, identify actionable findings, and post them only as resolvable review discussion threads after the user approves the complete draft.
---

# PR Review Skill

Review someone else's pull request for correctness, tests, error handling,
security, simplicity, and repository conventions. Findings should explain a
concrete risk or improvement and point to the relevant change.

## Required comment placement

**A comment the author must read and act on goes in a review discussion thread,
never in the pull request's main conversation.**

- A review discussion thread is an inline or file-level review comment. It can
  be resolved and appears in the unresolved conversations count.
- An issue comment or a review's top-level body is easy to miss and cannot be
  resolved. Never put a required item there.
- When a finding has no natural changed line (for example, a design concern, a
  missing test, or a missing file), anchor it to the most relevant changed line
  or file. Use a file-level comment when the API supports it. Never move such a
  finding into the conversation.
- A review's top-level body may contain only a short summary pointing to the
  threads, such as “3 threads to address, 2 optional nits.” It must not introduce
  another required item.
- On a re-review, add a follow-up to the existing thread when it covers the
  finding. Do not create a new conversation comment.

## Workflow

### 1. Gather the pull request state

Identify the repository and pull request number. Gather:

- PR metadata, including base and head commits
- the full diff
- existing review threads, including resolved and unresolved threads
- CI/check status

Use `gh-pr-review capture` and `gh-pr-review pull` when available. Otherwise,
use `gh pr view`, `gh pr diff`, and GitHub's pull-request/review APIs. Include
resolved threads when checking for duplicates. Do not post anything while
gathering or reviewing.

### 2. Review and draft findings

Inspect the changed code and relevant surrounding context. Consider
correctness, tests, error handling, security, simplicity, and repository
conventions. Avoid speculative findings and comments that only restate the
code.

For each finding, record:

- severity: `must-fix`, `should-fix`, or `nit`
- a concise explanation of the problem and its impact
- a concrete suggested action when helpful
- an exact anchor on the pull request's head side: changed file and line, or a
  file-level anchor

Skip a finding already covered by an unresolved thread. If new information
needs to be added to that finding, draft a reply in its existing thread.

### 3. Show the complete review draft and get approval

Before posting, show the user every proposed thread with its severity, exact
file/line (or file-level anchor), and full comment text. Also show the proposed
one-paragraph top-level summary. Clearly identify any proposed reply to an
existing thread.

Wait for the user's explicit approval of the draft before posting anything.
If the user requests changes, revise the draft and show it again. Do not post
partial findings while approval is pending.

### 4. Post the approved review as one review

Use `gh-pr-review comment` plus `submit` when available. Otherwise, submit one
pending review with all inline/file-level comments using:

```text
POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews
```

Use the `comments` array with `path`, `line`, and `side: RIGHT` for a line
comment on the head diff. For file-level comments, use `subject_type: file` and
the relevant `path` when supported. For replies, use the existing thread's
comment identifier with the review API's reply mechanism. Never use
`gh pr comment` or the issues comments API for review findings.

Choose `COMMENT` by default. When there are `must-fix` findings, use
`REQUEST_CHANGES` only if the user approved submitting that event. Use
`APPROVE` only when the user explicitly asks for approval. The top-level review
body is the short summary already shown to the user and may only point to the
threads; it must not carry new required items.

Submit the single review only after all its comments match the approved draft.

### 5. Report the result

Report the review state and links to the posted threads. If nothing actionable
was found, say so without posting an empty review.

## Dry-run walkthrough

Suppose a diff adds a required field to an API response but has no natural line
for the missing compatibility test. Draft a `should-fix` finding, anchor it as
a file-level review thread on the changed response file, and show the user the
anchor and full comment before submission. The comment belongs in that review
thread, where the author can resolve it. Do not put it in the PR conversation
or in the review's top-level summary. In a dry run, stop after presenting the
draft; do not call the posting API.
