#!/usr/bin/env bash
# shellcheck disable=SC2016  # test payloads are literal strings on purpose
# selftest.sh: proves that the guards fire.
#
# A guard that never speaks looks exactly like a guard with nothing to
# report. Hooks fail quietly: a renamed field in the payload, a missing jq,
# a lost executable bit, and the hook exits 0 on everything while the session
# feels protected. So every guard is checked on three axes:
#
#   registered  wired up in the settings as the one canonical command
#               (exec form, args []), executable, not async, no if filter,
#               and set to block when it fails
#   speaks      every known violation is blocked (exit 2, reason on stderr)
#   silent      harmless commands pass (exit 0); a guard that blocks
#               everything is as broken as one that blocks nothing
#
# Also checked: the selftest runs at session start, the reviewer subagent has
# no shell and no edit tools, the review skill runs in it, and the MCP
# configuration (.mcp.json, else .mcp.json.example) avoids common mistakes:
# credentials in named fields not given as ${VAR}, floating package versions,
# plain http. The MCP part is a hint for common mistakes, not a guarantee.
#
# Usage: selftest.sh [--quiet | --calibrate]
#   (none)       table; exit 0 all good, 1 a check failed, 2 cannot run
#   --quiet      for hooks: silent when all is good, a short warning
#                otherwise, always exit 0 so a broken guard never blocks the
#                session start
#   --calibrate  runs every "speaks" case against a stub hook that never
#                blocks, the registration checks against broken settings and
#                agent files, and the MCP checks against a broken config.
#                Every case must fail. A test that can only pass is itself a
#                silent guard.
#
# SELFTEST_SHELL=/bin/bash runs every hook under that interpreter, for
# example to check the bash 3.2 that ships with macOS.
set +x
set -u

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARDS="protect-secrets guard-git block-external-send"
HOOKS="$GUARDS recheck-guards config-guard"

# Two layouts. Project: the scripts sit in <project>/.claude/hooks/ and are
# registered in .claude/settings.json. Plugin (built by scripts/build-plugin.sh):
# the scripts sit in <plugin>/scripts/, next to .claude-plugin/plugin.json,
# and are registered in <plugin>/hooks/hooks.json.
if [ -f "$HOOK_DIR/../.claude-plugin/plugin.json" ]; then
  LAYOUT="plugin"
  ROOT="$(cd "$HOOK_DIR/.." && pwd)"
  PREFIX='${CLAUDE_PLUGIN_ROOT}/scripts'
  AGENT="$ROOT/agents/reviewer.md"
  SKILL="$ROOT/skills/pre-merge-review/SKILL.md"
else
  LAYOUT="project"
  ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$HOOK_DIR/../.." && pwd)}"
  PREFIX='${CLAUDE_PROJECT_DIR}/.claude/hooks'
  AGENT="$ROOT/.claude/agents/reviewer.md"
  SKILL="$ROOT/.claude/skills/pre-merge-review/SKILL.md"
fi
PROJECT_DIR="$ROOT"
# The path tail every registered script name ends with, after the prefix.
PREFIX_TAIL="${PREFIX#*\}}"
RUNNER="${SELFTEST_SHELL:-}"
# Claude Code version that first honors "onFailure": "block".
ONFAILURE_MIN="2.1.295"

MODE="normal"
for arg in "$@"; do
  case "$arg" in
    --quiet) MODE="quiet" ;;
    --calibrate) MODE="calibrate" ;;
    -h|--help) sed -n '3,35p' "$0"; exit 0 ;;
    *) echo "selftest: unknown option $arg" >&2; exit 2 ;;
  esac
done

SETTINGS=""
MCP=""
if [ "$LAYOUT" = "plugin" ]; then
  [ -f "$ROOT/hooks/hooks.json" ] && SETTINGS="$ROOT/hooks/hooks.json"
  [ -f "$ROOT/.mcp.json" ] && MCP="$ROOT/.mcp.json"
else
  for f in "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/.claude/settings.example.json"; do
    if [ -f "$f" ]; then SETTINGS="$f"; break; fi
  done
  for f in "$PROJECT_DIR/.mcp.json" "$PROJECT_DIR/.mcp.json.example"; do
    if [ -f "$f" ]; then MCP="$f"; break; fi
  done
fi

if command -v jq >/dev/null 2>&1; then
  PARSER="jq"
elif command -v python3 >/dev/null 2>&1; then
  PARSER="python3"
else
  echo "selftest: neither jq nor python3 found. The hooks cannot read their input and let everything through." >&2
  [ "$MODE" = "quiet" ] && exit 0
  exit 2
fi

tmpbase="${TMPDIR:-/tmp}"
TMPROOT="$(mktemp -d "${tmpbase%/}/selftest.XXXXXX")" || exit 2
trap 'rm -rf "$TMPROOT"' EXIT

# Two throwaway repositories, one on main and one on a feature branch, for the
# "bare git push" cases.
mkrepo() {
  git init -q "$TMPROOT/$1" >/dev/null 2>&1 || return 1
  git -C "$TMPROOT/$1" symbolic-ref HEAD "refs/heads/$2" >/dev/null 2>&1
  git -C "$TMPROOT/$1" -c user.name=selftest -c user.email=selftest@example.invalid \
    commit -q --allow-empty -m init >/dev/null 2>&1
}
mkrepo on-main main
mkrepo on-feature feature/login
REPO_MAIN="$TMPROOT/on-main"
REPO_FEATURE="$TMPROOT/on-feature"

# Stub for --calibrate: a hook that never blocks.
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$TMPROOT/stub.sh"
chmod +x "$TMPROOT/stub.sh"

# Copies of recheck-guards.sh and config-guard.sh, each next to a stand-in
# selftest: one that reports a broken guard, one that reports nothing, one
# that crashes without a word. So their cases never start the real selftest
# from inside the selftest.
mkcopy() {
  mkdir -p "$TMPROOT/$1"
  cp "$HOOK_DIR/$2.sh" "$HOOK_DIR/_common.sh" "$TMPROOT/$1/"
  printf '#!/usr/bin/env bash\nprintf "%%s" "%s"\n' "$3" > "$TMPROOT/$1/selftest.sh"
  chmod +x "$TMPROOT/$1/$2.sh" "$TMPROOT/$1/selftest.sh"
}
for h in recheck-guards config-guard; do
  mkcopy "$h-red" "$h" 'WARNING from selftest: 1 of 80 guard checks failed.'
  mkcopy "$h-green" "$h" ''
  mkcopy "$h-crash" "$h" ''
  printf '#!/usr/bin/env bash\nexit 7\n' > "$TMPROOT/$h-crash/selftest.sh"
done
# A guard whose here-document lost its END_MARK line, as when bash 3.2
# cannot write the here-document to a temp file: it must block, not pass.
for guard_name in protect-secrets guard-git block-external-send; do
  mkcopy "$guard_name-noend" "$guard_name" ''
  sed '/^\$END_MARK$/d' "$HOOK_DIR/$guard_name.sh" > "$TMPROOT/$guard_name-noend/$guard_name.sh"
done

# Settings files for the config-guard cases.
printf '{"disableAllHooks": true}\n' > "$TMPROOT/local-off.json"
printf '{"permissions": {"allow": []}}\n' > "$TMPROOT/local-ok.json"
mkdir -p "$TMPROOT/proj/.claude"
cp "$TMPROOT/local-off.json" "$TMPROOT/proj/.claude/settings.local.json"
mkdir -p "$TMPROOT/proj2/.claude"
cp "$TMPROOT/local-ok.json" "$TMPROOT/proj2/.claude/settings.local.json"

mkdir -p "$TMPROOT/proj3/.claude" "$TMPROOT/proj4/.claude"
printf '{"disableAllHooks": true}\n' > "$TMPROOT/proj3/.claude/settings.json"
printf '{"permissions": \n' > "$TMPROOT/proj4/.claude/settings.local.json"

# A PATH without jq and python3, for the "no parser" cases, and one whose jq
# exists but fails on every input, for the "broken parser" cases.
mkdir -p "$TMPROOT/noparser-bin" "$TMPROOT/brokenjq-bin"
for t in bash cat dirname head; do
  p="$(command -v "$t")" && ln -s "$p" "$TMPROOT/noparser-bin/$t" && ln -s "$p" "$TMPROOT/brokenjq-bin/$t"
done
printf '#!/bin/sh\ncat >/dev/null\nexit 5\n' > "$TMPROOT/brokenjq-bin/jq"
chmod +x "$TMPROOT/brokenjq-bin/jq"

# payload <tool> <field> <value> [cwd]: the JSON Claude Code would send.
# For tool "ConfigChange", field is the source and value the file path.
payload() {
  if [ "$PARSER" = "jq" ]; then
    if [ "$1" = "ConfigChange" ]; then
      jq -cn --arg s "$2" --arg f "$3" --arg c "${4:-$TMPROOT}" \
        '{hook_event_name: "ConfigChange", source: $s, file_path: $f, cwd: $c}'
    else
      jq -cn --arg t "$1" --arg k "$2" --arg v "$3" --arg c "${4:-$TMPROOT}" \
        '{hook_event_name: "PreToolUse", tool_name: $t, tool_input: {($k): $v}, cwd: $c}'
    fi
  else
    python3 -c 'import json, sys
t, k, v, c = sys.argv[1:5]
if t == "ConfigChange":
    print(json.dumps({"hook_event_name": "ConfigChange", "source": k, "file_path": v, "cwd": c}))
else:
    print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": t, "tool_input": {k: v}, "cwd": c}))' \
      "$1" "$2" "$3" "${4:-$TMPROOT}"
  fi
}

# run_hook <hook> <json>: sets RC and ERR (stderr of the hook).
# HOOK_FILE, when set, replaces the hook file (copies with stand-ins).
# HOOK_PATH, when set, is the PATH the hook runs with.
# HOOK_PROJECT is the CLAUDE_PROJECT_DIR the hook sees (empty by default, so
# a real session's project never leaks into a test).
HOOK_FILE=""
HOOK_PATH=""
HOOK_PROJECT=""
run_hook() {
  h="${HOOK_FILE:-$HOOK_DIR/$1.sh}"
  [ "$MODE" = "calibrate" ] && h="$TMPROOT/stub.sh"
  hp="${HOOK_PATH:-$PATH}"
  if [ -n "$RUNNER" ]; then
    ERR="$(printf '%s' "$2" | PATH="$hp" CLAUDE_PROJECT_DIR="$HOOK_PROJECT" "$RUNNER" "$h" 2>&1 >/dev/null)"; RC=$?
  else
    ERR="$(printf '%s' "$2" | PATH="$hp" CLAUDE_PROJECT_DIR="$HOOK_PROJECT" "$h" 2>&1 >/dev/null)"; RC=$?
  fi
}

# expect_block_raw <hook> <label> <raw input>: input that is not a normal payload.
expect_block_raw() {
  TOTAL=$((TOTAL + 1)); bump "$1" speaks_total
  run_hook "$1" "$3"
  if [ "$RC" -eq 2 ] && [ -n "$ERR" ]; then
    bump "$1" speaks_ok
  else
    fail "$1 speaks: $2 was not blocked (exit $RC)"
  fi
}

TOTAL=0
FAILED=0
FAIL_LINES=""
fail() {
  FAILED=$((FAILED + 1))
  FAIL_LINES="${FAIL_LINES}  FAIL ${1}
"
}

# Per hook counters, kept in plain variables (bash 3.2 has no maps).
counter_name() { printf '%s_%s' "$(printf '%s' "$1" | tr '-' '_')" "$2"; }
bump() { n="$(counter_name "$1" "$2")"; eval "$n=\$(( \${$n:-0} + 1 ))"; }
count() { n="$(counter_name "$1" "$2")"; eval "printf '%s' \"\${$n:-0}\""; }

# expect_block <hook> <tool> <field> <value> [cwd]
expect_block() {
  TOTAL=$((TOTAL + 1)); bump "$1" speaks_total
  run_hook "$1" "$(payload "$2" "$3" "$4" "${5:-}")"
  if [ "$RC" -eq 2 ] && [ -n "$ERR" ]; then
    bump "$1" speaks_ok
  else
    fail "$1 speaks: '$4' was not blocked (exit $RC)"
  fi
}

# expect_pass <hook> <tool> <field> <value> [cwd]
expect_pass() {
  [ "$MODE" = "calibrate" ] && return 0
  TOTAL=$((TOTAL + 1)); bump "$1" silent_total
  run_hook "$1" "$(payload "$2" "$3" "$4" "${5:-}")"
  if [ "$RC" -eq 0 ]; then
    bump "$1" silent_ok
  else
    fail "$1 silent: '$4' was blocked (exit $RC): $(printf '%s' "$ERR" | head -1)"
  fi
}

# --- registered ---------------------------------------------------------------
# settings_valid <settings>: exactly one JSON document, an object, and hooks
# (if present) an object. jq reads a stream of documents and would happily
# use the first one of a broken file; Claude Code may skip such a file.
settings_valid() {
  if [ "$PARSER" = "jq" ]; then
    jq -s -e 'length == 1 and (.[0] | type == "object")
      and ((.[0] | has("hooks") | not) or (.[0].hooks | type == "object"))' "$1" >/dev/null 2>&1
  else
    python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if isinstance(d, dict) and isinstance(d.get("hooks", {}), dict) else 1)' "$1" >/dev/null 2>&1
  fi
}

# handler_refs <settings> <event> <tool>: one line per command handler that
# Claude Code would run for this event and tool, as
# "onFailure|async|if|command|args". A field that is present counts with its
# value, even false or null (has(), not //), and args shows "<none>" when the
# field is missing, because without args Claude Code runs the command through
# a shell. Follows the matcher rules of the hooks reference (empty or "*"
# matches all, plain names separated by | or , match exactly, anything else
# is a regular expression) and returns nothing when disableAllHooks is true.
handler_refs() {
  if [ "$PARSER" = "jq" ]; then
    jq -r --arg ev "$2" --arg t "$3" '
      def hit($m):
        if ($m == null or $m == "" or $m == "*") then true
        elif ($m | test("^[A-Za-z0-9_|, -]+$")) then ([$m | splits("[|,]") | gsub("^\\s+|\\s+$"; "")] | index($t)) != null
        else ($t | test($m)) end;
      def f($k; $none): if has($k) then (.[$k] | tostring) else $none end;
      if .disableAllHooks == true then empty
      else (.hooks[$ev] // [])[] | select(hit(.matcher)) | (.hooks // [])[]
           | select(.type == "command")
           | "\(f("onFailure"; "-"))|\(if (has("async") and .async != false) or (has("asyncRewake") and .asyncRewake != false) then "true" else "false" end)|\(f("if"; "-"))|\(f("command"; ""))|\(if has("args") then (if (.args | type) == "array" then (.args | map(tostring) | join(" ")) else "<bad>" end) else "<none>" end)" end' "$1" 2>/dev/null
  else
    python3 -c 'import json, re, sys
s = json.load(open(sys.argv[1])); ev, t = sys.argv[2], sys.argv[3]
def hit(m):
    if m in (None, "", "*"): return True
    if re.fullmatch(r"[A-Za-z0-9_|, -]+", m): return t in [x.strip() for x in re.split(r"[|,]", m)]
    return re.search(m, t) is not None
def f(h, k, none):
    if k not in h: return none
    v = h[k]
    return json.dumps(v) if not isinstance(v, str) else v
if s.get("disableAllHooks") is not True:
    for g in (s.get("hooks") or {}).get(ev) or []:
        if hit(g.get("matcher")):
            for h in g.get("hooks") or []:
                if h.get("type") == "command":
                    asy = ("async" in h and h["async"] is not False) or ("asyncRewake" in h and h["asyncRewake"] is not False)
                    if "args" not in h: a = "<none>"
                    elif isinstance(h["args"], list): a = " ".join(x if isinstance(x, str) else json.dumps(x) for x in h["args"])
                    else: a = "<bad>"
                    print("%s|%s|%s|%s|%s" % (f(h, "onFailure", "-"), "true" if asy else "false", f(h, "if", "-"), f(h, "command", ""), a))' "$1" "$2" "$3" 2>/dev/null
  fi
}

# The reviewer's frontmatter and the review skill's fork lines as they must
# be. Change these together with .claude/agents/reviewer.md and the skill.
# The whole reviewer frontmatter is compared with this exact text (trailing
# spaces aside), not searched line by line: a line such as "tools: ..." can
# also sit inside a multi-line description, where YAML does not read it as a
# field and the subagent would inherit every tool.
REVIEWER_FM='name: reviewer
description: Read-only cold reviewer for a diff or branch. Use before a push or merge, or when asked to review changes. It has no shell and cannot edit files.
tools: Read, Grep, Glob
disallowedTools: Bash, Edit, Write, NotebookEdit
model: inherit
color: cyan'
# The review skill's frontmatter, compared the same way: a second
# "context:" line further down would override the fork.
SKILL_FM='name: pre-merge-review
description: Cold review of the current branch against main before a push or merge. Checks that every claim in the commits is backed by the diff, that tests ran on this exact state, that guards were tested against a known violation, and that no secret is in the diff. Use before "push", "merge", "ready for review", or when asked to review a branch.
allowed-tools: Bash(git status *) Bash(git log *) Bash(git diff *)
context: fork
agent: reviewer
background: false'

# frontmatter <file>: the YAML between a --- first line and the next ---
# line. Prints nothing when either marker is missing: Claude Code then reads
# no fields at all, so a file cut off before its closing --- must not pass.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit; next }
       $0 == "---" { closed = 1; exit }
       { buf = buf $0 "\n" }
       END { if (closed) printf "%s", buf }' "$1"
}

REG_STATUS=""
reg() { REG_STATUS="$REG_STATUS $1:$2"; }

# canonical <hook>: the one command form a guard may be registered with. Exec
# form (args present and empty), no shell, no wrapper, no other path.
canonical() { printf '%s' "$PREFIX/$1.sh"; }

# plain_ok <lines> <need-block>: every line is a plain call of the canonical
# command: args [], not async, no if filter, and onFailure block if asked.
plain_ok() {
  printf '%s\n' "$1" | awk -F'|' -v b="$2" 'NF && !(NF == 5 && $2 == "false" && $3 == "-" && $5 == "" && (b == "no" || $1 == "block")) { bad = 1 } END { exit bad }'
}

# deny_order <settings>: "ok" when permissions.deny holds Read(./.env.*)
# and, later in the list, Read(!.env.example).
deny_order() {
  if [ "$PARSER" = "jq" ]; then
    jq -r '(.permissions.deny // []) as $d
      | ($d | index("Read(./.env.*)")) as $a | ($d | index("Read(!.env.example)")) as $b
      | if $a != null and $b != null and $b > $a then "ok" else "no" end' "$1" 2>/dev/null
  else
    python3 -c 'import json, sys
d = (json.load(open(sys.argv[1])).get("permissions") or {}).get("deny") or []
a = d.index("Read(./.env.*)") if "Read(./.env.*)" in d else None
b = d.index("Read(!.env.example)") if "Read(!.env.example)" in d else None
print("ok" if a is not None and b is not None and b > a else "no")' "$1" 2>/dev/null
  fi
}

# hook_lines <handler_refs output> <hook>: handlers that name the hook script
# anywhere (command or args), so a wrapped or shell-form registration is seen
# and judged instead of being overlooked.
hook_lines() { printf '%s\n' "$1" | grep -F "$PREFIX_TAIL/$2.sh"; }

# check_registered <settings> <agent-file> <skill-file> <checks...>
# Checks: the guards, recheck-guards, selftest-start, reviewer, review-skill.
check_registered() {
  s="$1"; a="$2"; k="$3"; shift 3
  name="$(basename "$s")"
  if settings_valid "$s"; then sv=1; else sv=0; fi
  bash_refs="$(handler_refs "$s" PreToolUse Bash)"
  read_refs="$(handler_refs "$s" PreToolUse Read)"
  for h in "$@"; do
    TOTAL=$((TOTAL + 1))
    if [ "$sv" -eq 0 ] && [ "$h" != "reviewer" ] && [ "$h" != "review-skill" ]; then
      fail "$h registered: $name is not exactly one valid JSON object, Claude Code may skip it"; reg "$h" invalid-settings
      continue
    fi
    case "$h" in
      reviewer)
        fm="$(frontmatter "$a" 2>/dev/null | sed -E 's/[[:space:]]+$//')"
        if [ ! -f "$a" ] || [ "$fm" != "$REVIEWER_FM" ]; then
          fail "reviewer registered: the frontmatter of $(basename "$a") differs from the canonical text in selftest.sh (tools Read, Grep, Glob; Bash, Edit, Write, NotebookEdit disallowed)"; reg "$h" writable
        else
          reg "$h" ok
        fi ;;
      env-rules)
        # Read(./.env.*) blocks every .env variant; Read(!.env.example) after
        # it carves the template back out. A ! rule listed first carves
        # nothing out (permissions reference, gitignore negation).
        if [ "$(deny_order "$s")" != "ok" ]; then
          fail "env-rules registered: $name needs \"Read(./.env.*)\" in permissions.deny and \"Read(!.env.example)\" after it, or .env.example is blocked or the variants are open"; reg "$h" wrong-order
        else
          reg "$h" ok
        fi ;;
      review-skill)
        fm="$(frontmatter "$k" 2>/dev/null | sed -E 's/[[:space:]]+$//')"
        if [ ! -f "$k" ] || [ "$fm" != "$SKILL_FM" ]; then
          fail "review-skill registered: the frontmatter of $(basename "$(dirname "$k")")/SKILL.md differs from the canonical text in selftest.sh (context: fork, agent: reviewer)"; reg "$h" not-forked
        else
          reg "$h" ok
        fi ;;
      selftest-start)
        sl="$(handler_refs "$s" SessionStart startup | grep -F "$PREFIX_TAIL/selftest.sh")"
        if [ -z "$sl" ]; then
          fail "selftest-start registered: does not run at session start according to $name, so nobody notices when a guard dies"; reg "$h" missing
        elif ! printf '%s\n' "$sl" | awk -F'|' -v a="$PREFIX/selftest.sh --quiet" 'NF == 5 && $2 == "false" && $3 == "-" && $4 == "bash" && $5 == a { ok = 1 } END { exit !ok }'; then
          fail "selftest-start registered: not the plain call 'bash $PREFIX/selftest.sh --quiet' (no async, no if filter) in $name"; reg "$h" not-plain
        else
          reg "$h" ok
        fi ;;
      config-guard)
        # Must run for all three sources a project can change.
        cl=""; miss=""
        for src in project_settings local_settings skills; do
          l="$(hook_lines "$(handler_refs "$s" ConfigChange "$src")" "$h")"
          [ -n "$l" ] || miss="$miss $src"
          cl="$cl
$l"
        done
        if [ -n "$miss" ]; then
          fail "$h registered: does not run on ConfigChange for$miss according to $name"; reg "$h" missing
        elif ! printf '%s\n' "$cl" | awk -F'|' -v c="$(canonical "$h")" 'NF && $4 != c { bad = 1 } END { exit bad }' \
          || ! plain_ok "$cl" yes; then
          fail "$h registered: not the plain blocking call '$(canonical "$h")' with args [] and \"onFailure\": \"block\" (no wrapper, async or if filter) in $name"; reg "$h" fail-open
        elif [ ! -x "$HOOK_DIR/$h.sh" ]; then
          fail "$h registered: $h.sh is not executable (chmod +x)"; reg "$h" not-executable
        else
          reg "$h" ok
        fi ;;
      recheck-guards)
        el="$(hook_lines "$(handler_refs "$s" PostToolUse Edit)" "$h")"
        wl="$(hook_lines "$(handler_refs "$s" PostToolUse Write)" "$h")"
        if [ -z "$el" ] || [ -z "$wl" ]; then
          fail "$h registered: does not run after Edit and Write according to $name"; reg "$h" missing
        elif ! printf '%s\n%s\n' "$el" "$wl" | awk -F'|' -v c="$(canonical "$h")" 'NF && $4 != c { bad = 1 } END { exit bad }' \
          || ! plain_ok "$el
$wl" no; then
          fail "$h registered: not the plain call '$(canonical "$h")' with args [] (no wrapper, async or if filter) in $name"; reg "$h" not-plain
        elif [ ! -x "$HOOK_DIR/$h.sh" ]; then
          fail "$h registered: $h.sh is not executable (chmod +x)"; reg "$h" not-executable
        else
          reg "$h" ok
        fi ;;
      *)
        bl="$(hook_lines "$bash_refs" "$h")"
        rl=""
        [ "$h" = "protect-secrets" ] && rl="$(hook_lines "$read_refs" "$h")"
        if [ -z "$bl" ]; then
          fail "$h registered: does not run before Bash commands according to $name (missing, wrong event or matcher, or disableAllHooks)"; reg "$h" missing
        elif [ "$h" = "protect-secrets" ] && [ -z "$rl" ]; then
          fail "$h registered: does not run before Read according to $name"; reg "$h" no-read
        elif ! printf '%s\n%s\n' "$bl" "$rl" | awk -F'|' -v c="$(canonical "$h")" 'NF && $4 != c { bad = 1 } END { exit bad }' \
          || ! plain_ok "$bl
$rl" yes; then
          fail "$h registered: not the plain blocking call '$(canonical "$h")' with args [] and \"onFailure\": \"block\" (no wrapper, async or if filter) in $name"; reg "$h" fail-open
        elif [ ! -x "$HOOK_DIR/$h.sh" ]; then
          fail "$h registered: $h.sh is not executable (chmod +x)"; reg "$h" not-executable
        else
          reg "$h" ok
        fi ;;
    esac
  done
}

# mkvariant <name> <mode>: a broken copy of the settings.
mkvariant() {
  case "$2" in
    twodocs) { cat "$SETTINGS"; printf '{}\n'; } > "$TMPROOT/$1.json"; return ;;
  esac
  if [ "$PARSER" = "jq" ]; then
    case "$2" in
      disable) jq '.disableAllHooks = true' "$SETTINGS" ;;
      post) jq '.hooks.PostToolUse = (.hooks.PreToolUse // []) | del(.hooks.PreToolUse)' "$SETTINGS" ;;
      failopen) jq 'del(.. | objects | .onFailure?)' "$SETTINGS" ;;
      async) jq '(.hooks[]?[]?.hooks[]? | select(.type == "command")) |= (.async = true)' "$SETTINGS" ;;
      iff) jq '(.hooks[]?[]?.hooks[]? | select(.type == "command")) |= (.if = "Bash(git status *)")' "$SETTINGS" ;;
      echo) jq '(.hooks[]?[]?.hooks[]? | select(.type == "command")) |= (.args = [.command] | .command = "/bin/echo")' "$SETTINGS" ;;
      shellform) jq '(.hooks[]?[]?.hooks[]? | select(.type == "command")) |= (.command = ("/bin/echo " + .command + " " + ((.args // []) | join(" "))) | del(.args))' "$SETTINGS" ;;
      noargs) jq '(.hooks[]?[]?.hooks[]? | select(.type == "command")) |= del(.args)' "$SETTINGS" ;;
      ifnull) jq '(.hooks[]?[]?.hooks[]? | select(.type == "command")) |= (.if = null)' "$SETTINGS" ;;
      cfgnarrow) jq '(.hooks.ConfigChange[]?.matcher) = "project_settings"' "$SETTINGS" ;;
      negfirst) jq '.permissions.deny = (["Read(!.env.example)"] + ((.permissions.deny // []) | map(select(. != "Read(!.env.example)"))))' "$SETTINGS" ;;
    esac > "$TMPROOT/$1.json"
  else
    python3 -c 'import json, sys
d = json.load(open(sys.argv[1])); mode = sys.argv[2]
if mode == "disable":
    d["disableAllHooks"] = True
elif mode == "post":
    h = d.setdefault("hooks", {})
    h["PostToolUse"] = h.pop("PreToolUse", [])
elif mode == "negfirst":
    p = d.setdefault("permissions", {})
    p["deny"] = ["Read(!.env.example)"] + [x for x in p.get("deny", []) if x != "Read(!.env.example)"]
elif mode == "cfgnarrow":
    for g in (d.get("hooks") or {}).get("ConfigChange") or []:
        g["matcher"] = "project_settings"
else:
    for groups in (d.get("hooks") or {}).values():
        for g in groups:
            for x in g.get("hooks") or []:
                if x.get("type") != "command": continue
                if mode == "failopen": x.pop("onFailure", None)
                elif mode == "async": x["async"] = True
                elif mode == "iff": x["if"] = "Bash(git status *)"
                elif mode == "echo": x["args"] = [x.get("command", "")]; x["command"] = "/bin/echo"
                elif mode == "shellform": x["command"] = " ".join(["/bin/echo", x.get("command", "")] + list(x.pop("args", []) or []))
                elif mode == "noargs": x.pop("args", None)
                elif mode == "ifnull": x["if"] = None
json.dump(d, open(sys.argv[3], "w"))' "$SETTINGS" "$2" "$TMPROOT/$1.json"
  fi
}

# mkagent <name> <mode>: a broken copy of the agent or skill file.
mkagent() {
  case "$2" in
    bash) sed -e 's/^tools:.*/tools: Read, Grep, Glob, Bash/' "$AGENT" > "$TMPROOT/$1.md" ;;
    writable) sed -e 's/^tools:.*/tools: Read, Grep, Glob, Edit, Write/' -e '/^disallowedTools:/d' "$AGENT" > "$TMPROOT/$1.md" ;;
    nodeny) sed -e '/^disallowedTools:/d' "$AGENT" > "$TMPROOT/$1.md" ;;
    indesc)
      # Both tool lines inside a quoted multi-line description: valid YAML
      # without the fields, so the subagent would inherit every tool.
      printf '%s\n' '---' 'name: reviewer' 'description: "Review with documented defaults:' \
        'tools: Read, Grep, Glob' 'disallowedTools: Bash, Edit, Write, NotebookEdit' '"' \
        'model: inherit' 'color: cyan' '---' > "$TMPROOT/$1.md"
      awk 'c >= 2 { print } /^---$/ { c++ }' "$AGENT" >> "$TMPROOT/$1.md" ;;
    nofork) grep -v '^context: fork' "$SKILL" > "$TMPROOT/$1.md" ;;
    otheragent) sed -e 's/^agent: reviewer/agent: general-purpose/' "$SKILL" > "$TMPROOT/$1.md" ;;
    # Cut off before the closing ---: Claude Code reads no fields and skips it.
    truncated) { printf '%s\n' '---'; frontmatter "$AGENT"; } > "$TMPROOT/$1.md" ;;
    # A later context: line overrides the fork.
    override) awk '{ print } /^background: false$/ { print "context: inline" }' "$SKILL" > "$TMPROOT/$1.md" ;;
  esac
}

ALLCHECKS="$GUARDS recheck-guards config-guard selftest-start reviewer review-skill"
# Permissions live in the project settings only; a plugin cannot carry them.
[ "$LAYOUT" = "project" ] && ALLCHECKS="$ALLCHECKS env-rules"
if [ -z "$SETTINGS" ]; then
  TOTAL=$((TOTAL + 1))
  fail "settings: no .claude/settings.json or settings.example.json found"
elif [ "$MODE" = "calibrate" ]; then
  # Broken configurations that a plain text search would call fine.
  for v in disable post failopen async iff echo shellform noargs ifnull twodocs cfgnarrow negfirst; do mkvariant "v-$v" "$v"; done
  for v in bash writable nodeny indesc truncated nofork otheragent override; do mkagent "a-$v" "$v"; done
  G="$GUARDS"
  # shellcheck disable=SC2086  # lists of check names, split on purpose
  {
    check_registered "$TMPROOT/v-disable.json" "$AGENT" "$SKILL" $G recheck-guards config-guard
    check_registered "$TMPROOT/v-post.json" "$AGENT" "$SKILL" $G recheck-guards
    check_registered "$TMPROOT/v-failopen.json" "$AGENT" "$SKILL" $G config-guard
    check_registered "$TMPROOT/v-async.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-iff.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-echo.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-shellform.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-noargs.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-ifnull.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-twodocs.json" "$AGENT" "$SKILL" $G recheck-guards config-guard selftest-start
    check_registered "$TMPROOT/v-cfgnarrow.json" "$AGENT" "$SKILL" config-guard
    [ "$LAYOUT" = "project" ] && check_registered "$TMPROOT/v-negfirst.json" "$AGENT" "$SKILL" env-rules
    check_registered "$SETTINGS" "$TMPROOT/a-bash.md" "$SKILL" reviewer
    check_registered "$SETTINGS" "$TMPROOT/a-writable.md" "$SKILL" reviewer
    check_registered "$SETTINGS" "$TMPROOT/a-nodeny.md" "$SKILL" reviewer
    check_registered "$SETTINGS" "$TMPROOT/a-indesc.md" "$SKILL" reviewer
    check_registered "$SETTINGS" "$AGENT" "$TMPROOT/a-nofork.md" review-skill
    check_registered "$SETTINGS" "$AGENT" "$TMPROOT/a-otheragent.md" review-skill
    check_registered "$SETTINGS" "$AGENT" "$TMPROOT/a-override.md" review-skill
    check_registered "$SETTINGS" "$TMPROOT/a-truncated.md" "$SKILL" reviewer
  }
else
  # shellcheck disable=SC2086
  check_registered "$SETTINGS" "$AGENT" "$SKILL" $ALLCHECKS
fi

# --- MCP configuration --------------------------------------------------------
# mcp_violations <file>: one line per problem, "rule:server:what". Only server
# names, field names and argument positions are printed, never a value: an
# argument can hold a URL with a password in it.
mcp_violations() {
  if [ "$PARSER" = "jq" ]; then
    # Closed forms, so anything unexpected fails instead of slipping through:
    # - a header or env entry whose name looks like a credential must be
    #   exactly ${NAME}, optionally after "Bearer ", "Basic " or "Token "
    #   (no default after :-, no literal text around it)
    # - npx/bunx/pnpx accept -y, --yes, -q, --quiet and -p/--package SPEC;
    #   uvx accepts -q, --quiet, --from SPEC and --with SPEC. Every package
    #   spec and the tool itself (unless -p or --from names the package) need
    #   an exact version. Any other option before the tool fails.
    # Regexes use \A and \z: in jq, ^ and $ also match around a newline.
    jq -r '
      def credname: test("authorization|token|key|secret|password|cookie|auth|credential|(^|_)pat$"; "i");
      def strictvar: test("\\A((Bearer|Basic|Token) )?\\$\\{[A-Za-z_][A-Za-z0-9_]*\\}\\z");
      def pinned: test("(@|==)[0-9]+\\.[0-9]+\\.[0-9]+([-+][0-9A-Za-z.-]+)?\\z");
      def runner: if test("(^|/)(npx|bunx|pnpx)\\z") then "npx" elif test("(^|/)uvx\\z") then "uvx" else null end;
      def scan($kind):
        reduce to_entries[] as $e ({main: null, specs: [], bad: [], want: false, from: false};
          ($e.value) as $a | ($e.key + 1) as $i |
          if .main != null then .
          elif .want then .specs += [{i: $i, v: $a}] | .want = false
          elif ($a == "-q" or $a == "--quiet") then .
          elif ($kind == "npx" and ($a == "-y" or $a == "--yes")) then .
          elif ($kind == "npx" and ($a == "-p" or $a == "--package")) then .want = true
          elif ($kind == "npx" and ($a | startswith("--package="))) then .specs += [{i: $i, v: ($a | sub("^--package="; ""))}]
          elif ($kind == "uvx" and ($a == "--from" or $a == "--with")) then .want = true | .from = (.from or $a == "--from")
          elif ($kind == "uvx" and ($a | test("\\A--(from|with)="))) then .specs += [{i: $i, v: ($a | sub("^--(from|with)="; ""))}] | .from = (.from or ($a | startswith("--from=")))
          elif ($a | startswith("-")) then .bad += [$i]
          else .main = {i: $i, v: $a} end);
      (.mcpServers // {}) | to_entries[] | .key as $n | .value as $s |
      ( (($s.headers // {}) | to_entries[] | select(.key | credname) | select((.value | strictvar) | not) | "secrets:\($n):header \(.key)"),
        (($s.env // {}) | to_entries[] | select(.key | credname) | select((.value | strictvar) | not) | "secrets:\($n):env \(.key)"),
        ((($s.command // "") | runner) as $k | select($k != null)
           | (($s.args // []) | scan($k)) as $r
           | ( ($r.bad[] | "pinned:\($n):argument \(.) is an unknown option"),
               (if $r.want then "pinned:\($n):last option has no value" else empty end),
               ($r.specs[] | select(.v | pinned | not) | "pinned:\($n):argument \(.i) has no exact version"),
               (if ($k == "npx" and ($r.specs | length) > 0) or ($k == "uvx" and $r.from) then empty
                elif $r.main == null then "pinned:\($n):no package"
                elif ($r.main.v | pinned) then empty
                else "pinned:\($n):argument \($r.main.i) has no exact version" end) )),
        (select($s.url != null)
           | select(($s.url | test("\\Ahttps://|\\Ahttp://(localhost|127\\.0\\.0\\.1)(:|/|\\z)")) | not)
           | "https:\($n):url") )' "$1" 2>/dev/null
  else
    python3 -c 'import json, re, sys
d = json.load(open(sys.argv[1]))
cred = re.compile(r"authorization|token|key|secret|password|cookie|auth|credential|(^|_)pat$", re.I)
strict = re.compile(r"((Bearer|Basic|Token) )?\$\{[A-Za-z_][A-Za-z0-9_]*\}")
pin = re.compile(r"(@|==)[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?\Z")
for n, s in d["mcpServers"].items():
    for where in ("headers", "env"):
        for k, v in (s.get(where) or {}).items():
            if cred.search(k) and not strict.fullmatch(v):
                print("secrets:%s:%s %s" % (n, "header" if where == "headers" else "env", k))
    cmd = s.get("command") or ""
    kind = "npx" if re.search(r"(^|/)(npx|bunx|pnpx)\Z", cmd) else "uvx" if re.search(r"(^|/)uvx\Z", cmd) else None
    if kind:
        main, specs, bad, want, frm = None, [], [], False, False
        for i, a in enumerate(s.get("args") or [], 1):
            if main is not None: break
            if want: specs.append((i, a)); want = False
            elif a in ("-q", "--quiet"): pass
            elif kind == "npx" and a in ("-y", "--yes"): pass
            elif kind == "npx" and a in ("-p", "--package"): want = True
            elif kind == "npx" and a.startswith("--package="): specs.append((i, a[len("--package="):]))
            elif kind == "uvx" and a in ("--from", "--with"): want = True; frm = frm or a == "--from"
            elif kind == "uvx" and re.match(r"--(from|with)=", a): specs.append((i, a.split("=", 1)[1])); frm = frm or a.startswith("--from=")
            elif a.startswith("-"): bad.append(i)
            else: main = (i, a)
        for b in bad: print("pinned:%s:argument %d is an unknown option" % (n, b))
        if want: print("pinned:%s:last option has no value" % n)
        for i, sp in specs:
            if not pin.search(sp): print("pinned:%s:argument %d has no exact version" % (n, i))
        if (kind == "npx" and specs) or (kind == "uvx" and frm): pass
        elif main is None: print("pinned:%s:no package" % n)
        elif not pin.search(main[1]): print("pinned:%s:argument %d has no exact version" % (n, main[0]))
    u = s.get("url")
    if u is not None and not re.match(r"https://|http://(localhost|127\.0\.0\.1)(:|/|\Z)", u):
        print("https:%s:url" % n)' "$1" 2>/dev/null
  fi
}

# mcp_valid <file>: exactly one JSON document, an object mcpServers of
# objects, and every field the checks read has the expected type (strings,
# a list of strings, objects of strings). Otherwise the checks above could
# stop halfway and report nothing.
mcp_valid() {
  if [ "$PARSER" = "jq" ]; then
    jq -s -e '
      length == 1 and (.[0] | type == "object") and (.[0].mcpServers | type == "object")
      and ([.[0].mcpServers[] |
        type == "object"
        and ((has("command") | not) or (.command | type == "string"))
        and ((has("url") | not) or (.url | type == "string"))
        and ((has("args") | not) or (.args | type == "array" and all(.[]; type == "string")))
        and ((has("headers") | not) or (.headers | type == "object" and all(.[]; type == "string")))
        and ((has("env") | not) or (.env | type == "object" and all(.[]; type == "string")))] | all)' "$1" >/dev/null 2>&1
  else
    python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
def ok(s):
    return (isinstance(s, dict)
        and isinstance(s.get("command", ""), str) and isinstance(s.get("url", ""), str)
        and isinstance(s.get("args", []), list) and all(isinstance(a, str) for a in s.get("args", []))
        and all(isinstance(s.get(f, {}), dict) and all(isinstance(v, str) for v in s.get(f, {}).values()) for f in ("headers", "env")))
m = d.get("mcpServers") if isinstance(d, dict) else None
sys.exit(0 if isinstance(m, dict) and all(ok(s) for s in m.values()) else 1)' "$1" >/dev/null 2>&1
  fi
}

MCP_STATUS=""
# check_mcp <file> [rules...]: one check per rule (default: all four).
# A file that does not parse fails every rule it was asked for: nothing in it
# was checked.
check_mcp() {
  f="$1"; shift
  [ $# -gt 0 ] || set -- valid secrets pinned https
  ok_json=0; v=""
  if mcp_valid "$f"; then
    # A checker that stops halfway has not checked the rest: count as failed.
    if v="$(mcp_violations "$f")"; then ok_json=1; else v=""; fi
  fi
  for rule in "$@"; do
    TOTAL=$((TOTAL + 1))
    if [ "$ok_json" -eq 0 ]; then
      fail "mcp $rule: $(basename "$f") is not one valid JSON document with the expected fields, or the check stopped, nothing was checked"
      MCP_STATUS="$MCP_STATUS $rule:FAIL"
      continue
    fi
    [ "$rule" = "valid" ] && { MCP_STATUS="$MCP_STATUS valid:ok"; continue; }
    hits="$(printf '%s\n' "$v" | grep "^$rule:" | cut -d: -f2- | tr '\n' ' ')"
    if [ -n "$hits" ]; then
      case "$rule" in
        secrets) fail "mcp secrets: credential not given as \${VAR} in $hits" ;;
        pinned) fail "mcp pinned: no exact version or unknown option in $hits" ;;
        https) fail "mcp https: plain http for $hits" ;;
      esac
      MCP_STATUS="$MCP_STATUS $rule:FAIL"
    else
      MCP_STATUS="$MCP_STATUS $rule:ok"
    fi
  done
}

if [ "$MODE" = "calibrate" ]; then
  # Literal token, @latest, plain http.
  cat > "$TMPROOT/broken-a.mcp.json" <<'JSON'
{"mcpServers": {
  "leaky": {"type": "http", "url": "http://mcp.example.com/mcp",
            "headers": {"Authorization": "Bearer not-a-real-value"}},
  "floating": {"command": "npx", "args": ["-y", "@example/server@latest"]}
}}
JSON
  # A literal default behind a variable, and a pinned extra with an unpinned tool.
  cat > "$TMPROOT/broken-b.mcp.json" <<'JSON'
{"mcpServers": {
  "defaulted": {"command": "node", "args": ["server.js"],
                "env": {"EXAMPLE_API_KEY": "${EXAMPLE_API_KEY:-not-a-real-value}"}},
  "extra": {"command": "uvx", "args": ["--with", "requests==2.32.3", "ruff"]}
}}
JSON
  # Unknown option before the package, and a truncated file.
  cat > "$TMPROOT/broken-c.mcp.json" <<'JSON'
{"mcpServers": {"odd": {"command": "npx", "args": ["--prefer-online", "@example/server@1.0.0"]}}}
JSON
  printf '{"mcpServers":' > "$TMPROOT/broken-d.mcp.json"
  # A wrong field type, two documents in one file, a newline after ${VAR}.
  printf '{"mcpServers": {"t": {"command": "npx", "args": [false]}}}\n' > "$TMPROOT/broken-e.mcp.json"
  printf '{"mcpServers": {}}\n{"mcpServers": {}}\n' > "$TMPROOT/broken-f.mcp.json"
  printf '{"mcpServers": {"nl": {"type": "http", "url": "https://a.example/mcp", "headers": {"Authorization": "${A_TOKEN}\\n"}}}}\n' > "$TMPROOT/broken-g.mcp.json"
  check_mcp "$TMPROOT/broken-a.mcp.json" secrets pinned https
  check_mcp "$TMPROOT/broken-b.mcp.json" secrets pinned
  check_mcp "$TMPROOT/broken-c.mcp.json" pinned
  check_mcp "$TMPROOT/broken-d.mcp.json" valid
  check_mcp "$TMPROOT/broken-e.mcp.json" valid
  check_mcp "$TMPROOT/broken-f.mcp.json" valid
  check_mcp "$TMPROOT/broken-g.mcp.json" secrets
  # Present but null or false: a jq default (//) would hide these.
  printf '{"mcpServers": {"n": {"command": null, "args": false, "env": null}}}\n' > "$TMPROOT/broken-h.mcp.json"
  check_mcp "$TMPROOT/broken-h.mcp.json" valid
else
  [ -n "$MCP" ] && check_mcp "$MCP"
  # The report names fields and argument positions, never values: a canary
  # placed in every kind of field must not appear in the checker's output.
  canary="selftest-canary-$$"
  cat > "$TMPROOT/leak.mcp.json" <<JSON
{"mcpServers": {
  "a": {"type": "http", "url": "http://user:$canary@mcp.example/mcp", "headers": {"Authorization": "Bearer $canary"}},
  "b": {"command": "uvx", "args": ["--index-url", "https://user:$canary@registry.example/simple", "server==1.2.3"]},
  "c": {"command": "npx", "args": ["-y", "@example/$canary"], "env": {"EXAMPLE_TOKEN": "$canary"}},
  "d": {"command": "uvx", "args": ["--with", "pkg-$canary", "tool==1.0.0"]}
}}
JSON
  TOTAL=$((TOTAL + 1))
  leak_out="$(mcp_violations "$TMPROOT/leak.mcp.json")"
  if [ -z "$leak_out" ] || printf '%s' "$leak_out" | grep -q "$canary"; then
    fail "mcp no-leak: the MCP check printed a field value, or found nothing in a config full of problems"
    MCP_STATUS="$MCP_STATUS no-leak:FAIL"
  else
    MCP_STATUS="$MCP_STATUS no-leak:ok"
  fi
fi

# --- protect-secrets ----------------------------------------------------------
H=protect-secrets
expect_block $H Bash command 'cat .env'
expect_block $H Bash command 'head -n 5 config/.env.production'
expect_block $H Bash command 'grep API_KEY .env'
expect_block $H Bash command 'printenv'
expect_block $H Bash command 'env | sort'
expect_block $H Bash command 'echo $OPENAI_API_KEY'
expect_block $H Bash command 'op read "op://vault/item/field"'
expect_block $H Bash command 'security find-generic-password -s example -w'
expect_block $H Bash command 'aws secretsmanager get-secret-value --secret-id example'
expect_block $H Bash command 'while read l; do echo "$l"; done < .env'
expect_block $H Bash command 'git -C . show HEAD:.env'
expect_block $H Bash command 'bash -c "cat ~/.ssh/id_ed25519"'
expect_block $H Bash command 'cat .env.development.local'
expect_block $H Read file_path '/repo/.env'
expect_block $H Read file_path '/repo/.env.production.local'
expect_block $H Read file_path '/home/user/.aws/credentials'
expect_pass  $H Bash command 'test -f .env && echo present'
expect_pass  $H Bash command "grep -c '^API_KEY=' .env"
expect_pass  $H Bash command 'cut -d= -f1 .env'
expect_pass  $H Bash command 'echo "${#API_KEY}"'
expect_pass  $H Bash command 'cp .env.example .env'
expect_pass  $H Bash command 'cat .env.example'
expect_pass  $H Bash command 'cat ~/.ssh/id_ed25519.pub'
expect_pass  $H Bash command 'npm test'
expect_pass  $H Read file_path '/repo/README.md'
expect_pass  $H Read file_path '/repo/.env.example'

# --- guard-git ----------------------------------------------------------------
H=guard-git
expect_block $H Bash command 'git push --force origin feature/login'
expect_block $H Bash command 'git push -f'
expect_block $H Bash command 'git -C . push origin +feature/login'
expect_block $H Bash command 'git push origin main'
expect_block $H Bash command 'git push origin HEAD:master'
expect_block $H Bash command 'git push' "$REPO_MAIN"
expect_block $H Bash command 'git push origin HEAD' "$REPO_MAIN"
expect_block $H Bash command 'git reset --hard HEAD~1'
expect_block $H Bash command 'git clean -fdx'
expect_block $H Bash command 'git checkout -- .'
expect_block $H Bash command 'git restore .'
expect_block $H Bash command 'git branch -D old-feature'
expect_block $H Bash command 'git stash drop'
expect_block $H Bash command 'npm test && git push --force-with-lease'
expect_block $H Bash command 'git push origin "HEAD:main"'
expect_block $H Bash command "git -C $REPO_MAIN push" "$REPO_FEATURE"
expect_block $H Bash command 'git branch -df feature/old'
expect_pass  $H Bash command 'git status'
expect_pass  $H Bash command 'git push -u origin feature/login' "$REPO_FEATURE"
expect_pass  $H Bash command 'git push' "$REPO_FEATURE"
expect_pass  $H Bash command 'git commit -m "fix: reset form on submit"'
expect_pass  $H Bash command 'git restore --staged .'
expect_pass  $H Bash command 'git branch -d merged-feature'
expect_pass  $H Bash command 'git log --oneline -5'
expect_pass  $H Bash command 'git push origin feature/main-menu' "$REPO_FEATURE"
expect_pass  $H Bash command "git -C $REPO_FEATURE push" "$REPO_MAIN"

# --- block-external-send ------------------------------------------------------
H=block-external-send
expect_block $H Bash command 'sendmail client@example.com < draft.txt'
expect_block $H Bash command "printf 'Subject: Hi' | msmtp client@example.com"
expect_block $H Bash command 'curl -X POST https://api.resend.com/emails -d @mail.json'
expect_block $H Bash command "curl -s https://hooks.slack.com/services/T000/B000/XXXX -d '{\"text\":\"done\"}'"
expect_block $H Bash command "python3 -c \"import smtplib; smtplib.SMTP('smtp.example.com')\""
expect_block $H Bash command "osascript -e 'tell application \"Mail\" to send (first outgoing message)'"
expect_block $H Bash command 'npm publish'
expect_block $H Bash command 'gh release create v1.0.0'
expect_block $H Bash command 'docker push registry.example.com/app:1.0'
expect_block $H Bash command 'python3 -m twine upload dist/*'
expect_block $H Bash command 'docker buildx build --push -t example/app .'
expect_block $H Bash command 'vercel deploy --target production'
expect_pass  $H Bash command 'git commit -m "docs: explain why agents never sendmail"'
expect_pass  $H Bash command "osascript -e 'tell application \"Mail\" to make new outgoing message with properties {subject:\"Draft\"}'"
expect_pass  $H Bash command 'npm run build'
expect_pass  $H Bash command 'curl -s https://api.github.com/repos/example/example'
expect_pass  $H Bash command 'docker build -t app .'
expect_pass  $H Bash command 'echo "draft saved to drafts/reply.md"'
expect_pass  $H Bash command 'curl -s https://api.resend.com/domains'
expect_pass  $H Bash command 'rg nodemailer src'
expect_pass  $H Bash command 'npm publish --dry-run'
expect_pass  $H Bash command 'gh release create v1.0.0 --draft'
expect_pass  $H Bash command 'docker buildx build -t example/app .'

# --- recheck-guards -----------------------------------------------------------
H=recheck-guards
HOOK_FILE="$TMPROOT/recheck-guards-red/recheck-guards.sh"
expect_block $H Edit file_path '/repo/.claude/hooks/guard-git.sh'
expect_block $H Write file_path '/repo/.claude/settings.json'
expect_block $H Write file_path '/repo/.claude/settings.local.json'
expect_block $H Edit file_path '/repo/.claude/agents/reviewer.md'
expect_block $H Edit file_path '/repo/.claude/skills/pre-merge-review/SKILL.md'
expect_block $H Edit file_path '/repo/.claude/rules/guards.md'
expect_block $H Write file_path '/repo/.mcp.json'
expect_pass  $H Edit file_path '/repo/src/app.ts'
expect_pass  $H Write file_path '/repo/README.md'
HOOK_FILE="$TMPROOT/recheck-guards-crash/recheck-guards.sh"
expect_block $H Edit file_path '/repo/.claude/hooks/protect-secrets.sh'
HOOK_FILE="$TMPROOT/recheck-guards-green/recheck-guards.sh"
expect_pass  $H Edit file_path '/repo/.claude/hooks/guard-git.sh'
expect_pass  $H Write file_path '/repo/.claude/settings.json'
HOOK_FILE=""

# --- config-guard -------------------------------------------------------------
H=config-guard
HOOK_FILE="$TMPROOT/config-guard-red/config-guard.sh"
expect_block $H ConfigChange project_settings '/repo/.claude/settings.json'
expect_block $H ConfigChange skills '/repo/.claude/skills/pre-merge-review/SKILL.md'
expect_block $H ConfigChange local_settings "$TMPROOT/proj2/.claude/settings.local.json"
expect_pass  $H ConfigChange user_settings '/home/user/.claude/settings.json'
expect_pass  $H ConfigChange policy_settings '/etc/claude-code/managed-settings.json'
HOOK_FILE="$TMPROOT/config-guard-crash/config-guard.sh"
expect_block $H ConfigChange project_settings '/repo/.claude/settings.json'
HOOK_FILE="$TMPROOT/config-guard-green/config-guard.sh"
expect_block $H ConfigChange local_settings "$TMPROOT/proj/.claude/settings.local.json"
expect_pass  $H ConfigChange local_settings "$TMPROOT/proj2/.claude/settings.local.json"
expect_pass  $H ConfigChange project_settings '/repo/.claude/settings.json'
expect_pass  $H ConfigChange skills '/repo/.claude/skills/pre-merge-review/SKILL.md'
# file_path is optional in ConfigChange: the guard reads both settings files
# of the project itself (from CLAUDE_PROJECT_DIR, else the payload's cwd).
expect_block_raw $H "no file_path and no cwd" '{"hook_event_name":"ConfigChange","source":"local_settings"}'
expect_block $H ConfigChange local_settings '' "$TMPROOT/proj"
HOOK_PROJECT="$TMPROOT/proj"
expect_block $H ConfigChange local_settings ''
HOOK_PROJECT=""
expect_block $H ConfigChange project_settings '' "$TMPROOT/proj3"
expect_block $H ConfigChange local_settings '' "$TMPROOT/proj4"
expect_pass  $H ConfigChange local_settings '' "$TMPROOT/proj2"
HOOK_FILE=""

# --- every guard blocks when it cannot read its input -------------------------
# Without jq and python3, or with a jq that fails, a guard would see an empty
# command and exit 0; require_parser and require_payload make it block.
for bin in noparser-bin brokenjq-bin; do
  HOOK_PATH="$TMPROOT/$bin"
  expect_block protect-secrets Bash command 'cat .env'
  expect_block guard-git Bash command 'git push --force'
  expect_block block-external-send Bash command 'npm publish'
  expect_block config-guard ConfigChange project_settings '/repo/.claude/settings.json'
done
# Each document alone would pass; two of them must not be read as one call.
ONE_DOC='{"tool_name":"Bash","tool_input":{"command":"ls"},"source":"skills"}'
TWO_DOCS="$ONE_DOC $ONE_DOC"
HOOK_PATH=""
for guard_name in protect-secrets guard-git block-external-send config-guard; do
  expect_block_raw "$guard_name" "input that is not JSON" 'not json {'
  expect_block_raw "$guard_name" "empty input" ''
  expect_block_raw "$guard_name" "two JSON documents" "$TWO_DOCS"
  expect_block_raw "$guard_name" "a JSON value that is not an object" 'false {}'
done
for guard_name in protect-secrets guard-git block-external-send; do
  expect_block_raw "$guard_name" "a command that is a number" '{"tool_name":"Bash","tool_input":{"command":7}}'
  expect_block_raw "$guard_name" "tool_input that is a number" '{"tool_name":"Bash","tool_input":7}'
  expect_block_raw "$guard_name" "no command" '{"tool_name":"Bash","tool_input":{}}'
done
expect_block_raw protect-secrets "no file_path for Read" '{"tool_name":"Read","tool_input":{}}'
expect_block_raw protect-secrets "a file_path that is an object" '{"tool_name":"Read","tool_input":{"file_path":{}}}'
for guard_name in protect-secrets guard-git block-external-send; do
  expect_block_raw "$guard_name" "a tool_name that is a number" '{"tool_name":7,"tool_input":{"command":"ls"}}'
  expect_block_raw "$guard_name" "a tool_name that is false" '{"tool_name":false,"tool_input":{"command":"ls"}}'
  HOOK_FILE="$TMPROOT/$guard_name-noend/$guard_name.sh"
  expect_block "$guard_name" Bash command 'ls'
  HOOK_FILE=""
done
expect_block_raw config-guard "a source that is a number" '{"hook_event_name":"ConfigChange","source":7}'

# --- report -------------------------------------------------------------------
if [ "$MODE" = "calibrate" ]; then
  if [ "$FAILED" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    echo "calibration ok: all $TOTAL broken cases were reported (violations against a stub hook that blocks nothing, broken settings and agent files, a broken MCP config)."
    exit 0
  fi
  echo "calibration FAILED: only $FAILED of $TOTAL broken cases were reported. The selftest cannot tell a dead guard from a live one."
  exit 1
fi

if [ "$MODE" = "quiet" ]; then
  if [ "$FAILED" -gt 0 ]; then
    echo "WARNING from .claude/hooks/selftest.sh: $FAILED of $TOTAL guard checks failed. Tell the user before relying on the guards."
    printf '%s' "$FAIL_LINES" | head -5
  fi
  exit 0
fi

printf '%-22s %-11s %-6s %s\n' "Check" "Axis" "Result" "Detail"
for h in $HOOKS; do
  # shellcheck disable=SC2086  # one word per status entry, split on purpose
  reg="$(printf '%s\n' $REG_STATUS | grep "^$h:" | cut -d: -f2)"
  [ "$reg" = "ok" ] && r="ok" || r="FAIL"
  printf '%-22s %-11s %-6s %s\n' "$h" "registered" "$r" "${reg:-?} in $(basename "${SETTINGS:-settings}")"
  so="$(count "$h" speaks_ok)"; st="$(count "$h" speaks_total)"
  [ "$so" = "$st" ] && r="ok" || r="FAIL"
  printf '%-22s %-11s %-6s %s\n' "$h" "speaks" "$r" "$so of $st violations blocked"
  po="$(count "$h" silent_ok)"; pt="$(count "$h" silent_total)"
  [ "$po" = "$pt" ] && r="ok" || r="FAIL"
  printf '%-22s %-11s %-6s %s\n' "$h" "silent" "$r" "$po of $pt harmless commands passed"
done
for c in selftest-start reviewer review-skill $( [ "$LAYOUT" = "project" ] && echo env-rules ); do
  # shellcheck disable=SC2086  # one word per status entry, split on purpose
  reg="$(printf '%s\n' $REG_STATUS | grep "^$c:" | cut -d: -f2)"
  [ "$reg" = "ok" ] && r="ok" || r="FAIL"
  case "$c" in
    selftest-start) where="$(basename "${SETTINGS:-settings}") SessionStart" ;;
    reviewer) where="agents/$(basename "$AGENT")" ;;
    env-rules) where="$(basename "${SETTINGS:-settings}") permissions.deny" ;;
    *) where="skills/pre-merge-review" ;;
  esac
  printf '%-22s %-11s %-6s %s\n' "$c" "registered" "$r" "${reg:-?} in $where"
done
[ -n "$MCP" ] || printf '%-22s %-11s %-6s %s\n' "mcp-config" "-" "skip" "no .mcp.json or .mcp.json.example"
for entry in $MCP_STATUS; do
  where="$(basename "${MCP:-none}")"
  [ "${entry%%:*}" = "no-leak" ] && where="canary fixture"
  printf '%-22s %-11s %-6s %s\n' "mcp-config" "${entry%%:*}" "${entry##*:}" "$where"
done
echo "Parser: $PARSER. Interpreter: ${RUNNER:-shebang ($(command -v bash))}."

# onFailure is ignored by Claude Code before $ONFAILURE_MIN. Informational:
# the CLI is not installed everywhere this test runs (CI, a fresh machine).
if command -v claude >/dev/null 2>&1; then
  cv="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -n "$cv" ] && [ "$(printf '%s\n%s\n' "$ONFAILURE_MIN" "$cv" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" != "$ONFAILURE_MIN" ]; then
    echo "Note: Claude Code $cv ignores \"onFailure\": \"block\" (needs $ONFAILURE_MIN or newer). Update, or a crashing guard lets everything through."
  else
    echo "Claude Code: ${cv:-unknown version} (onFailure needs $ONFAILURE_MIN or newer)."
  fi
fi

if [ "$FAILED" -gt 0 ]; then
  echo
  printf '%s' "$FAIL_LINES"
  echo "Result: $FAILED of $TOTAL checks failed."
  exit 1
fi
echo "Result: all $TOTAL checks passed."
exit 0
