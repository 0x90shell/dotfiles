---
name: instruction-authoring
description: Write or refactor a CLAUDE.md, skill, hook or agent prompt. Use when the user says "/instruction-authoring", "add a rule", "write a skill", "turn this into a skill", "update CLAUDE.md", "make a hook for this", or asks why an instruction keeps being ignored.
argument-hint: "[claude-md | skill <name> | hook <what it guards>] (blank = ask)"
---

<!-- slop-check: ignore -->

Instructions for an agent are not documentation for a human. A human reads "keep
the database code organised sensibly" and applies judgment. An agent needs "all
SQL lives in db/". The job is to remove assumptions, not to read well.

## First: does this belong in an instruction at all?

Ask in order. Stop at the first yes.

1. **Can a hook enforce it deterministically?** Then it is a hook. A rule asks; a
   hook guarantees. Anything phrased as "always", "never", "before X do Y", or
   naming a specific event or ordering, is a hook in disguise.
2. **Is it about how output looks?** Then it is the output style. That goes into
   the core system prompt and is re-injected during the session. CLAUDE.md loads
   once at the top and decays under context pressure.
3. **Does it apply to only one kind of task?** Then it is a skill, loaded on
   demand. Its always-on cost is only its description.
4. **True in every session and not enforceable?** Only then, CLAUDE.md.

## The Rule of Three

Do not create a rule or skill for something that has happened once. Wait for the
third time the user asks for the same thing, and name the three occasions before
adding it. If you cannot name three, propose it and let the user decide.

## Format

Imperative lines, not prose paragraphs.

    NEVER add Co-Authored-By to a commit.
    VERIFY the tier map before running a partial suite.
    IF a memory contradicts a CLAUDE.md THEN the CLAUDE.md wins.

Be specific about **facts the model cannot infer**: paths, commands, tier names,
exit codes, host names. Be general about **judgment the model is already good at**:
code style, naming, comment density. Anthropic removed most of the rigid style
rules from Claude Code's own system prompt with no measured loss, so a rule saying
"write clear code" is pure cost.

Every specific fact has an expiry date. That is the trade: facts are what the
agent needs and what rots first. Anything added here becomes work for the drift
audit later, so it has to earn that.

## Size

CLAUDE.md under 200 lines. Growth usually means bad allocation, not too much
knowledge: rules that should be hooks, or task-specific rules that should be
skills.

## Skills

Layout is `~/.claude/skills/<name>/SKILL.md`, plus optional `references/*.md`
loaded on demand, `scripts/*` that are run and never read into context, and
`templates/*`.

Frontmatter is `name` plus a trigger-dense `description` listing the phrases that
should fire it, plus `argument-hint` if it takes input. The description is the
entire always-on cost: specific enough to fire, short enough to be free.

Body under about 2,000 words. Anything longer goes to `references/`.

**A skill encodes a method and must port to any project.** If it names a specific
script, host or domain convention, that belongs in a project CLAUDE.md instead.
The exception is a skill that ships as a template with `# REPLACE:` placeholders
and says so in a banner at the top.

Workflow skills end each phase with an explicit GATE: state what to post, then
stop. That is what stops work starting before the user approved the plan.

## Hooks

Read `references/hook-mechanics.md` before writing one. The exit code semantics run
backwards from every other CLI and cost an afternoon if guessed.

Never ship a hook you have only read. Feed it a real payload on stdin and check
both the allow and the deny path. Then break it on purpose and confirm it fails,
because a check that cannot fail is worthless.
