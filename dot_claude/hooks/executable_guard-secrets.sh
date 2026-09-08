#!/usr/bin/env bash
# PreToolUse: refuse access to the user's own credential stores.
#
# Deliberately narrow. This machine is used for offensive security work, so the
# hook must NOT get in the way of reading keys, certs or dumps that belong to a
# target or a test rig. It guards the operator's own secrets only: paths under
# their home directory that hold credentials.
#
# The settings.json deny globs cover Read/Edit on ~/.ssh and ~/.gnupg, but not
# `cat ~/.ssh/id_ed25519`, not `env`, and not ~/.aws or ~/.netrc.
set -uo pipefail

# shellcheck source=lib/guard-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/guard-common.sh"

# shellcheck disable=SC2034  # read by guard_field() in the sourced library
GUARD_PAYLOAD=$(cat)
tool=$(guard_field '.tool_name')
cmd=$(guard_field '.tool_input.command')
path=$(guard_field '.tool_input.file_path')

guard_escaped "$cmd" && guard_allow

subject="$cmd $path"
[[ -n ${subject//[[:space:]]/} ]] || guard_allow

home_re="(${HOME}|~|\\\$HOME)"

# The operator's own credential material.
if [[ $subject =~ ${home_re}/\.ssh/ ]] ||
    [[ $subject =~ ${home_re}/\.gnupg/ ]] ||
    [[ $subject =~ ${home_re}/\.aws/credentials ]] ||
    [[ $subject =~ ${home_re}/\.netrc ]] ||
    [[ $subject =~ ${home_re}/\.config/[^[:space:]]*(credential|secret|token) ]] ||
    [[ $subject =~ ${home_re}/\.password-store/ ]]; then
    # A public key is not a secret and is routinely needed.
    [[ $subject =~ \.pub([[:space:]]|$|\") ]] && guard_allow
    [[ $subject =~ ssh/(config|known_hosts) ]] && guard_allow
    guard_deny "Refused: that path holds the operator's own credentials.

This guard is scoped to the user's personal secret stores (~/.ssh private keys,
~/.gnupg, ~/.aws/credentials, ~/.netrc, password-store). It does not restrict
key or cert material belonging to a target or test rig, so security work is
unaffected.

If you need a fingerprint or a public key, read the .pub file. If you genuinely
need the private material, ask the user to do it, or prefix with
CLAUDE_GUARD_OFF=1." \
        "Blocked: access to your own credential store"
fi

# Wholesale environment dumps, which routinely carry tokens.
if [[ $tool == "Bash" ]] && [[ $cmd =~ ^[[:space:]]*(env|printenv|set)[[:space:]]*$ ]]; then
    guard_deny "Refused: a bare environment dump exposes every token in the session.

Read the one variable you actually need: printenv VARNAME, or \${VARNAME}." \
        "Blocked: full environment dump"
fi

guard_allow
