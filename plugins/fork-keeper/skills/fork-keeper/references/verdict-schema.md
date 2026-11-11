# fork-keeper verdict contract

`verdict.json` is how the sync agent hands its review to the deterministic
scheduler and promotion script in
[jaeyeom/experimental#598](https://github.com/jaeyeom/experimental/issues/598).
Both sides depend on this file. Change it only with a matching change there.

The agent writes the file. `scripts/validate-verdict.sh` checks it. If the
validator exits non-zero, the promotion script never promotes.

## Shape

```json
{
  "schema": 1,
  "verdict": "clean",
  "candidate_head": "<40-hex sha of fork-keeper/candidate>",
  "range": {
    "branch": "master",
    "upstream_old": "<sha>",
    "upstream_new": "<sha>",
    "first_run": false,
    "up_to_date": false,
    "rewritten": false,
    "review_base": "<sha or null>",
    "user_commits": ["<sha>"],
    "fork_has_merges": false,
    "fork_behind_recorded_head": false,
    "moved_tags": [{ "name": "v1", "was": "<sha>", "now": "<sha>" }],
    "deleted_tags": ["v0"]
  },
  "conflicts": [{ "commit": "<sha>", "files": ["path"], "confident": true }],
  "findings": [
    {
      "category": "secret-leak",
      "file": "path",
      "line": 12,
      "commit": "<sha>",
      "summary": "why this is an immediate threat to the user"
    }
  ],
  "summary": "one paragraph"
}
```

- `range` is the output of `scripts/review-range.sh`, copied as is.
- `verdict` is either `"clean"` or `"needs-review"`.
- `conflicts` lists every rebase conflict the agent resolved in the user's
  commits. `confident: false` means the agent was unsure of the
  resolution.
- `findings[].category` must be one of `secret-leak`, `destructive`,
  `concealment`, `supply-chain`, `repo-signal`, `agent-manipulation`, or
  `uncertain`. See `threat-checklist.md`.

## Rules enforced by `validate-verdict.sh`

The validator rejects a verdict (exit 1) when any of these hold:

1. The file is missing, or doesn't hold exactly one JSON object.
2. `schema` isn't `1`.
3. `verdict` isn't one of the two allowed values.
4. `candidate_head`, `range.upstream_old`, or `range.upstream_new` isn't a
   40-hex SHA, `range.user_commits` isn't an array of 40-hex SHAs, or
   `range.moved_tags` or `range.deleted_tags` isn't an array.
5. A finding has an unknown category.
6. `--candidate-head <sha>` was given and doesn't match `candidate_head`.
   An empty or non-40-hex `--candidate-head` is itself an error.
7. `--range <file>` was given and `range` isn't exactly equal to that file's
   JSON.
8. The verdict is `"clean"`, but any of these is true:
   - `findings` is non-empty
   - a conflict isn't `confident`
   - `range.rewritten` is true
   - `range.fork_has_merges` is true
   - `range.first_run` is true (a first review always goes to the user)
   - `range.fork_behind_recorded_head` is true
   - `range.moved_tags` isn't `[]`
   - `range.deleted_tags` isn't `[]`

   Boolean flags must be literally `false`: a missing flag or `null` blocks
   `clean`.

## What the promotion side adds (#598, not enforced here)

- **Don't trust the agent's `range`.** The scheduler runs
  `scripts/review-range.sh` itself, on the same fetched refs and before the
  agent starts, and passes that output to the validator with `--range`. The
  agent could have been manipulated into reporting `rewritten: false` or
  empty tag lists.
- Promotion needs this validator to pass with both `--candidate-head` (the
  pushed `sync/*` head) and `--range`. On top of that, the scheduler's own
  deterministic tripwires on the diff must find nothing.
- Delete `$OUT/verdict.json` before invoking the agent, so a crashed run
  can't leave an old verdict behind.
- Update `refs/fork-keeper/upstream-head` and the tag mirror only _after_ the
  force-push of the default branch succeeds.
- A `needs-review` PR stays that way until the user labels it
  `fork-keeper:approved` on the current head SHA.
