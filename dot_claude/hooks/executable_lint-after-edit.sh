#!/usr/bin/env bash
# PostToolUse hook: lint a file after Claude writes or edits it, reporting only
# findings on lines this edit actually touched.
#
# Wired with asyncRewake, so this runs in the background and never blocks the
# edit. Exit 2 wakes the model with the findings on stderr; exit 0 is silent.
# That matters because shellcheck on a 24k-line pipeline.sh takes ~53s, which
# would be intolerable as a synchronous hook.
#
# Python runs ruff AND flake8: ruff is the eventual replacement, but flake8 still
# carries plugin checks ruff has not reimplemented. Drop flake8 here once that
# gap closes.
set -uo pipefail

payload=$(cat)

file=$(jq -r '.tool_response.filePath // .tool_input.file_path // ""' <<<"$payload")
[[ -n $file && -f $file ]] || exit 0

case $file in
    *.sh | *.bash) linters=(shellcheck) ;;
    *.py) linters=(ruff flake8) ;;
    *.go) linters=(golangci-lint) ;;
    *) exit 0 ;;
esac

key=$(printf '%s' "$file" | md5sum | cut -d' ' -f1)

# Repeated edits to one file would otherwise stack multi-minute shellcheck runs.
# Skip if a check for this file is already in flight; the next edit re-triggers.
lockdir="/tmp/claude-lint-hook-$(id -u)"
mkdir -p "$lockdir"
exec 9>"$lockdir/$key.lock"
flock -n 9 || exit 0

# Resolve changed lines BEFORE the slow lint run, to narrow the window in which a
# following edit could overwrite the snapshot out from under us.
snap="/tmp/claude-lint-snap-$(id -u)/$key"
changed=$(mktemp) || exit 0
trap 'rm -f "$changed"' EXIT

scope="changed lines"
if [[ -f $snap ]]; then
    # Emits the new-file line number of every added or modified line.
    diff --unchanged-line-format= --old-line-format= --new-line-format=$'%dn\n' \
        "$snap" "$file" >"$changed" 2>/dev/null
else
    # No before-image means a newly created file: everything in it is new.
    scope="whole file (new)"
fi

# All four linters are asked for a one-finding-per-line "path:line:col:" format so
# a single filter works across them.
# flake8 7 dropped user-level config discovery, so ~/.config/flake8 is inert on
# its own. Supply it explicitly, but only when the project defines no config of
# its own, so a project standard still wins. This mirrors how ruff already
# resolves ~/.config/ruff/ruff.toml against a project ruff.toml.
flake8_config_args() {
    local dir
    dir=$(cd "$(dirname "$file")" && pwd) || return 0

    while [[ $dir != / ]]; do
        if [[ -f $dir/.flake8 || -f $dir/setup.cfg || -f $dir/tox.ini ]]; then
            return 0
        fi
        dir=$(dirname "$dir")
    done

    [[ -f $HOME/.config/flake8 ]] && printf -- '--config=%s' "$HOME/.config/flake8"
    return 0
}

run_linter() {
    case $1 in
        shellcheck) shellcheck -f gcc "$file" 2>&1 ;;
        ruff) ruff check --no-cache --output-format=concise "$file" 2>&1 ;;
        flake8)
            local cfg
            cfg=$(flake8_config_args)
            # shellcheck disable=SC2086  # cfg is one optional flag or empty
            flake8 $cfg "$file" 2>&1
            ;;
        # golangci-lint works on packages, not single files.
        golangci-lint) (cd "$(dirname "$file")" && golangci-lint run 2>&1) ;;
    esac
}

# Keep only findings whose basename matches this file and whose line was touched.
# The basename test matters for golangci-lint, which reports the whole package.
filter_to_changed() {
    awk -F: -v lf="$changed" -v want="${file##*/}" '
        BEGIN { while ((getline l < lf) > 0) if (l ~ /^[0-9]+$/) touched[l] = 1 }
        /^[^:]+:[0-9]+:/ {
            n = split($1, seg, "/")
            if (seg[n] == want && ($2 in touched)) print
        }
    '
}

report=""
failed=0

for linter in "${linters[@]}"; do
    command -v "$linter" >/dev/null 2>&1 || continue

    # Dispatch on exit status, not on output: ruff prints "All checks passed!"
    # on success, so a non-empty-output test would report a false failure.
    if out=$(run_linter "$linter"); then
        continue
    fi

    if [[ -f $snap ]]; then
        out=$(printf '%s\n' "$out" | filter_to_changed)
    fi

    # Every finding may have been pre-existing, leaving nothing to report.
    [[ -n $out ]] || continue

    failed=1
    report="${report}
--- ${linter} ---
${out}
"
done

[[ $failed -eq 0 ]] && exit 0

# Exit 2 is the blocking-error code; with asyncRewake it re-wakes the model and
# appends this stderr text to the rewake message.
{
    printf 'Lint issues in %s (%s):\n' "$file" "$scope"
    printf '%s\n' "$report"
} >&2
exit 2
