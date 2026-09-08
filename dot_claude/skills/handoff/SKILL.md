---
name: handoff
description: Write a resumable handoff document and start a fresh session. Use when the user says "/handoff", "start fresh", "new session", "this conversation is a mess", when context is running low, or after three failed attempts at the same problem.
argument-hint: "[output path] (blank = ./HANDOFF.md)"
---

Write a document that lets a new session continue without this one.

## When to reach for this

**Context is running out.** A compaction keeps roughly a tenth of the specific
detail, and you do not control which tenth. A handoff you write deliberately is
the same idea with the selection under your control.

**The conversation has gone bad.** After three failed corrections on one problem,
stop. A context full of mistakes and corrections makes the next token more likely
to be another mistake, and escalating to a larger model mid-conversation recovers
less than half the gap because the bad context carries over. Write the handoff and
abandon the session. Do not attempt a fourth fix.

## What goes in

    # Handoff: <one line on the goal>

    ## State
    What is done. Name files and commits, not intentions.

    ## In progress
    The exact thing being worked on, and how far it got.

    ## Next command
    The literal command or edit to run first. Not a description of it.

    ## Ruled out
    What was tried and did not work, with the reason. This is the part that
    saves the next session from repeating this one, and the part most often
    left out.

    ## Open questions
    Decisions that need the user, stated so they can be answered without
    reading the transcript.

    ## Environment
    Branch, dirty files, anything half-applied, anything left running.

## Rules

Facts, not narrative. "The dedup tier passes, 368 asserts, 24s" beats "tests seem
mostly fine".

Every claim needs a path, a command or a number. The next session cannot ask you
what you meant.

State what you did not check. An unchecked assumption presented as fact is the
most expensive thing you can hand over.

Do not include the reasoning that got you here, only the conclusions and the
evidence for them. The next session does not need the journey.
