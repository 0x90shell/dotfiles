---
name: review-changes
description: Review uncommitted changes or a diff before committing. Use when the user says "/review-changes", "review this", "check my changes", "look over the diff", or before a commit on work that took more than one session.
argument-hint: "[git ref or path] (blank = uncommitted changes)"
---

Review a diff with fresh eyes.

## Run this in a new session

The value here is the absence of the assumptions that produced the code. An agent
reviewing work it just wrote will approve it, because it cannot see its own
premises. If this session wrote the code, say so and recommend the user run the
review in a fresh session with only the diff as input.

## What to look at

Start from `git diff` (or the named ref). Read the diff, then read enough
surrounding code to know whether each change is correct in context. A diff read
in isolation hides the thing it broke.

## Priority

**1. Correctness.** Does it do what it claims? Off-by-one, inverted conditions,
unhandled error paths, changed behaviour at boundaries.

**2. Did a test stop testing anything?** When a change touches both a test and the
code that test covers, look hard. That is the shape in which coverage silently
disappears. Same for a weakened assertion or a test that now asserts the new
behaviour without anyone deciding the new behaviour is right.

**3. Consistency with the project's own rules.** Check the project CLAUDE.md.
A change that violates a documented convention is either a bug or a decision that
should be recorded.

**4. Scope.** Changes that nobody asked for. An unrelated rename or reformat
buried in a functional diff is a review problem even when each line is fine.

**5. Reuse.** New code duplicating something that already exists in the project.

## What not to say

No style opinions the project has not asked for. No praise. No summary of what the
diff does; the user can read it. If nothing is wrong, say nothing is wrong in one
line and stop.

## Output

Findings ranked by severity, each with `file:line`, what breaks, and the concrete
input or state that triggers it. A finding you cannot describe a failure for is a
hunch, and should be labelled as one or dropped.
