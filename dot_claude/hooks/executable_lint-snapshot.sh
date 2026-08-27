#!/usr/bin/env bash
# PreToolUse hook: stash a before-image of a lintable file about to be changed.
#
# Paired with lint-after-edit.sh, which diffs against this to report only the
# findings on lines actually touched. rom-cleanup is not a git repo, so there is
# no cheaper before-image available.
#
# Always exits 0: this must never block an edit.
set -uo pipefail

payload=$(cat)

file=$(jq -r '.tool_input.file_path // ""' <<<"$payload")
[[ -n $file && -f $file ]] || exit 0

case $file in
    *.sh | *.bash | *.py | *.go) ;;
    *) exit 0 ;;
esac

snapdir="/tmp/claude-lint-snap-$(id -u)"
mkdir -p "$snapdir" || exit 0
cp -f "$file" "$snapdir/$(printf '%s' "$file" | md5sum | cut -d' ' -f1)" 2>/dev/null

exit 0
