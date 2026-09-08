---
name: rules-drift
description: Audit CLAUDE.md files, skills and hooks for rules that no longer match reality. Use when the user says "/rules-drift", "check my rules", "is my CLAUDE.md still accurate", "audit the skills", or after a large refactor moved things around.
---

Rules rot for the same reason they work: they are specific. A rule naming a path,
a command or a file is exactly the rule that breaks when the code moves.

A wrong rule is worse than no rule. The agent tries to reconcile the instruction
with a codebase that disagrees with it, and the result is confident wrong work.

## Scope

Global `~/.claude/CLAUDE.md`, every project `CLAUDE.md`, every
`~/.claude/skills/*/SKILL.md` and its references, every hook in
`~/.claude/hooks/`, and the hook wiring in `settings.json`.

## Checks

**Does the referenced thing exist?** Every path, script, function, command,
directory and host named in a rule. This finds most drift on its own.

**Does the rule still describe the behaviour?** A rule can name a real file and
still be wrong about what it does.

**Is the rule superseded by a hook?** If a hook now enforces it, the prose is
duplication that will drift out of step with the enforcement. The hook is the
source of truth; the prose should point at it or go.

**Do two rules contradict each other?** Across global and project files, and
between a rule and a hook. Contradictions are worse than staleness because the
agent picks one silently.

**Is a hook wired?** A hook file with no matching entry in `settings.json` is
worse than no hook: it reads as covered and does nothing. Check both directions,
including hooks wired to a path that no longer exists.

**Is a skill still portable?** A skill naming a specific project, script or
domain convention has leaked project knowledge and belongs in that project's
CLAUDE.md instead. Check with a grep for project-specific terms across
`~/.claude/skills/`.

**Is a rule generic filler?** Rules restating things the model does anyway
("write clear code", "follow best practices") are pure token cost now. Flag them
for deletion.

## Report

For each finding: where the rule lives, what it claims, what is actually true, and
the recommendation (fix, delete, move to a project file, or convert to a hook).

Separate **certain** from **suspected**. A rule you could not verify is not the
same as a rule you proved wrong, and saying so is the difference between a useful
audit and a destructive one.

## Gate

Post the report and stop. Deleting a rule that turns out to be load-bearing is
expensive and not obviously reversible.
