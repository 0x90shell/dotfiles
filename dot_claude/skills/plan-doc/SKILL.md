---
name: plan-doc
description: Write a durable plan document for a multi-step change. Use when the user says "/plan-doc", "write a plan", "plan this out", "make a plan doc", or when starting a refactor, migration or remediation big enough to span sessions.
argument-hint: "[topic] (blank = the work just discussed)"
---

Write a plan that survives the session that produced it.

Filename is a kebab-case slug of the topic plus `-PLAN.md`, never a bare
`PLAN.md`. A second plan must never clobber the first.

## Never invent requirements

Anything you do not know becomes a literal `TBD, needs validation` line. Not a
plausible-sounding guess. A confident invented requirement is the most expensive
thing a plan document can contain, because nobody rechecks the parts that read
as settled.

## Design the validation before the change

This section is mandatory and comes before the implementation steps, not after.
Testing added at the end is testing that shapes itself around whatever got built.

State:

- Which existing test tier or suite covers this area, by name.
- What new cases are needed, and their tag or ID scheme if the project uses one.
- The exact command that proves the change works.
- The edge cases worth attacking.
- What "still broken" would look like, so a partial fix is not mistaken for a fix.

If the project has no test for the area, say so explicitly. That is a finding.

## Shape

    # <Topic>

    ## Context
    Why this is being done, what prompted it, what the outcome should be.

    ## Current state
    What is true now, with evidence. Measurements, not impressions.

    ## Outcome
    We are right if: <observable signal>
    We are wrong if: <observable counter-signal>

    Both lines are required. The second is the one people skip, and the one
    that makes the plan falsifiable rather than merely optimistic.

    ## Validation
    (as above, before the steps)

    ## Steps
    Numbered. Each names the files it touches and how it is verified.

    ## Risks and unknowns
    Including every TBD.

## Keep intent and engineering separate

The Context and Outcome sections say what must be true and why. They do not pick
the implementation. If a "why" section is naming data structures, the decision has
been smuggled in before it was examined.

## Gate

Write the file, give the user the path, summarise the outcome lines and the open
TBDs. Then stop. Do not start implementing.
