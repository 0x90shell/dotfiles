---
name: shell-hardening
description: Write or fix bash that will not break on the usual traps. Use when writing or editing a .sh file, debugging a shell script that fails oddly, seeing SIGPIPE, IFS, set -e or quoting bugs, or when the user says "/shell-hardening" or pastes a broken shell one-liner.
---

## Write a file, not a one-liner

Non-trivial logic goes in a `.sh` file that gets `shellcheck`ed, not into an inline
heredoc or a chained sed/awk pipeline. Inline shell has produced repeated broken
first attempts here: quoting errors, over-eager regex substitutions, and heredocs
that swallow their own delimiters.

Run `shellcheck` before saying it works. Not after the user reports it does not.

## Traps that have actually bitten

**`set -e` and a trailing test.** A function whose last statement is `[[ ... ]]`
returns non-zero when the test is false, which under `set -e` kills the script.
End such functions with `return 0` or `|| true`.

**Character classes containing brackets or parens.** `[(\[]` does not work as a
bash regex character class. Use alternation: `(\(|\[)`. This one recurs.

**`tr` and hex escapes.** `'\x00'` in single quotes is literal. Use double quotes.

**SIGPIPE.** `find ... | head -1` under `set -euo pipefail` fails when `head`
closes the pipe. Use `find -quit`, or process substitution.

**IFS on tab-delimited data.** Set `IFS=$'\t'` explicitly when reading TSV in a
function, or leading and trailing fields get mangled.

**Apostrophes in filenames.** Game and film titles contain them. They break `eval`
and every unquoted expansion. Quote every expansion; prefer arrays over strings.

**`grep -c` counts lines, not matches.** For occurrences use `grep -o ... | wc -l`.

**`local` masks exit status.** `local x=$(cmd)` always succeeds. Declare first,
assign second, if you need the status.

**Unresolved variables in destructive commands.** `rm -rf "$dir"` where `$dir` is
empty is a live hazard, and the destructive guard will refuse it. Use explicit
paths, or test the variable first.

## Defaults

    set -euo pipefail

Quote every expansion. Use `[[ ]]` over `[ ]`. Prefer arrays for argument lists.
Give long-running scripts a progress indicator; they get run on large trees.
Comment the non-obvious logic and nothing else.
