---
name: notes-audit
description: Find claims in notes, memories and planning docs that have quietly stopped being true. Use when the user says "/notes-audit", "audit my notes", "is this still accurate", "check the memories", or when a document contradicts what the code actually does.
argument-hint: "[path or glob] (blank = this project's docs and memories)"
---

Notes rot silently. A stale note is worse than a missing one, because it is
trusted and acted on.

## What to check

- `*-PLAN.md`, `*-TODO.md`, findings and report files in the project.
- Claude memory files under `~/.claude/projects/<key>/memory/`.
- `CLAUDE.md` at every level.
- Any README or notes file the project keeps by hand.

## Method

For each factual claim, decide which it is and verify accordingly.

**Claims about code**: check the file, function or line still exists and still
behaves that way. A named function that is gone is a definite hit.

**Claims about state** ("root cause untraced", "still needs migration"): check
whether the state changed. This is the biggest source of stale notes, because
someone fixes the thing and never returns to the note.

**Claims about commands and paths**: run or stat them.

**Frontmatter versus body**: a memory whose `description` contradicts its own body
is stale by definition. That mismatch is a reliable tell and cheap to scan for.

**Duplicates**: the same fact in two places will diverge. Note which copy should
be canonical.

**Superseded by enforcement**: a note describing a rule that is now enforced by a
hook or a test is redundant, and worse, it will drift out of step with the thing
that actually enforces it.

## Report

Group as: **Wrong** (contradicted by the code), **Stale** (was true, no longer),
**Unverifiable** (no way to check), **Duplicated** (say which wins), **Redundant**
(now enforced elsewhere).

Every entry cites the note location and the evidence that contradicts it.

## Gate

Post the report. Do not edit or delete any note until the user has decided. A note
that looks stale is sometimes a deliberate record of history, and only the user
knows which.
