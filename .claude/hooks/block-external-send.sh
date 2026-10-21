#!/usr/bin/env bash
# block-external-send.sh: PreToolUse hook for Bash.
#
# Agents draft, humans send. This hook stops the agent from sending anything
# that leaves the building on its own: email (sendmail, mail, mutt, msmtp,
# swaks, SMTP URLs, Apple Mail "send" via osascript, smtplib, nodemailer),
# chat and SMS APIs (Slack, Telegram, Discord, Twilio, mail provider APIs),
# and publishing (npm publish, twine upload, gem push, cargo publish,
# gh release create, docker push, production deploys with vercel --prod).
#
# The agent can still prepare everything: the draft, the release notes, the
# built package, a publish --dry-run, a draft release. Read-only calls to the
# same providers pass. The user reviews the result and presses send.
#
# Seatbelt, not a wall: this matches command text. A script that sends mail
# without naming any of the above in the command line is not seen here.
set +x

HOOK="block-external-send"
# shellcheck source=SCRIPTDIR/_common.sh
. "$(dirname "$0")/_common.sh" || { printf "Blocked by %s: helper _common.sh could not be loaded.\n" "$HOOK" >&2; exit 2; }
require_parser "$HOOK"

HINT='Agents draft, humans send: prepare the message or release, show it to the user, and let the user send it.'

payload="$(read_payload)"
require_input "$HOOK" "$payload"
require_payload "$HOOK" "$payload" tool_name
[ "$(printf '%s' "$payload" | json_get tool_name)" = "Bash" ] || exit 0
require_string "$HOOK" "$payload" tool_input.command
cmd="$(printf '%s' "$payload" | json_get tool_input.command)"
[ -n "$cmd" ] || exit 0

# 1. Sending endpoints of mail, chat and SMS APIs, and SMTP URLs, anywhere in
#    the command (curl, wget, scripts). Only the endpoints that send: a
#    read-only call to the same provider (list domains, check status) passes.
if printf '%s' "$cmd" | grep -Eiq '(smtps?://|api\.sendgrid\.com/v3/mail/send|api(\.eu)?\.mailgun\.net/v3/[^[:space:]]*/messages|api\.postmarkapp\.com/email|api\.resend\.com/emails|api\.brevo\.com/v3/smtp/email|api\.mailjet\.com/v3(\.1)?/send|hooks\.slack\.com/(services|workflows|triggers)/|slack\.com/api/chat\.(postMessage|scheduleMessage)|api\.telegram\.org/bot[^[:space:]]*/send|discord(app)?\.com/api/webhooks/|api\.twilio\.com/[^[:space:]]*/Messages|graph\.microsoft\.com/[^[:space:]]*/sendMail|gmail\.googleapis\.com/[^[:space:]]*/send)'; then
  block "$HOOK" "this command sends a message through a mail, chat or SMS API." "$HINT"
fi

# 2. Apple Mail: an AppleScript that talks to Mail and says "send".
if printf '%s' "$cmd" | grep -q 'osascript' \
  && printf '%s' "$cmd" | grep -Eiq 'application (id )?"(Mail|com\.apple\.mail)"' \
  && printf '%s' "$cmd" | grep -Eq '(^|[^A-Za-z_])send([^A-Za-z_]|$)'; then
  block "$HOOK" "AppleScript would send a mail from Apple Mail." "$HINT"
fi

# 3. Mail programs, inline code and publish commands at command position.
#    Preview modes stay allowed, so a release can be prepared for review:
#    npm/pnpm/yarn/cargo publish --dry-run, gh release create --draft.
word() { printf ' %s ' "$1" | grep -Eq "[[:space:]]$2[[:space:]]"; }
inline_code=0
segs="$(printf '%s\n' "$cmd" | segments)"
seen_end=0
while IFS= read -r seg; do
  if [ "$seg" = "$END_MARK" ]; then seen_end=1; continue; fi
  [ -n "$seg" ] || continue
  prog="${seg%%[[:space:]]*}"
  prog="${prog##*/}"
  rest="${seg#"${seg%%[[:space:]]*}"}"
  case "$prog" in
    sendmail|mail|mailx|mutt|neomutt|msmtp|ssmtp|swaks)
      block "$HOOK" "$prog sends email." "$HINT" ;;
    python|python3|node|perl|ruby|deno|bun|php)
      if word "$rest" '(-c|-e|-E|-r|--eval)'; then
        inline_code=1
      fi
      if word "$rest" '-m[[:space:]]+twine[[:space:]]+upload'; then
        block "$HOOK" "twine upload publishes a package." "$HINT"
      fi ;;
    npm|pnpm|yarn)
      if word "$rest" 'publish' && ! word "$rest" '--dry-run'; then
        block "$HOOK" "$prog publish releases a package to the public registry." "Preview it with --dry-run. $HINT"
      fi ;;
    twine)
      if word "$rest" 'upload'; then
        block "$HOOK" "twine upload publishes a package." "$HINT"
      fi ;;
    gem)
      if word "$rest" 'push'; then
        block "$HOOK" "gem push publishes a package." "$HINT"
      fi ;;
    cargo)
      if word "$rest" 'publish' && ! word "$rest" '--dry-run'; then
        block "$HOOK" "cargo publish publishes a crate." "Preview it with --dry-run. $HINT"
      fi ;;
    gh)
      if word "$rest" 'release[[:space:]]+upload' \
        || { word "$rest" 'release[[:space:]]+(create|edit)' && ! word "$rest" '--draft'; }; then
        block "$HOOK" "gh release publishes a release." "Prepare it with --draft. $HINT"
      fi ;;
    docker|podman)
      if word "$rest" 'push' || { word "$rest" 'buildx' && word "$rest" '--push'; }; then
        block "$HOOK" "$prog push publishes an image." "$HINT"
      fi ;;
    vercel)
      if word "$rest" '(--prod|promote|--target[[:space:]=]+production|--target=production)'; then
        block "$HOOK" "this vercel command deploys to production." "$HINT"
      fi ;;
  esac
done <<EOF
$segs
$END_MARK
EOF
require_end "$HOOK" "$seen_end"

# 4. Mail libraries, only when the command runs inline code (python -c,
#    node -e, perl -e). Searching the source for the word passes.
if [ "$inline_code" = 1 ] && printf '%s' "$cmd" | grep -Eq '(smtplib|nodemailer|Net::SMTP|PHPMailer)'; then
  block "$HOOK" "inline code uses a mail library." "$HINT"
fi

exit 0
