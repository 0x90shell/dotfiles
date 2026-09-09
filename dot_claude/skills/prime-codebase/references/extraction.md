# Extraction recipes by shape

Commands that emit structure. None of these read a file into context whole.

## First: decide the shape

    # size and language mix
    git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head
    git ls-files '*.py' '*.sh' '*.go' '*.ts' | tr '\n' '\0' | xargs -0 wc -l | sort -rn | head

    # module tree or script collection? count LOCAL cross-imports only
    git ls-files '*.py' | tr '\n' '\0' | xargs -0 grep -h '^from \|^import ' \
      | grep -vE '^\s*(from|import) (os|sys|re|json|argparse|subprocess|shutil|pathlib|collections|typing|itertools|dataclasses|functools|logging|datetime|math|hashlib|csv|time|glob|tempfile)' \
      | sort -u

Few or no local cross-imports means script collection, not module tree. Do not
build a dependency graph for something that has no dependencies.

## Monolithic script (bash)

    f=path/to/script.sh
    wc -l "$f"

    # every function definition with its line number
    grep -nE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$f"

    # group by naming prefix: this is usually the real architecture
    grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$f" | sed 's/_.*//' | sort | uniq -c | sort -rn

    # second-level grouping inside a prefix
    grep -oE '^phase_[a-z_]*\(\)' "$f" | sort

    # the dispatch table: how an argument becomes work
    grep -nE '^\s*(case|[a-z-]+\))' "$f" | head -40
    grep -n 'Usage:' "$f"

    # section banners, if the author used them
    grep -nE '^# =+|^# -+ ' "$f" | head -40

    # globals and config surface
    grep -nE '^[A-Z_]+=' "$f" | head -40

Line ranges per group: take the first and last line number of each prefix from the
function index. That gives "organize_step_*, 34 functions, lines 6900-12400".

## Monolithic script (python)

    grep -nE '^(def|class) ' file.py
    grep -nE '^\s{4}def ' file.py | head -40    # methods
    grep -n 'argparse\|add_argument\|sub_parser' file.py

## Module tree

    # entry points
    git ls-files | grep -iE '(main|__main__|index|cli|app)\.(py|ts|js|go)$'
    grep -rln 'if __name__' --include='*.py' .

    # dependency direction, local imports only
    for f in $(git ls-files '*.py'); do
      printf '%s -> ' "$f"
      grep -hoE '^from [a-z_.]+ import|^import [a-z_.]+' "$f" | sort -u | tr '\n' ' '
      echo
    done

    # fan-in: which modules everyone depends on
    git ls-files '*.py' | xargs -I{} basename {} .py | while read -r m; do
      printf '%4s %s\n' "$(git grep -c "import $m" -- '*.py' | wc -l)" "$m"
    done | sort -rn | head

## Script collection

One line per file. Read only the top of each: the docstring or header comment and
the argparse setup usually say what it does.

    for f in $(git ls-files '*.py'); do
      printf '%-40s %s\n' "$f" "$(head -20 "$f" | grep -m1 -E '^\s*(#|\"\"\")' | cut -c1-70)"
    done

## Tests, whatever the shape

    # standalone test files
    git ls-files | grep -iE '(^|/)(test_|.*_test\.|tests?/)'

    # tests embedded in the code (common in single-file tools)
    grep -nE '^(run_tests|test_|.*_tests)[a-z_]*\(\)' path/to/script.sh
    grep -oE '"[A-Z]{1,3}[0-9]{1,4}:' path/to/script.sh | sort -u | sed 's/.//' | head

    # how they are invoked
    grep -rn 'test' Makefile justfile package.json pyproject.toml 2>/dev/null | head

Embedded tests matter: a tool with no `tests/` directory may still have a full
suite inside the file under test. Check before concluding there are no tests.

## Deprecated and dead code

    # files the entry point never reaches
    git log -1 --format=%cr -- path/to/file      # last touched
    grep -rn 'deprecated\|DEPRECATED\|superseded\|do not use' --include='*.sh' --include='*.py' . | head
