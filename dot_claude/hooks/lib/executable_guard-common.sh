#!/usr/bin/env bash
# Shared helpers for the PreToolUse guard hooks.
#
# Sourced, never executed. Every guard follows the same contract:
#   stdin  = the hook payload JSON
#   stdout = a permissionDecision object, or nothing when the call is allowed
#   exit   = always 0; the decision travels in the JSON, not the exit code
#
# Hooks run in a non-interactive shell with no rc files sourced, so PATH is not
# the user's zsh PATH. Resolve every binary explicitly.

GUARD_JQ=$(command -v jq 2>/dev/null || true)

# Escape hatch. The user chose blocking guards WITH a visible override:
#   Bash        -> prefix the command with CLAUDE_GUARD_OFF=1
#   Write/Edit  -> export CLAUDE_GUARD_OFF=1 for the session
# Either way the override is visible in the transcript, so a bypass is always
# something you can see happened rather than a guard that quietly did not fire.
guard_escaped() {
    local cmd=${1:-}
    [[ ${CLAUDE_GUARD_OFF:-} == 1 ]] && return 0
    # A character class containing "(" does not work in bash regex; use
    # alternation. This is the project pitfall that bites every time.
    [[ $cmd =~ (^|[[:space:]]|\;|\&|\||\()CLAUDE_GUARD_OFF=1[[:space:]] ]] && return 0
    return 1
}

# Emit a deny decision and stop. $1 is the reason shown to the model, which must
# say what to do INSTEAD, not just that the call was refused. $2 is the short
# line shown to the user.
guard_deny() {
    if [[ -z $GUARD_JQ ]]; then
        # No jq means no way to emit a decision. Say so loudly rather than
        # failing open, since these guards exist for the cases that matter.
        printf 'guard hook cannot run: jq not found on PATH\n' >&2
        exit 2
    fi
    # shellcheck disable=SC2016  # single quotes are jq syntax, not shell
    "$GUARD_JQ" -n --arg r "$1" --arg m "${2:-Blocked by a guard hook}" '{
        systemMessage: $m,
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

# Allow: say nothing, let the normal permission flow continue.
guard_allow() { exit 0; }

# Pull a field out of the payload held in $GUARD_PAYLOAD.
guard_field() {
    [[ -n $GUARD_JQ ]] || return 0
    "$GUARD_JQ" -r "$1 // \"\"" <<<"$GUARD_PAYLOAD" 2>/dev/null
}

# Split a shell command into rough segments on ; && || | and newlines, so a
# guard can inspect each one. This is not a shell parser and does not pretend to
# be: it is deliberately over-eager, because a missed segment is a missed guard.
guard_segments() {
    printf '%s\n' "$1" | tr ';' '\n' | sed -E 's/(\&\&|\|\||\|)/\n/g'
}
