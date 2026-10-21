#!/usr/bin/env bash
# recheck-guards.sh: PostToolUse hook for Edit and Write.
#
# When Claude changes a guard, the settings (also settings.local.json), an
# agent, a skill, a rule or the MCP configuration with Edit or Write, the
# guards prove themselves again right away: this hook runs
# selftest.sh --quiet and, if a check fails, exits 2 so Claude sees the
# warning next to its own edit and can repair it in the same turn.
#
# Edits to any other file pass without running anything.
set +x

HOOK="recheck-guards"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=SCRIPTDIR/_common.sh
. "$HOOK_DIR/_common.sh"

payload="$(read_payload)"
[ -n "$payload" ] || exit 0
case "$(printf '%s' "$payload" | json_get tool_name)" in
  Edit|Write) ;;
  *) exit 0 ;;
esac
path="$(printf '%s' "$payload" | json_get tool_input.file_path)"

case "$path" in
  */.claude/hooks/*|*/.claude/settings.json|*/.claude/settings.example.json|*/.claude/settings.local.json|*/.claude/agents/*|*/.claude/skills/*|*/.claude/rules/*|*/.mcp.json|*/.mcp.json.example) ;;
  *) exit 0 ;;
esac

report="$(bash "$HOOK_DIR/selftest.sh" --quiet 2>&1)"
rc=$?
# --quiet exits 0 and prints nothing when all is good. Anything else, a
# warning or a crash without output, means the guards are not proven.
if [ "$rc" -ne 0 ] && [ -z "$report" ]; then
  report="selftest.sh exited with $rc and printed nothing."
fi
if [ -n "$report" ]; then
  block "$HOOK" "the guards no longer pass their selftest after this edit to $(basename "$path")." "$(printf '%s' "$report" | head -6)"
fi
exit 0
