#!/usr/bin/env bash
# PreToolUse (Write|Edit|Bash): keep writes inside the project, /tmp and the
# session scratchpad.
#
# CLAUDE.md: "Write/move/delete operations must stay within the current project
# directory and /tmp." That is a rule the model can reason its way around under
# context pressure, so it becomes a gate here.
#
# Write/Edit carry an explicit file_path and are checked exactly. Bash is checked
# conservatively: only writes to unambiguous system locations are refused, so
# ordinary shell work is never caught by a guess.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/guard-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/guard-common.sh"

# shellcheck disable=SC2034  # read by guard_field() in the sourced library
GUARD_PAYLOAD=$(cat)
tool=$(guard_field '.tool_name')
cmd=$(guard_field '.tool_input.command')
path=$(guard_field '.tool_input.file_path')
cwd=$(guard_field '.cwd')
[[ -n $cwd ]] || cwd=$PWD

guard_escaped "$cmd" && guard_allow

in_scope() {
    local p=$1 r
    # Resolve BEFORE testing. A literal prefix test is not enough: the string
    # "$cwd/../../.bashrc" starts with "$cwd/" and would otherwise pass while
    # actually pointing outside the project.
    if [[ $p == /* ]]; then
        r=$(readlink -m -- "$p" 2>/dev/null) || return 1
    else
        r=$(readlink -m -- "$cwd/$p" 2>/dev/null) || return 1
    fi
    case $r in
        /tmp/* | /var/tmp/* | /dev/null | /dev/stdout | /dev/stderr) return 0 ;;
        "$cwd" | "$cwd"/*) return 0 ;;
        # The agent's own home. The harness writes plans, memory, todos and
        # session state here through the Write tool, so blocking it breaks plan
        # mode and the memory system outright. Skills, hooks, agents and output
        # styles live here too and are legitimate configuration work.
        "$HOME"/.claude | "$HOME"/.claude/*) return 0 ;;
    esac
    return 1
}

if [[ $tool == "Write" || $tool == "Edit" || $tool == "NotebookEdit" ]]; then
    [[ -n $path ]] || guard_allow
    in_scope "$path" && guard_allow
    guard_deny "Refused: '$path' is outside the current project and /tmp.

Current project directory: $cwd

Writes stay inside the project, /tmp, or the session scratchpad unless the user
names an external path explicitly. If they did name it, say so and re-issue with
CLAUDE_GUARD_OFF=1 exported, so the override is visible.

If this is a dotfile, remember it is probably chezmoi-managed: edit the chezmoi
source instead." \
        "Blocked: write outside project scope"
fi

# Bash: only refuse writes to unambiguous system locations.
#
# Checked PER SEGMENT. An earlier version matched across the whole command with
# .*, so any command containing "cp" plus the string "/opt/" anywhere later (a
# comment, for instance) was refused. Over-broad guards get switched off, so the
# match has to be tight.
if [[ $tool == "Bash" ]]; then
    [[ -n $cmd ]] || guard_allow
    sys='(/etc|/usr|/boot|/bin|/sbin|/lib|/lib64|/opt|/var/lib|/var/log|/sys|/proc)'

    deny_sys() {
        guard_deny "Refused: '$1' writes into a system directory.

System configuration on this machine is managed with chezmoi. Edit the chezmoi
source (~/.local/share/chezmoi) and run 'chezmoi apply', rather than writing to
the target directly.

If this genuinely has to bypass chezmoi, prefix with CLAUDE_GUARD_OFF=1." \
            "Blocked: write to a system directory"
    }

    while IFS= read -r seg; do
        seg=${seg#"${seg%%[![:space:]]*}"}
        seg=$(sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//; s/^(sudo|command|env)[[:space:]]+//' <<<"$seg")
        [[ -n $seg ]] || continue

        # A redirection into a system path, inside this segment only.
        if [[ $seg =~ (\>|\>\>)[[:space:]]*\"?${sys}/ ]]; then
            deny_sys "$seg"
        fi

        # tee writing to a system path.
        if [[ $seg =~ ^tee[[:space:]]+(-a[[:space:]]+)?\"?${sys}/ ]]; then
            deny_sys "$seg"
        fi

        # A copy/move/link whose DESTINATION (the final argument) is a system
        # path. Checking only the last word avoids matching a source path or a
        # path that merely appears somewhere in the line.
        if [[ $seg =~ ^(cp|mv|install|ln|touch|mkdir)([[:space:]]|$) ]]; then
            read -r -a w <<<"$seg"
            dest=${w[-1]}
            dest=${dest%\"}; dest=${dest#\"}
            if [[ $dest =~ ^${sys}/ ]]; then
                deny_sys "$seg"
            fi
        fi
    done < <(guard_segments "$cmd")
fi

guard_allow
