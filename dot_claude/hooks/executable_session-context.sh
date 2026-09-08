#!/usr/bin/env bash
# SessionStart: inject the repository's current state.
#
# Only useful now that the working projects are in git. Saves the first two or
# three orientation commands of every session, and makes uncommitted work visible
# before anything starts editing on top of it.
set -uo pipefail

jq=$(command -v jq) || exit 0
git=$(command -v git) || exit 0

payload=$(cat)
cwd=$("$jq" -r '.cwd // ""' <<<"$payload")
[[ -n $cwd ]] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0
"$git" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$("$git" symbolic-ref --short HEAD 2>/dev/null || echo "detached")
dirty=$("$git" status --porcelain 2>/dev/null | wc -l)
recent=$("$git" log --oneline -5 2>/dev/null)
remote=$("$git" remote 2>/dev/null | head -1)

ctx="Repository state (from SessionStart hook):
  branch: $branch
  uncommitted files: $dirty"

if [[ $dirty -gt 0 ]]; then
    ctx="$ctx
$("$git" status --porcelain 2>/dev/null | head -12 | while IFS= read -r l; do printf '    %s\n' "$l"; done)"
fi

if [[ -z $remote ]]; then
    ctx="$ctx
  remote: none (this repo is local-only; a pre-push hook refuses pushes)"
fi

ctx="$ctx

  recent commits:
    ${recent//$'\n'/$'\n'    }"

# shellcheck disable=SC2016  # single quotes are jq syntax, not shell
"$jq" -n --arg c "$ctx" '{
    hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: $c
    }
}'
exit 0
