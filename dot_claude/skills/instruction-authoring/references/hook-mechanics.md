# Hook mechanics

<!-- slop-check: ignore -->

## Exit codes (backwards from most CLIs)

| Exit | Meaning |
| --- | --- |
| 0 | allow, silent |
| 2 | **block**, stderr goes back to the model |
| 1 or anything else | non-blocking error. Does NOT block. Common trap. |

## Contract

Payload arrives as JSON on stdin. Useful fields: `tool_name`, `tool_input`, `cwd`,
`session_id`, `agent_id`, `agent_type`, `stop_hook_active`.

A PreToolUse hook can instead print a decision object:

    {
      "systemMessage": "short line shown to the user",
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "what to do INSTEAD"
      }
    }

`additionalContext` must nest under `hookSpecificOutput`, never at top level.

## Traps

- Hooks run in a non-interactive shell with **no rc files sourced**. PATH is not
  your shell PATH. Resolve binaries with `command -v` or absolute paths.
- `@file` mentions bypass PreToolUse entirely, so a read-blocking hook has a hole.
- Stop hooks stop being honoured after **8 consecutive blocks**. A gate that can
  never go green burns the session instead of protecting it. Check
  `stop_hook_active` to avoid re-entering.
- A slow hook blocks the tool call. Over a few seconds, use `asyncRewake` in
  settings with `rewakeMessage` and `rewakeSummary`.
- Parallel subagents mean concurrent hook processes. Use `flock` on any shared
  counter or state file.
- The deny reason is read by the model, so write it as an instruction. Say what to
  do instead, not just that the call was refused.

## Guard conventions in this setup

- Shared helpers live in `~/.claude/hooks/lib/guard-common.sh`.
- Escape hatch is `CLAUDE_GUARD_OFF=1` as a command prefix, or exported for
  Write/Edit. Exported, it disables every guard for the whole session, so prefer
  the prefix.
- To test a guard from a Bash call, prefix the runner with `CLAUDE_GUARD_OFF=1`
  and then `unset CLAUDE_GUARD_OFF` inside it. Without the prefix the guard blocks
  its own test fixtures. Without the unset, the variable is inherited and every
  guard escapes, so all the deny cases silently pass.
- `~/.claude/**` is in scope for writes. The harness writes plans, memory and
  todos there through the Write tool; blocking it breaks plan mode.
