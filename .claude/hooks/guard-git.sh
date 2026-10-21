#!/usr/bin/env bash
# guard-git.sh: PreToolUse hook for Bash.
#
# Stops git commands that destroy work or rewrite shared history, so an agent
# cannot do them on its own:
#   force push, push --mirror, deleting a remote branch, pushing straight to a
#   protected branch (also a bare "git push" while on one), reset --hard,
#   clean -f, checkout -- . and restore . (discard all local changes),
#   branch -D, stash drop / clear, filter-branch / filter-repo.
#
# Everything else passes. If one of these is really intended, the user runs it
# in a terminal. That is the point: the human makes irreversible moves.
#
# Protected branches: GUARD_GIT_PROTECTED (space separated), default "main master".
# Global options such as "git -C path" and "git -c key=value" are skipped, so
# "git -C . push --force" is caught as well.
set +x

HOOK="guard-git"
# shellcheck source=SCRIPTDIR/_common.sh
. "$(dirname "$0")/_common.sh" || { printf "Blocked by %s: helper _common.sh could not be loaded.\n" "$HOOK" >&2; exit 2; }
require_parser "$HOOK"

PROTECTED="${GUARD_GIT_PROTECTED:-main master}"
HINT='If this is intended, the user runs it in a terminal. For shared branches, open a pull request instead.'

payload="$(read_payload)"
require_input "$HOOK" "$payload"
require_payload "$HOOK" "$payload" tool_name
[ "$(printf '%s' "$payload" | json_get tool_name)" = "Bash" ] || exit 0
require_string "$HOOK" "$payload" tool_input.command
cmd="$(printf '%s' "$payload" | json_get tool_input.command)"
[ -n "$cmd" ] || exit 0
cwd="$(printf '%s' "$payload" | json_get cwd)"

has() { printf ' %s ' "$1" | grep -Eq -- "$2"; }

segs="$(printf '%s\n' "$cmd" | segments)"
seen_end=0
while IFS= read -r seg; do
  if [ "$seg" = "$END_MARK" ]; then seen_end=1; continue; fi
  [ -n "$seg" ] || continue
  prog="${seg%%[[:space:]]*}"
  [ "${prog##*/}" = "git" ] || continue

  # Word split on purpose, quote characters removed: "HEAD:main" and
  # HEAD:main must look the same (see the limits in _common.sh).
  set -f
  # shellcheck disable=SC2046
  set -- $(printf '%s' "$seg" | tr -d "\"'")
  set +f
  shift
  # The repository git acts on: the session directory, moved by -C like git does.
  repo="$cwd"
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        if [ $# -ge 2 ]; then
          case "$2" in
            /*) repo="$2" ;;
            *) repo="${repo:+$repo/}$2" ;;
          esac
          shift 2
        else
          shift
        fi ;;
      -c|--git-dir|--work-tree|--namespace)
        if [ $# -ge 2 ]; then shift 2; else shift; fi ;;
      --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--no-pager|--paginate|-p|-P|--bare|--no-replace-objects|--literal-pathspecs|--no-optional-locks)
        shift ;;
      *) break ;;
    esac
  done
  sub="${1:-}"
  if [ $# -gt 0 ]; then shift; fi
  rest="$*"

  case "$sub" in
    push)
      if has "$rest" '[[:space:]](--force|--force-with-lease(=[^[:space:]]*)?|--force-if-includes|--mirror|--delete|--prune)[[:space:]]|[[:space:]]-[A-Za-z]*[fd][A-Za-z]*[[:space:]]|[[:space:]][+:][^[:space:]]+'; then
        block "$HOOK" "git push that rewrites or deletes remote history." "$HINT"
      fi
      for b in $PROTECTED; do
        if has "$rest" "[[:space:]:/]${b}[[:space:]]"; then
          block "$HOOK" "direct push to protected branch '$b'." "$HINT"
        fi
      done
      # Bare "git push", "git push origin" or "git push origin HEAD":
      # the target is the current branch.
      nonflag=0
      for a in $rest; do
        case "$a" in -*) ;; *) nonflag=$((nonflag + 1)) ;; esac
      done
      if { [ "$nonflag" -le 1 ] || has "$rest" '[[:space:]]HEAD[[:space:]]'; } && [ -n "$repo" ] && [ -d "$repo" ]; then
        current="$(git -C "$repo" branch --show-current 2>/dev/null)"
        for b in $PROTECTED; do
          if [ "$current" = "$b" ]; then
            block "$HOOK" "push while on protected branch '$b'." "$HINT"
          fi
        done
      fi ;;
    reset)
      if has "$rest" '[[:space:]]--hard[[:space:]]'; then
        block "$HOOK" "git reset --hard discards uncommitted work." "$HINT"
      fi ;;
    clean)
      if has "$rest" '[[:space:]](-[A-Za-z]*f[A-Za-z]*|--force)[[:space:]]'; then
        block "$HOOK" "git clean -f deletes untracked files for good." "$HINT"
      fi ;;
    checkout)
      if has "$rest" '[[:space:]]--[[:space:]]+(\.|:/)[[:space:]]|^[[:space:]]+(\.|:/)[[:space:]]+$'; then
        block "$HOOK" "git checkout of the whole tree discards all local changes." "$HINT"
      fi ;;
    restore)
      if has "$rest" '[[:space:]](\.|:/)[[:space:]]'; then
        # Only unstaging (--staged without --worktree) keeps the files.
        if ! has "$rest" '[[:space:]](--staged|-S)[[:space:]]' || has "$rest" '[[:space:]](--worktree|-W)[[:space:]]'; then
          block "$HOOK" "git restore of the whole tree discards all local changes." "$HINT"
        fi
      fi ;;
    branch)
      # -D, or delete plus force in any spelling: -d -f, -df, -fd, --delete --force.
      if has "$rest" '[[:space:]]-[A-Za-z]*D[A-Za-z]*[[:space:]]' \
        || { has "$rest" '[[:space:]](--delete|-[A-Za-z]*d[A-Za-z]*)[[:space:]]' && has "$rest" '[[:space:]](--force|-[A-Za-z]*f[A-Za-z]*)[[:space:]]'; }; then
        block "$HOOK" "force-deleting a branch can lose unmerged commits." "$HINT"
      fi ;;
    stash)
      if has "$rest" '^[[:space:]]+(drop|clear)[[:space:]]'; then
        block "$HOOK" "git stash $1 deletes stashed work." "$HINT"
      fi ;;
    filter-branch|filter-repo)
      block "$HOOK" "git $sub rewrites history." "$HINT" ;;
  esac
done <<EOF
$segs
$END_MARK
EOF
require_end "$HOOK" "$seen_end"

exit 0
