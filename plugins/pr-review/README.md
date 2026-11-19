# pr-review

A Claude Code skill for reviewing someone else's pull request and posting
actionable findings as resolvable review discussion threads.

## What It Does

- Gathers PR metadata, the diff, existing resolved and unresolved review
  threads, and CI state
- Reviews correctness, tests, error handling, security, simplicity, and project
  conventions
- Drafts findings with a severity and exact line or file-level anchor
- Shows the complete set of proposed threads and summary for approval before
  posting one review
- Keeps required findings out of the PR's main conversation and the review's
  top-level body
- Avoids duplicate findings and follows up in an existing thread when needed

## Install

```text
/plugin marketplace add jaeyeom/claude-toolbox
/plugin install pr-review
```

## Usage

Ask Claude to review a pull request, for example:

```text
Review pull request 123 in this repository.
```

The skill gathers the review context, drafts all findings, and waits for your
explicit approval before posting. Its [dry-run walkthrough](skills/pr-review/SKILL.md#dry-run-walkthrough)
demonstrates how to anchor a finding with no natural line as a file-level
thread.

### Dry-run walkthrough

Suppose a diff adds a required field to an API response but has no natural line
for the missing compatibility test. Draft a `should-fix` finding, anchor it as
a file-level review thread on the changed response file, and show the user the
anchor and full comment before submission. In a dry run, stop after presenting
the draft; do not call the posting API. The author can resolve the finding in
the review thread. Do not place it in the PR conversation or in the review's
top-level summary.

## Comment placement rule

Every item the author must address goes in an inline or file-level review
discussion thread. A top-level review body may only summarize and point to
threads. The skill never posts findings through `gh pr comment` or the issues
comments API.
