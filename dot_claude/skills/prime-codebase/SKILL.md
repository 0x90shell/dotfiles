---
name: prime-codebase
description: Build or refresh a structural map of a codebase before planning or editing it. Use when the user says "/prime-codebase", "get oriented", "map this codebase", "how is this organised", when starting work on an unfamiliar or very large file, or when you catch yourself grepping for the same structure you looked up last session.
argument-hint: "[path] (blank = current project)"
---

Produce a map of the code, once, and write it down so the next session does not
rebuild it.

The cost this removes is real: without a map, every session rediscovers the same
structure by grep, and pays for it in tokens and in wrong first guesses about
where things live.

## Step 0: is there already a map?

Look for a `## Map` or `## Architecture` section in the project `CLAUDE.md`, or a
`CODEMAP.md`. If one exists, **read it and check it is still true** rather than
starting over. Verifying an existing map is far cheaper than rebuilding it.

Staleness check: pick five named things from the map (a function, a path, a
command, a config key, a tier name) and confirm each still exists. If any is gone,
the map is stale. Say which, and refresh only the affected part.

If the map is current, say so and stop. That is a successful run.

## Step 1: classify the shape

The extraction method depends on the shape, not the language. Decide which this is:

- **Monolithic script.** One file of thousands of lines with internal sections.
  The map is a function index and a dispatch table.
- **Module tree.** Many files with imports between them. The map is the dependency
  direction and the entry points.
- **Script collection.** Many files with few or no imports between them. The map is
  one line per file saying what it does. There is no graph to draw, and pretending
  otherwise wastes effort.
- **Service or app.** Entry point, routing, data layer, config.

Check before assuming. Counting cross-file imports takes one command and decides
between the second and third shapes, which need completely different maps.

## Step 2: extract structurally, not by reading

Use commands that emit structure. Do not read whole files hoping to absorb them:
that is the expensive habit this skill exists to replace.

`references/extraction.md` has the per-shape command recipes.

Rules for this step:

- Work from definitions, dispatch tables, and naming conventions. In most
  codebases the naming convention carries more information than any single file.
- Note where the **entry point** is and how arguments reach the work.
- Note the **test layout**: where tests live, how they are invoked, how they map to
  the code. This is the part most often missing and most often needed.
- Record **counts and line numbers**, not impressions. "phase_* functions, 11 of
  them, lines 4400-9800" is usable. "well structured" is not.

## Step 3: write the map down

Put it in the project `CLAUDE.md` under `## Map`, or in `CODEMAP.md` if it is long
enough to be its own document. It belongs in version control so it is reviewable
in a diff and so it travels with the code.

Keep it to what cannot be re-derived in one command. A list of every function is
not a map; `grep -n '^[a-z_]*()' file` regenerates that in a second. The map holds
the things grep cannot tell you: what the groups mean, which order they run in,
where the boundaries are, and which parts are dead or deprecated.

Include:

- Entry point and dispatch.
- The naming conventions, stated explicitly, with an example of each.
- Groups of units and what each group is for, with line ranges.
- Test layout and how tests map to code.
- Anything deprecated or superseded, so nobody reads it as current.

## Step 4: report

Give the path to the map and a five-line summary. Do not paste the whole map into
the conversation; it now lives in a file, which was the point.

## Scope

This builds a map. It does not review, refactor or fix anything. If you notice a
bug while mapping, note it in the report and leave it alone.
