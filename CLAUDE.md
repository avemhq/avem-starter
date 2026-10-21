# CLAUDE.md

Project instructions for Claude Code. Claude reads this file at the start of
every session. Keep it short: every line here costs context in every session.
Replace the bracketed parts, delete what does not apply.

## Project

- What this is: [one sentence, for example "Booking backend for a plumbing company"]
- Stack: [for example Next.js, Supabase, Vercel]
- Run: `[npm run dev]` · Test: `[npm test]` · Lint: `[npm run lint]`
- Owner who decides scope and releases: [role, not a private name if this file is shared]

## How to work here

1. **Say what "done" means before you start.** For any change beyond a
   one-liner, state one to three checks that prove it works, then do the work.
2. **Measure before you claim.** "Fixed", "works", "deployed" need evidence
   from this session: test output, a command result, a file you read back.
   If you did not check it, say "not verified".
3. **Read back what you wrote.** After writing a file, a record or a config,
   read the result back and compare it with what you intended. Tools can
   fail silently while the result looks complete.
4. **Small, reviewable diffs.** One concern per commit. Explain the why in the
   commit message, not the what.
5. **Review before merge.** Run the `pre-merge-review` skill on the diff
   before asking for a merge. It runs in the read-only `reviewer` subagent,
   which starts without this conversation. A second model or a second person
   reviews anything that touches auth, payments, data deletion or permissions.

## Hard rules

- **Never send, publish or pay.** Draft messages, releases and invoices,
  then hand them to the user. The `block-external-send` hook enforces the
  common cases. Use the `draft-external-message` skill for anything a person
  outside the team will read.
- **Secrets stay out of the transcript.** Never read or print `.env` or key
  files; the `protect-secrets` hook, the `Read` deny rules and the sandbox
  block them. To know which keys a project needs, read `.env.example`; to
  know whether a key is set, ask the user.
- **No history rewrites on shared branches.** No force push, no direct push
  to `main`. The `guard-git` hook enforces the common cases.
- **A blocked command is reported, not reworded.** If a hook or a permission
  rule blocks a command, tell the user what was blocked and why. Do not look
  for another spelling of the same command.

## Guards

`bash .claude/hooks/selftest.sh` proves every guard blocks what it should and
passes what it should. It also runs quietly at every session start, after
every Edit or Write to a guard, the settings, an agent, a skill, a rule or the
MCP configuration, and when Claude Code reports a change to the project or
local settings or a skill. It only speaks when something is broken. If it
warns, tell the user first. A settings or skill change that breaks the guards
is not applied to the running session.
Rules for changing the guards load from `.claude/rules/guards.md` when you
touch those files.

## Where things live

- Decisions and their reasons: `[docs/decisions/]`
- Open tasks: `[issue tracker or TASKS.md]`
- Anything that changes how Claude should work here goes into this file,
  in the section it belongs to, in the same session it was decided.
