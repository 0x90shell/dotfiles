---
name: output-audit
description: Diff a pipeline's output tree against a previous run and classify what changed as expected or a regression. Use when the user says "/output-audit", "audit the run", "what changed", "compare snapshots", "check for regressions", or after a batch job that rewrites a large tree.
argument-hint: "[before-snapshot] [after-snapshot] (blank = the two most recent)"
---

> **This skill is a template.** It owns the method. The project owns the run
> command, the snapshot shape and its own regression categories. Read the
> project's `.claude/audit.conf` or its `CLAUDE.md` before starting. If neither
> exists, ask for those three things rather than guessing them.

A program rewrote a large file tree. The question is what changed and whether any
of it is wrong. That question is the same whether the tree holds ROMs, encoded
video or generated documents, so nothing here should name a specific project.

## Procedure

**1. Snapshot before.** A snapshot is whatever the project defines: a `find`
manifest with sizes and hashes, a report file, a generated XML. Never overwrite
the previous snapshot; keep them numbered or dated so a bad run can be compared
against two good ones.

**2. Run.** Use the project's command. Prefer its dry-run mode first if it has one.

**3. Snapshot after.**

**4. Diff and group.** Raw diffs on large trees are unreadable. Group by the
change's shape: added, removed, renamed, moved between directories, content
changed at the same path. Report counts per group before any detail.

**5. Classify every group.** Three buckets, and every group lands in exactly one:

- **Expected**: follows directly from the change that was made.
- **Regression**: contradicts a stated rule or a previous decision.
- **Unknown**: cannot be explained yet.

**Unknown is not a polite word for expected.** Anything you cannot account for
stays Unknown and gets listed. Quietly filing it under Expected is the failure
mode this whole procedure exists to prevent.

**6. Trace each regression to `file:line`.** A regression without a cause is a
symptom report. Follow it to the code that produced it.

**7. Write a numbered fix plan.** Each entry names the file, the cause and the
change. No code yet.

## Scale

These diffs are large. Report counts and representative examples, not every path.
Ten lines showing the shape of a 4,000-item group beats 4,000 lines. Write the
full list to a file and give the path.

## Gate

Post the classification summary, the regression list with causes, and the fix plan.
Then stop. Do not implement, and do not re-run the pipeline to "check", because a
second run changes the state you are auditing.
