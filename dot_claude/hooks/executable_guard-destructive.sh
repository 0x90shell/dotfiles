#!/usr/bin/env bash
# PreToolUse (Bash): refuse destructive commands on real files.
#
# This replaces the "Bash(rm *)" style deny rules in settings.json, which match
# the command string as a glob and so miss every compound form:
#   cd ~/Documents && rm -rf snes
#   find . -name '*.tmp' | xargs rm
#   for f in *; do rm "$f"; done
# This hook splits the command into segments and inspects each one instead.
#
# Policy (from CLAUDE.md): rm is only for tempfiles, build artifacts and paths
# under /tmp. Everything else goes to trash-put.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/guard-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/guard-common.sh"

# shellcheck disable=SC2034  # read by guard_field() in the sourced library
GUARD_PAYLOAD=$(cat)
cmd=$(guard_field '.tool_input.command')
[[ -n $cmd ]] || guard_allow

guard_escaped "$cmd" && guard_allow

# Paths rm may touch freely: scratch space and regenerable build output.
path_is_disposable() {
    case $1 in
        /tmp/* | /var/tmp/* | /dev/shm/*) return 0 ;;
        *__pycache__* | *.pyc | *.pyo) return 0 ;;
        *node_modules* | *.ruff_cache* | *.mypy_cache* | *.pytest_cache*) return 0 ;;
        */target/* | */build/* | */dist/*) return 0 ;;
        *.o | *.a | *.so | *.tmp | *.log) return 0 ;;
    esac
    return 1
}

deny_rm() {
    guard_deny "Refused: '$1'

CLAUDE.md: never delete the user's files. rm is only for tempfiles, build
artifacts and paths under /tmp.

Use 'trash-put <path>' (trash-cli) instead, or move the file to a removed/ or
backup directory. Both are recoverable; rm is not.

If this really is disposable build output, say so and use an explicit path under
/tmp, or prefix the command with CLAUDE_GUARD_OFF=1 to override deliberately." \
        "Blocked: destructive command on non-disposable paths"
}

while IFS= read -r seg; do
    # Strip leading whitespace and any env-var assignments or sudo prefix.
    seg=${seg#"${seg%%[![:space:]]*}"}
    seg=$(sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//; s/^(sudo|command|env)[[:space:]]+//' <<<"$seg")
    [[ -n $seg ]] || continue

    # find with a destructive action, in any segment.
    if [[ $seg == find\ * ]] && [[ $seg =~ (-delete|-exec[[:space:]]+rm|-execdir[[:space:]]+rm) ]]; then
        # Bulk deletion is denied unless every name it targets is obviously
        # regenerable, which is what routine __pycache__/*.pyc cleanup looks like.
        if ! [[ $seg =~ (__pycache__|\.pyc|\.pyo|\.o|\.tmp|\.log|node_modules|ruff_cache|pytest_cache|mypy_cache) ]]; then
            deny_rm "$seg"
        fi
    fi

    # xargs feeding rm.
    if [[ $seg =~ ^xargs([[:space:]]|$) ]] && [[ $seg =~ (^|[[:space:]])rm([[:space:]]|$) ]]; then
        deny_rm "$seg"
    fi

    # Whole-disk and device writes are never OK from here.
    if [[ $seg =~ ^(mkfs|fdisk|parted|wipefs)([[:space:].]|$) ]] ||
        [[ $seg =~ ^dd[[:space:]].*of=/dev/ ]]; then
        guard_deny "Refused: '$seg' writes to a device or filesystem directly.
Nothing in this workflow needs that. If it is genuinely intended, run it yourself." \
            "Blocked: device/filesystem write"
    fi

    # git commands that discard uncommitted work.
    if [[ $seg =~ ^git[[:space:]] ]] && [[ $seg =~ (reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f) ]]; then
        guard_deny "Refused: '$seg' discards uncommitted work irrecoverably.

Use 'git stash' to set changes aside, or commit them first. If you truly want to
throw them away, prefix with CLAUDE_GUARD_OFF=1." \
            "Blocked: git command that discards work"
    fi

    # rm proper.
    [[ $seg =~ ^rm([[:space:]]|$) ]] || continue

    # Inspect every non-flag argument.
    read -r -a words <<<"$seg"
    targets=0
    for w in "${words[@]:1}"; do
        [[ $w == -* ]] && continue
        targets=$((targets + 1))
        # A variable or glob we cannot resolve is not something to guess about.
        if [[ $w == *'$'* || $w == '*' || $w == '/' || $w == '/*' ]]; then
            deny_rm "$seg"
        fi
        path_is_disposable "$w" || deny_rm "$seg"
    done
    # "rm" with only flags, or with everything hidden behind expansion.
    [[ $targets -eq 0 ]] && deny_rm "$seg"
done < <(guard_segments "$cmd")

guard_allow
