---
name: investigate
description: Trace a bug to root cause without fixing it yet. Use when the user says "/investigate", "why is this happening", "trace this", "find the root cause", "dig into", or reports a failure whose cause is not obvious.
argument-hint: "[what is broken] (blank = the failure just reported)"
---

Find the cause. Do not fix it in the same pass.

Inline fixes during investigation inject bugs upstream, because a fix written
mid-trace has not considered the whole vertical of the change. Investigate first,
then plan the fixes together.

The one exception is a fix that is one line, obvious, and carries no upstream
risk. If you have to think about whether it qualifies, it does not.

## Procedure

**1. Check the simplest explanation first.** If the user suggested where to look,
look there first, before forming your own theory.

**2. State hypotheses before testing.** Write 2 to 4 candidate causes ranked by
likelihood, each with the evidence that suggests it. Ranking them first stops you
finding the first plausible thing and stopping.

**3. Design a test per hypothesis that can kill it.** A test that only confirms is
not a test. Say what result would rule each one out.

**4. Run the targeted tests.** Independent hypotheses can be investigated in
parallel. Do not read whole files hoping something jumps out.

**5. Stop after three failed checks.** If three targeted tests have not found it,
stop and summarise what has been ruled out. Ask before opening the search wider.
Extended wandering is how a session gets tainted.

## Output

Write findings to a file, not into the chat, and give the user the path.

    # <symptom>

    ## Symptom
    Exactly what was observed, with the command and the output.

    ## Root cause
    One paragraph. Every claim cites file:line.

    ## Evidence
    What was tested, what each test showed, and how each ruled a hypothesis in
    or out.

    ## Ruled out
    The hypotheses that died, and what killed them. Keep these: they stop the
    next person re-running the same tests.

    ## Not established
    What is still assumption. Be explicit. A confident-sounding root cause that
    was never actually confirmed is worse than an open question.

    ## Proposed fixes
    Numbered, each naming the file and what changes. No code written yet.

## Gate

Post the findings path and the proposed fix list. Then stop. Do not begin
implementing until the user has read it and said go.
