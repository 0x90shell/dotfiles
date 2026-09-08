#!/usr/bin/env bash
# Stop: refuse to call the work done while the project's tests are red.
#
# Opt-in per project. Reads the command from .claude/test-command; with no such
# file this hook exits silently and costs nothing. That matters because Claude
# Code stops honouring a Stop hook after 8 consecutive blocks, so a gate that can
# never go green burns a session rather than protecting it.
#
# Keep the configured command FAST. It runs at every turn end. Anything over a
# few seconds belongs in a manual run, not here.
set -uo pipefail

jq=$(command -v jq) || exit 0
payload=$(cat)

# Re-entrancy: if we already blocked and the model is stopping again after
# working on it, do not stack another run on top.
[[ $("$jq" -r '.stop_hook_active // false' <<<"$payload") == "true" ]] && exit 0

cwd=$("$jq" -r '.cwd // ""' <<<"$payload"); [[ -n $cwd ]] || cwd=$PWD
conf="$cwd/.claude/test-command"
[[ -f $conf ]] || exit 0

cmd=$(grep -vE '^\s*(#|$)' "$conf" | head -1)
[[ -n $cmd ]] || exit 0

[[ ${CLAUDE_GUARD_OFF:-} == 1 ]] && exit 0

timeout_s=${CLAUDE_TEST_TIMEOUT:-120}
out=$(cd "$cwd" && timeout "$timeout_s" bash -c "$cmd" 2>&1)
rc=$?

[[ $rc -eq 0 ]] && exit 0

if [[ $rc -eq 124 ]]; then
    printf 'The configured test command exceeded %ss and was killed:\n  %s\n\n' \
        "$timeout_s" "$cmd" >&2
    printf 'A Stop gate must be fast. Either point .claude/test-command at a quicker\n' >&2
    printf 'tier, or raise CLAUDE_TEST_TIMEOUT deliberately.\n' >&2
    exit 2
fi

{
    printf 'Tests are failing, so the work is not done.\n\n'
    printf '  command: %s\n  exit: %s\n\n' "$cmd" "$rc"
    printf '%s\n' "$out" | tail -40
    printf '\nFix these before reporting success. If the failure is pre-existing and\n'
    printf 'unrelated to your change, say so explicitly rather than ignoring it.\n'
} >&2
exit 2
