#!/usr/bin/env bash
# config-guard.sh: ConfigChange hook for project settings, local settings and
# skills.
#
# Claude Code runs it when one of these files changes during a session, no
# matter who changed it: Claude through Edit or Bash, another program, or a
# person in an editor. If the change would break the guards, the hook exits 2
# and Claude Code does not apply the change to the running session; the
# guards that were working stay active.
#
# It blocks when
#   - the selftest no longer passes (selftest.sh --quiet prints a warning or
#     exits with an error), or
#   - .claude/settings.json or .claude/settings.local.json of the project is
#     not valid JSON or switches all hooks off ("disableAllHooks": true);
#     both files are read directly, also when Claude Code sends no file_path
#     and also in the plugin layout, where the selftest reads neither.
#
# Claude Code shows no message for a blocked change (hooks reference,
# ConfigChange decision control); the change is only not applied. Run
# bash .claude/hooks/selftest.sh to see why.
set +x

HOOK="config-guard"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=SCRIPTDIR/_common.sh
. "$HOOK_DIR/_common.sh" || { printf 'Blocked by %s: helper _common.sh could not be loaded.\n' "$HOOK" >&2; exit 2; }
require_parser "$HOOK"

payload="$(read_payload)"
require_input "$HOOK" "$payload"
require_payload "$HOOK" "$payload" source
source_name="$(printf '%s' "$payload" | json_get source)"
path="$(printf '%s' "$payload" | json_get file_path)"

case "$source_name" in
  project_settings|local_settings|skills) ;;
  *) exit 0 ;;
esac

# Both project settings files are read directly, whichever one changed and
# whether or not Claude Code sent file_path (the field is optional): the
# selftest reads only one file in the project layout, and none of them in the
# plugin layout, so "disableAllHooks": true would otherwise pass.
if [ "$source_name" != "skills" ]; then
  proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$payload" | json_get cwd)}"
  if [ -z "$proj" ] && [ -z "$path" ]; then
    block "$HOOK" "cannot tell which settings file changed, the change is not applied." ""
  fi
  for f in "$path" "${proj:+$proj/.claude/settings.json}" "${proj:+$proj/.claude/settings.local.json}"; do
    case "$f" in */settings.json|*/settings.local.json) ;; *) continue ;; esac
    [ -f "$f" ] || continue
    if ! json_valid < "$f"; then
      block "$HOOK" "$(basename "$f") is not valid JSON, the change is not applied." "Fix the file, then run bash .claude/hooks/selftest.sh."
    fi
    if [ "$(json_get disableAllHooks < "$f")" = "true" ]; then
      block "$HOOK" "$(basename "$f") switches all hooks off." "Remove \"disableAllHooks\" or set it to false."
    fi
  done
fi

report="$(bash "$HOOK_DIR/selftest.sh" --quiet 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] && [ -z "$report" ]; then
  report="selftest.sh exited with $rc and printed nothing."
fi
if [ -n "$report" ]; then
  block "$HOOK" "the change to $(basename "${path:-$source_name}") would break the guards, it is not applied." "$(printf '%s' "$report" | head -6)"
fi
exit 0
