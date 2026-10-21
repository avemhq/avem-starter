#!/usr/bin/env bash
# _common.sh: helpers shared by the example hooks. Sourced, never run alone.
#
# Claude Code hands every hook its payload as JSON on stdin, for example
#   {"tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"/repo"}
# A hook that exits 2 blocks the tool call, and its stderr is shown to Claude
# as the reason. Exit 0 lets the normal permission flow decide.
#
# Written for bash 3.2 (the macOS default) as well as bash 4 and 5:
# no associative arrays, no ${var,,}, no mapfile.

# read_payload: print stdin once. Prints nothing when stdin is a terminal,
# so running a hook by hand without input does not hang.
read_payload() {
  if [ -t 0 ]; then
    return 0
  fi
  cat
}

# require_parser <hook-name>: block when neither jq nor python3 exists. A
# guard that cannot read its input would otherwise exit 0 on everything, and
# onFailure cannot see that, because the exit code says success.
require_parser() {
  if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    printf 'Blocked by %s: neither jq nor python3 found, the guard cannot read its input.\n' "$1" >&2
    printf '%s\n' 'Install jq or python3, then run bash .claude/hooks/selftest.sh.' >&2
    exit 2
  fi
}

# require_input <hook-name> <payload>: an empty payload passes only when
# stdin is a terminal (the hook was run by hand). Claude Code always sends
# JSON, so empty redirected input means something broke on the way: block.
require_input() {
  if [ -z "$2" ]; then
    if [ -t 0 ]; then
      exit 0
    fi
    printf 'Blocked by %s: the hook input was empty.\n' "$1" >&2
    exit 2
  fi
}

# json_valid: exit 0 when stdin is exactly one JSON object. jq or python3.
# -s with length == 1: plain jq -e would accept "{} {}" or "false {}".
json_valid() {
  if command -v jq >/dev/null 2>&1; then
    jq -s -e 'length == 1 and (.[0] | type == "object")' >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys
sys.exit(0 if isinstance(json.load(sys.stdin), dict) else 1)' >/dev/null 2>&1
  else
    return 3
  fi
}

# require_payload <hook-name> <payload> <field>: block unless the payload is
# a valid JSON object and the field is present and not empty. A parser that
# exists but fails (or input that is not JSON) would otherwise look like an
# empty, harmless call and pass with exit 0, where onFailure cannot see it.
require_payload() {
  if ! printf '%s' "$2" | json_valid; then
    printf 'Blocked by %s: the hook input could not be read as JSON.\n' "$1" >&2
    exit 2
  fi
  if [ -z "$(printf '%s' "$2" | json_get "$3")" ]; then
    printf 'Blocked by %s: the hook input has no %s.\n' "$1" "$3" >&2
    exit 2
  fi
  require_string "$1" "$2" "$3"
}

# END_MARK and require_end <hook-name> <seen>: the guards read their command
# segments from a here-document and put END_MARK on its last line. bash 3.2
# writes a here-document to a temp file; when it cannot (no writable TMPDIR),
# the loop does not run at all and the guard would reach exit 0. A guard that
# did not see END_MARK blocks instead.
# shellcheck disable=SC2034  # read by the guards that source this file
END_MARK='__end_of_guard_checks__'
require_end() {
  if [ "$2" != "1" ]; then
    printf 'Blocked by %s: the guard could not read its own check list (here-document failed, is TMPDIR writable?).\n' "$1" >&2
    exit 2
  fi
}

# require_string <hook-name> <payload> <dotted.path>: block unless the value
# at the path is a JSON string. A missing field, a number or an object would
# otherwise read as an empty, harmless command (a failing jq field access
# also prints nothing).
require_string() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$2" | jq -e --arg p "$3" 'getpath($p | split(".")) | type == "string"' >/dev/null 2>&1
  else
    printf '%s' "$2" | python3 -c 'import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
sys.exit(0 if isinstance(d, str) else 1)' "$3" >/dev/null 2>&1
  fi || {
    printf 'Blocked by %s: the hook input has no text in %s.\n' "$1" "$3" >&2
    exit 2
  }
}

# json_get <dotted.path>: read JSON on stdin, print the value at the path
# (strings as is, everything else as JSON). Prints nothing when the path is
# missing. Uses jq, falls back to python3. Returns 3 when neither exists;
# the guards call require_parser first, so they block in that case.
json_get() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg p "$1" 'getpath($p | split(".")) // empty | if type == "string" then . else tojson end' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
if d is not None:
    sys.stdout.write(d if isinstance(d, str) else json.dumps(d))
' "$1" 2>/dev/null
  else
    return 3
  fi
}

# segments: read a shell command on stdin, print one simple command per line.
# Splits at && || ; | & ( ) $( and backticks, trims whitespace and group
# braces, and strips what only wraps the real command: leading VAR=value
# assignments, sudo, command, builtin, exec, nohup, time, nice, env, xargs,
# noglob, timeout N, and "bash -c" / "sh -c" / "zsh -c" with an optional
# opening quote. Braces are not split points, so ${NAME} stays intact.
#
# Known limit, on purpose: quotes are not parsed. A separator inside a quoted
# string also splits, so prose in a commit message can look like a command.
# That errs toward blocking, which is the safe side for a guard.
segments() {
  awk '{ gsub(/&&|\|\||\$\(|[|;&()`]/, "\n"); print }' |
  while IFS= read -r seg; do
    prev=""
    while [ "$seg" != "$prev" ]; do
      prev="$seg"
      seg="$(printf '%s' "$seg" | sed -E \
        -e 's/^[[:space:]]+//' \
        -e 's/[[:space:]]+$//' \
        -e 's/^\{[[:space:]]*//' \
        -e 's/^\}$//' \
        -e 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+//' \
        -e 's/^(sudo|command|builtin|exec|nohup|time|nice|env|xargs|noglob)[[:space:]]+//' \
        -e 's/^timeout[[:space:]]+[0-9.]+[smhd]?[[:space:]]+//' \
        -e 's/^(bash|sh|zsh)[[:space:]]+-c[[:space:]]+["'\'']?//')"
    done
    if [ -n "$seg" ]; then
      printf '%s\n' "$seg"
    fi
  done
}

# block <hook-name> <reason> <hint>: print the reason for Claude and exit 2.
block() {
  printf 'Blocked by %s: %s\n' "$1" "$2" >&2
  if [ -n "${3:-}" ]; then
    printf '%s\n' "$3" >&2
  fi
  exit 2
}
