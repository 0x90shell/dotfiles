---
name: quick
description: Cut the last answer down to the N most important points. Use when the user says "/quick", "/quick 3", "just the highlights", "top 3", "tl;dr", "bottom line", or asks for the short version of something you just wrote.
argument-hint: "[N] (blank = 3)"
---

Reduce what you just said to its most important points.

## How many

`$ARGUMENTS` is a number. With no number, give 3.

## Rules

Rank by consequence, not by the order you happened to write them. The point that
changes what the user does next goes first.

One line each. A line is one sentence, not a sentence plus a parenthetical plus a
caveat.

Keep the numbers. "Aborts at INV1, so 14 invariants never run" earns its place;
"there are some test issues" does not. Specifics are what make a short answer
useful rather than merely short.

No preamble and no closing line. Start at point 1, stop after point N.

If something important genuinely does not fit in N points, say so in one final
line beginning "Not covered:" and name it. Do not silently drop it, and do not
quietly exceed N instead.
