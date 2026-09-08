#!/usr/bin/env bash
# PreToolUse (Bash): refuse a test run that could reach the real user config.
#
# This targets a specific incident: a test migrated the user's real config
# because resolveConfig() had side effects and XDG_CONFIG_HOME was not set.
#
# A test command is allowed when EITHER
#   - the command itself redirects config/home to a temp dir, or
#   - the project has verified its harness is sandboxed, recorded in
#     .claude/test-isolation-verified (a file whose contents say why).
# The second form keeps this hook generic: no project-specific knowledge lives
# here, the project declares its own status.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/guard-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/guard-common.sh"

# shellcheck disable=SC2034  # read by guard_field() in the sourced library
GUARD_PAYLOAD=$(cat)
cmd=$(guard_field '.tool_input.command')
cwd=$(guard_field '.cwd'); [[ -n $cwd ]] || cwd=$PWD
[[ -n $cmd ]] || guard_allow

guard_escaped "$cmd" && guard_allow

# Is this a test invocation at all?
is_test=0
[[ $cmd =~ (^|[[:space:]])pytest([[:space:]]|$) ]] && is_test=1
[[ $cmd =~ python[0-9.]*[[:space:]]+-m[[:space:]]+pytest ]] && is_test=1
[[ $cmd =~ (^|[[:space:]])(tox|nox)([[:space:]]|$) ]] && is_test=1
[[ $cmd =~ (^|[[:space:]])go[[:space:]]+test([[:space:]]|$) ]] && is_test=1
[[ $cmd =~ (npm|yarn|pnpm)[[:space:]]+(run[[:space:]]+)?test ]] && is_test=1
[[ $cmd =~ selftest ]] && is_test=1
[[ $cmd =~ (^|[[:space:]])(\./)?[a-zA-Z0-9_.-]+\.sh[[:space:]]+[a-z0-9]+[[:space:]]+test([[:space:]]|$) ]] && is_test=1
[[ $is_test -eq 1 ]] || guard_allow

# Isolation supplied inline?
[[ $cmd =~ XDG_CONFIG_HOME=(/tmp|/var/tmp|\"?\$\(mktemp) ]] && guard_allow
[[ $cmd =~ HOME=(/tmp|/var/tmp|\"?\$\(mktemp) ]] && guard_allow

# Isolation verified once, by the project.
marker="$cwd/.claude/test-isolation-verified"
[[ -f $marker ]] && guard_allow

guard_deny "Refused: test run with no config isolation.

Command: $cmd

Tests that resolve config paths must not be able to reach the real user config.
This has already gone wrong once here: a test migrated real config files because
resolveConfig() had side effects and XDG_CONFIG_HOME was not set.

Do one of these:
  1. Set the env inline:
       XDG_CONFIG_HOME=\$(mktemp -d) XDG_DATA_HOME=\$(mktemp -d) <command>
  2. If this project's harness is genuinely sandboxed, verify that (find where it
     puts its scratch dir, confirm it is under /tmp), then record it once:
       echo 'why this harness is sandboxed' > $marker
     After that this guard stays out of the way for this project.

Do not skip straight to CLAUDE_GUARD_OFF=1 without checking which of the two
applies." \
    "Blocked: test run without config isolation"
