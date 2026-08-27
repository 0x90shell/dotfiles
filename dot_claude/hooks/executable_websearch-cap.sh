#!/usr/bin/env bash
# PreToolUse hook: cap WebSearch calls per session and per subagent.
#
# Reads the hook payload on stdin. Every Claude Code hook payload carries
# session_id, agent_id and agent_type; agent_id is absent for the main loop
# and set for subagents, which is how the two budgets are told apart:
#
#   main loop  -> session cap only
#   subagent   -> its own cap, and still draws against the session cap
#
# Counters live under /tmp so they die with the boot; sessions never outlive
# that. Denied calls are not counted, so hitting a cap cannot inflate it further.
set -euo pipefail

SESSION_CAP="${CLAUDE_WEBSEARCH_SESSION_CAP:-200}"
AGENT_CAP="${CLAUDE_WEBSEARCH_AGENT_CAP:-20}"

payload=$(cat)

session_id=$(jq -r '.session_id // "unknown"' <<<"$payload")
agent_id=$(jq -r '.agent_id // ""' <<<"$payload")
agent_type=$(jq -r '.agent_type // "main"' <<<"$payload")

# session_id and agent_id land in filenames; keep them to a safe charset.
sanitize() { printf '%s' "${1//[^A-Za-z0-9._-]/_}"; }

state_dir="/tmp/claude-websearch-cap-$(id -u)/$(sanitize "$session_id")"
mkdir -p "$state_dir"

# Parallel subagents means concurrent hook processes racing the counter files.
exec 9>"$state_dir/.lock"
flock 9

read_count() {
    local file=$1 n=0
    if [[ -f $file ]]; then
        read -r n <"$file" || n=0
    fi
    [[ $n =~ ^[0-9]+$ ]] || n=0
    printf '%s' "$n"
}

# Deny rather than ask: at these ceilings a cap means something looped, and a
# prompt would just stall a fan-out waiting on a human.
deny() {
    jq -n --arg r "$1" --arg m "$2" '{
        systemMessage: $m,
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

session_file="$state_dir/session"
session_count=$(read_count "$session_file")

if ((session_count >= SESSION_CAP)); then
    deny "WebSearch session cap reached ($SESSION_CAP searches this session). \
Web search is blocked for the remainder of the session. Do not retry: answer \
from what you already have, and tell the user the cap was hit if it matters." \
        "WebSearch blocked: session cap of $SESSION_CAP reached"
fi

agent_file=""
agent_count=0
if [[ -n $agent_id ]]; then
    agent_file="$state_dir/agent-$(sanitize "$agent_id")"
    agent_count=$(read_count "$agent_file")

    if ((agent_count >= AGENT_CAP)); then
        deny "WebSearch per-agent cap reached ($AGENT_CAP searches for this \
$agent_type agent). This agent cannot search again. Do not retry: report what \
you found so far and finish." \
            "WebSearch blocked: $agent_type agent hit its cap of $AGENT_CAP"
    fi
fi

# Allowed: charge the budgets and stay silent.
printf '%s\n' "$((session_count + 1))" >"$session_file"
if [[ -n $agent_file ]]; then
    printf '%s\n' "$((agent_count + 1))" >"$agent_file"
fi

exit 0
