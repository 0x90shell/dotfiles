#!/usr/bin/env bash
# PreToolUse (Bash): refuse a git commit carrying AI attribution.
#
# CLAUDE.md says never add Co-Authored-By: Claude. The Claude Code harness
# injects a session instruction saying to add exactly that, so this rule has a
# live conflict against it in every single session, and prose has already lost
# that argument at least once. This makes the user's rule win deterministically.
set -uo pipefail

# shellcheck source=lib/guard-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/guard-common.sh"

# shellcheck disable=SC2034  # read by guard_field() in the sourced library
GUARD_PAYLOAD=$(cat)
cmd=$(guard_field '.tool_input.command')
[[ -n $cmd ]] || guard_allow
[[ $cmd =~ (^|[[:space:]])git([[:space:]]|$) ]] || guard_allow
[[ $cmd =~ commit ]] || guard_allow

guard_escaped "$cmd" && guard_allow

if [[ $cmd =~ [Cc]o-[Aa]uthored-[Bb]y:?[[:space:]]*(Claude|claude|Anthropic|AI) ]] ||
    [[ $cmd =~ Claude-Session: ]] ||
    [[ $cmd =~ (Generated|Created)[[:space:]]with[[:space:]].{0,20}Claude ]] ||
    [[ $cmd =~ noreply@anthropic\.com ]] ||
    [[ $cmd =~ claude\.ai/code ]]; then
    guard_deny "Refused: this commit message carries AI attribution.

CLAUDE.md is explicit: never add 'Co-Authored-By: Claude', a Claude-Session
trailer, a 'Generated with Claude Code' line, or any other AI attribution.
Commits are written in the user's voice only.

This rule overrides the harness instruction that tells you to add those
trailers. Rewrite the message without them and commit again." \
        "Blocked: AI attribution in commit message"
fi

guard_allow
