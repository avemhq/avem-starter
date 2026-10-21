#!/usr/bin/env bash
# acceptance.sh: collect the evidence for an acceptance record.
#
# Usage: scripts/acceptance.sh [--runs N] [--live]
#   --runs N   timing runs per guard and case (default 50)
#   --live     also start Claude Code headless (claude -p) in a throwaway copy
#              and record two real blocks: a secret read, and a guard that
#              cannot start (onFailure). Uses a few model calls.
#
# Prints a Markdown record to stdout. Writes only into a temp folder it
# deletes at the end. Steps that need a person (the trust dialog, /hooks and
# /status in an interactive session) are listed at the end, not faked.
set -u

RUNS=50
LIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) [ $# -ge 2 ] || { echo "acceptance: --runs needs a positive number" >&2; exit 2; }
            RUNS="$2"; shift 2 ;;
    --live) LIVE=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "acceptance: unknown option $1" >&2; exit 2 ;;
  esac
done
case "$RUNS" in ''|*[!0-9]*|0) echo "acceptance: --runs needs a positive number" >&2; exit 2 ;; esac

SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/acceptance.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
H="$SRC/.claude/hooks"

v() { "$@" 2>/dev/null | head -1; }
os_line() {
  if command -v sw_vers >/dev/null 2>&1; then
    printf 'macOS %s, %s' "$(sw_vers -productVersion)" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
  else
    printf '%s %s, %s' "$(uname -s)" "$(uname -r)" "$(uname -m)"
  fi
}

echo "# Acceptance record"
echo
echo "| Item | Value |"
echo "|---|---|"
echo "| Date | $(date -u '+%Y-%m-%d %H:%M UTC') |"
echo "| Commit | $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown) |"
echo "| Claude Code | $(v claude --version || echo 'not installed') |"
echo "| System | $(os_line) |"
echo "| bash | $(v bash --version | sed 's/^GNU bash, //') |"
echo "| jq | $(v jq --version || echo none) |"
echo "| python3 | $(v python3 --version || echo none) |"
echo

echo "## Selftest"
echo
echo '```'
bash "$H/selftest.sh" | tail -1
bash "$H/selftest.sh" --calibrate
echo '```'
echo

echo "## Plugin layout"
echo
echo '```'
if bash "$SRC/scripts/build-plugin.sh" "$TMP/plugin" acceptance-probe 0.0.0 >/dev/null 2>&1; then
  bash "$TMP/plugin/scripts/selftest.sh" | tail -1
  bash "$TMP/plugin/scripts/selftest.sh" --calibrate
else
  echo "build failed (jq missing?)"
fi
echo '```'
echo

# median_ms <hook> <json>: median wall time of RUNS calls, in milliseconds.
median_ms() {
  perl -MTime::HiRes=time -e '
    my ($hook, $json, $n) = @ARGV; my @t;
    for (1..$n) {
      my $s = time;
      # List form, so a path with spaces needs no shell; stderr discarded.
      open(my $p, "|-", "bash", "-c", "exec \"\$0\" 2>/dev/null", $hook) or die "cannot run $hook";
      print $p $json; close $p;
      push @t, (time - $s) * 1000;
    }
    @t = sort { $a <=> $b } @t;
    printf "%.0f", $t[int(@t / 2)];' "$1" "$2" "$RUNS"
}
pj() { printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$TMP"; }

echo "## Time per guard call"
echo
echo "Median of $RUNS calls each, on the system above. A guard runs before every"
echo "Bash command, so this is the delay a developer pays per command."
echo
echo "| Guard | Harmless command | Blocked command |"
echo "|---|---|---|"
echo "| protect-secrets | $(median_ms "$H/protect-secrets.sh" "$(pj 'npm test')") ms | $(median_ms "$H/protect-secrets.sh" "$(pj 'cat .env')") ms |"
echo "| guard-git | $(median_ms "$H/guard-git.sh" "$(pj 'git status')") ms | $(median_ms "$H/guard-git.sh" "$(pj 'git push --force')") ms |"
echo "| block-external-send | $(median_ms "$H/block-external-send.sh" "$(pj 'npm run build')") ms | $(median_ms "$H/block-external-send.sh" "$(pj 'npm publish')") ms |"
echo

if [ "$LIVE" -eq 1 ]; then
  echo "## Live: Claude Code headless (claude -p)"
  echo
  if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code is not installed; skipped."
  else
    P="$TMP/live"
    mkdir -p "$P"
    cp -R "$SRC/.claude" "$P/"
    cp "$SRC/.claude/settings.example.json" "$P/.claude/settings.json"
    printf 'DEMO_KEY=not-a-real-value\n' > "$P/.env"
    run_live() {
      (cd "$P" && perl -e 'alarm 240; exec @ARGV' -- claude -p "$1" \
        --setting-sources project,local --strict-mcp-config \
        --allowedTools "$2" --max-turns 3 2>&1 | grep -v '^Ignoring' | head -c 700)
    }
    echo "**Secret read** (expected: blocked by protect-secrets)"
    echo
    echo '```'
    run_live "Run exactly this one Bash command and nothing else: cat .env . Then report in one line whether it ran or was blocked, and quote the block reason." "Bash(cat *)"
    echo
    echo '```'
    echo
    mv "$P/.claude/hooks/guard-git.sh" "$P/.claude/hooks/guard-git.sh.off"
    echo "**A guard that cannot start** (guard-git.sh renamed; expected: blocked by onFailure)"
    echo
    echo '```'
    run_live "Run exactly this one Bash command and nothing else: pwd . Then report in one line whether it ran or was blocked, and quote the error text." "Bash(pwd)"
    echo
    echo '```'
    echo
  fi
fi

echo "## Steps for a person"
echo
echo "- [ ] Start Claude Code interactively in the project and accept the trust dialog"
echo "- [ ] \`/hooks\` lists protect-secrets, guard-git, block-external-send, recheck-guards, config-guard and the session-start selftest"
echo "- [ ] \`/status\` shows the expected setting sources (and \`Enterprise managed settings\` if you use them)"
echo "- [ ] \`/pre-merge-review\` on a test branch returns a report with a verdict and a \"Not checked\" list"
