#!/usr/bin/env bash
# protect-secrets.sh: PreToolUse hook for Bash, Read, Edit and Write.
#
# Keeps secrets out of the transcript. Blocks the usual ways an agent would
# put a secret value on screen: reading a secret file, dumping the whole
# environment, echoing a variable that holds a key, or asking a password
# manager or cloud secret store to print a value.
#
# Existence checks pass this hook, because they answer the real question
# ("is the key set?") without showing the value:
#   test -f .env          grep -c '^API_KEY=' .env      cut -d= -f1 .env
#   echo "${#API_KEY}"    (length only)                 source .env
# In the full setup the Read deny rules and the sandbox still block any
# command that reads .env, so the hint below points to what works there.
#
# Seatbelt, not a wall: this matches command text. A program that opens the
# file by itself, without naming it in the command, is not seen here. Hard
# limits come from the sandbox and from OS file permissions.
set +x

HOOK="protect-secrets"
# shellcheck source=SCRIPTDIR/_common.sh
. "$(dirname "$0")/_common.sh" || { printf "Blocked by %s: helper _common.sh could not be loaded.\n" "$HOOK" >&2; exit 2; }
require_parser "$HOOK"

HINT='Check that the file exists (test -f FILE), read the key names from .env.example, or ask the user whether a key is set.'

# is_secret_path <text>: true when the text names a file that holds secrets
# by convention. Template files (.env.example, .env.sample, .env.template,
# .env.dist) and public keys (any *.pub) do not count.
is_secret_path() {
  printf '%s' "$1" \
    | sed -E -e 's/\.env\.(example|sample|template|dist)//g' -e 's/[^[:space:]"'\'']*\.pub([[:space:]"'\'']|$)/ /g' \
    | grep -Eq '(^|[^A-Za-z0-9_.-])(\.env(\.[A-Za-z0-9_-]+)*|[A-Za-z0-9_.-]*\.(pem|key|p12|pfx)|id_(rsa|ed25519|ecdsa)|credentials(\.json)?|\.netrc|\.npmrc|\.pypirc)([^A-Za-z0-9_.-]|$)|(^|[^A-Za-z0-9_.-])(secrets|\.ssh|\.aws)/'
}

payload="$(read_payload)"
require_input "$HOOK" "$payload"
require_payload "$HOOK" "$payload" tool_name
tool="$(printf '%s' "$payload" | json_get tool_name)"

case "$tool" in
  Read|Edit|Write)
    require_string "$HOOK" "$payload" tool_input.file_path
    path="$(printf '%s' "$payload" | json_get tool_input.file_path)"
    if [ -n "$path" ] && is_secret_path "$path"; then
      block "$HOOK" "$tool on a file that holds secrets ($(basename "$path"))." "$HINT"
    fi
    exit 0
    ;;
  Bash) ;;
  *) exit 0 ;;
esac

require_string "$HOOK" "$payload" tool_input.command
cmd="$(printf '%s' "$payload" | json_get tool_input.command)"
[ -n "$cmd" ] || exit 0

# Input redirection from a secret file, for example: while read l; do ...; done < .env
redirs="$(printf '%s' "$cmd" | grep -oE '<[[:space:]]*[^[:space:]<>|;&]+' | sed -E 's/^<[[:space:]]*//')"
seen_end=0
while IFS= read -r target; do
  if [ "$target" = "$END_MARK" ]; then seen_end=1; continue; fi
  if [ -n "$target" ] && is_secret_path "$target"; then
    block "$HOOK" "input redirected from a secret file ($target)." "$HINT"
  fi
done <<EOF
$redirs
$END_MARK
EOF
require_end "$HOOK" "$seen_end"

segs="$(printf '%s\n' "$cmd" | segments)"
seen_end=0
while IFS= read -r seg; do
  if [ "$seg" = "$END_MARK" ]; then seen_end=1; continue; fi
  [ -n "$seg" ] || continue
  prog="${seg%%[[:space:]]*}"
  prog="${prog##*/}"
  rest="${seg#"${seg%%[[:space:]]*}"}"

  case "$prog" in
    printenv)
      block "$HOOK" "printenv prints every variable, secrets included." "$HINT" ;;
    env|set|export|declare|typeset)
      # Bare forms (and -p) print all variables. With arguments they are fine.
      # printf '%s\n': an empty rest must still give grep one line to test.
      if printf '%s\n' "$rest" | grep -Eq '^[[:space:]]*(-p[[:space:]]*)?$'; then
        block "$HOOK" "'$prog' without arguments prints every variable, secrets included." "$HINT"
      fi ;;
    op)
      if printf '%s' "$rest" | grep -Eq '(^|[[:space:]])(read|inject)([[:space:]]|$)' \
        || { printf '%s' "$rest" | grep -Eq 'item[[:space:]]+get' && printf '%s' "$rest" | grep -Eq -- '--reveal|--fields'; }; then
        block "$HOOK" "password manager asked to print a secret value." "Let the tool inject the value into the process environment instead (for example direnv), never onto stdout."
      fi ;;
    security)
      if printf '%s' "$rest" | grep -Eq 'find-(generic|internet)-password' && printf '%s' "$rest" | grep -Eq '[[:space:]]-[wg]([[:space:]]|$)'; then
        block "$HOOK" "keychain asked to print a password." "$HINT"
      fi ;;
    gcloud)
      if printf '%s' "$rest" | grep -Eq 'secrets[[:space:]]+versions[[:space:]]+access'; then
        block "$HOOK" "cloud secret store asked to print a secret value." "$HINT"
      fi ;;
    aws)
      if printf '%s' "$rest" | grep -Eq 'secretsmanager[[:space:]]+get-secret-value' \
        || { printf '%s' "$rest" | grep -Eq 'ssm[[:space:]]+get-parameters?' && printf '%s' "$rest" | grep -Eq -- '--with-decryption'; }; then
        block "$HOOK" "cloud secret store asked to print a secret value." "$HINT"
      fi ;;
    vault)
      if printf '%s' "$rest" | grep -Eq '(^|[[:space:]])(read|kv[[:space:]]+get)([[:space:]]|$)'; then
        block "$HOOK" "secret store asked to print a secret value." "$HINT"
      fi ;;
    echo|printf|print)
      # ${#NAME} (length) stays allowed: '#' is not part of a name.
      if printf '%s' "$rest" | grep -Eiq '\$\{?[A-Za-z0-9_]*(key|token|secret|passw|credential)'; then
        block "$HOOK" "$prog would print a variable that looks like a secret." "Print its length instead: echo \"\${#NAME}\"."
      fi ;;
    grep|egrep|fgrep|rg|ag|ack)
      if is_secret_path "$seg"; then
        # Count, list and quiet modes show no values.
        if ! printf ' %s ' "$rest" | grep -Eq '[[:space:]](-[A-Za-z]*[clLq][A-Za-z]*|--count|--files-with-matches|--files-without-match|--quiet)[[:space:]]'; then
          block "$HOOK" "$prog would print lines from a secret file." "$HINT"
        fi
      fi ;;
    cut)
      if is_secret_path "$seg"; then
        # cut -d= -f1 prints key names only.
        if ! printf '%s' "$rest" | grep -Eq -- "-d[[:space:]]*['\"]?=['\"]?" || ! printf ' %s ' "$rest" | grep -Eq '[[:space:]]-f[[:space:]]*1[[:space:]]'; then
          block "$HOOK" "cut would print values from a secret file." "$HINT"
        fi
      fi ;;
    git)
      # git show, diff, log -p and add would print or commit the file.
      if is_secret_path "$seg" && ! printf '%s' "$rest" | grep -Eq '^[[:space:]]*(check-ignore|ls-files|rm[[:space:]]+(-r[[:space:]]+)?--cached)'; then
        block "$HOOK" "git would print or commit a secret file." "Keep secret files in .gitignore. To untrack one: git rm --cached FILE."
      fi ;;
    cat|head|tail|less|more|bat|nl|xxd|hexdump|od|strings|base64|tee|sed|awk|gawk|perl|ruby|python|python3|node|deno|bun|jq|yq|sort|uniq|diff|cmp|vim|vi|nano|emacs|open|code|scp|rsync|curl|wget|http|https|zip|tar|gzip|openssl)
      if is_secret_path "$seg"; then
        block "$HOOK" "$prog on a file that holds secrets." "$HINT"
      fi ;;
  esac
done <<EOF
$segs
$END_MARK
EOF
require_end "$HOOK" "$seen_end"

exit 0
