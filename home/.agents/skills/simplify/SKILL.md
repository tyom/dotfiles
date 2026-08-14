---
name: simplify
description: Reviews changed code for reuse, simplification, efficiency and altitude, then applies the fixes. Quality, not correctness bugs.
disable-model-invocation: true
---

# Simplify

`simplify → 4 angles, one review each → apply the fixes`

Scope is the quality of the changed code: reuse, simplification, efficiency,
altitude. Correctness bugs belong to a code review.

## Phase 0 — Scope the diff

Write the diff under review somewhere a reviewer can read it:

```bash
git diff @{upstream}...HEAD > "$(git rev-parse --path-format=absolute --git-dir)/simplify.patch"
```

Use `main...HEAD`, then `HEAD~1`, when there is no upstream. Append
`git diff HEAD` when the working tree is dirty or the range came back empty:
this usually runs before the commit, so the uncommitted work is the point. An
argument (PR number, branch, path) replaces the range.

## Phase 1 — Review

Review the patch against every angle below. Each angle gets its own verdict.

A finding is `file`, `line`, a one-line `summary`, and the concrete cost: what
is duplicated, wasted, or made harder to maintain.

### Reuse

New code that re-implements what the codebase already has. Grep shared utility
modules and the files next to the change, and name the existing helper to call
instead.

### Simplification

Complexity the diff adds: redundant or derivable state, copy-paste with a small
variation, deep nesting, dead code left behind. Name the simpler form that does
the same job.

### Efficiency

Wasted work the diff introduces: recomputation, repeated I/O, independent
operations run in sequence, blocking work added to startup or a hot path. Also
long-lived objects built from closures, which hold the whole enclosing scope
alive for the object's lifetime: prefer a struct that copies the fields it
needs.

### Altitude

Whether each change sits at the right depth. A special case layered onto shared
infrastructure is a bandaid: generalise the underlying mechanism instead.

### Running the four

Delegate one angle per agent when this runtime spawns agents. Give each the
patch path and its single angle, and have it report findings and edit nothing.

On Codex this needs `features.multi_agent_v2`. Spawn four in one batch with
`task_name` per angle and `fork_turns: "none"`, so a reviewer reads the patch
rather than inheriting the session. Then loop `wait_agent` over the outstanding
ids and `close_agent` each finisher: `wait_agent` returns whichever agent
finishes first, and a completed agent holds its concurrency slot until closed.

Otherwise work through all four angles yourself in one pass, and say so in the
closing summary so nobody reads it as four independent reviews.

Phase 1 ends when all four angles have reported.

## Phase 2 — Apply

Dedup findings that point at the same line or mechanism, then fix what is left.

Skip a finding when the fix would change intended behaviour, reach well outside
the diff, or you judge it a false positive. Name the skip rather than arguing
with it.

Phase 2 ends when every finding is either fixed or named as a skip. Close with
what was fixed and what was skipped, or confirm the diff was already clean.
