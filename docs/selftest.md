# How the selftest works

`bash .claude/hooks/selftest.sh` checks every guard on three axes:

- **registered**: wired up in the project settings, executable, and set to
  block when it fails
- **speaks**: every known violation is blocked (exit 2, reason on stderr)
- **silent**: harmless commands pass (exit 0), because a guard that blocks
  everything gets switched off

The hooks get the same JSON on stdin that Claude Code sends them.

## What "registered" means here

The check reads one file: `.claude/settings.json`, or the example when that
file does not exist. It does not merge your personal settings
(`~/.claude/settings.json`), the local project file
(`.claude/settings.local.json`) or managed settings. A green result proves
the project file is right. Whether the guards are active in your session is
shown by `/hooks` and `/status` in Claude Code, see
[effective configuration](https://code.claude.com/docs/en/settings#settings-precedence).

Within that file it follows event names and matchers the way the hooks
reference describes them and notices `disableAllHooks`, so a guard
registered under the wrong event counts as missing. The file must be exactly
one valid JSON object. Each guard must be registered in exactly one form:

- the command `${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.sh`
- with `"args": []` (exec form: no shell, no wrapper)
- with `"onFailure": "block"`
- without `async` (a background hook cannot block) and without an `if`
  filter (a filtered hook skips commands)

`config-guard` must be registered this way on `ConfigChange` for all three
sources a project can change: `project_settings`, `local_settings` and
`skills`. In the project layout, `permissions.deny` must hold
`Read(./.env.*)` and, after it, `Read(!.env.example)`: a `!` rule carves the
template back out of the rules listed before it, and carves nothing out when
it comes first
([permissions](https://code.claude.com/docs/en/permissions)). The
session-start selftest is checked the same way as the guards. Every guard
also has a case that runs it without `jq` and `python3` on `PATH`; it must
block. The whole frontmatter of
the reviewer subagent and of the review skill is compared with its exact
expected text in `selftest.sh`, including the closing `---`. A `tools:` line
hidden inside a multi-line description, a second `context:` line that
overrides the fork, or a file cut off before the closing marker all fail.
If you change the reviewer's description or the skill's frontmatter, change
`REVIEWER_FM` or `SKILL_FM` in `selftest.sh` with it.

## Calibration

`selftest.sh --calibrate` turns the test against itself. The violations run
against a stub hook that never blocks; the registration check runs against
broken settings (hooks disabled, guards moved to `PostToolUse`,
`onFailure` removed, `async` set, an `if` filter added or set to null, the
guard wrapped in `/bin/echo`, shell form, `args` missing, a second JSON
document appended, the `ConfigChange` matcher narrowed to one source), a reviewer with a shell or edit tools or with its tool
lines inside the description, a truncated reviewer file, a review skill that
does not fork or whose fork is overridden, and broken MCP configs. Every case
must fail, which proves the test can go red.

`SELFTEST_SHELL=/bin/bash bash .claude/hooks/selftest.sh` runs every hook
under a chosen interpreter, for example the bash 3.2 that ships with macOS.

## The MCP check is a hint, not a guarantee

The selftest also looks at `.mcp.json` (or the example) for the common
mistakes: invalid JSON, a header or env entry with a credential-like name
(`Authorization`, `*_TOKEN`, `*_KEY`, ...) that is not written as `${VAR}`,
an `npx` or `uvx` package without an exact version, plain http to a remote
host. It does not find every way a secret can end up in the file: a password
inside a URL, a token passed as a command argument or a connection string
under an unrelated name all pass. Read the file before you commit it.

## Plugin layout

When `selftest.sh` sits in a plugin built by `scripts/build-plugin.sh`
(next to `.claude-plugin/plugin.json`), it checks the plugin instead of a
project: `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` as
the canonical command, and the plugin's own agent and skill files. The same
cases and the same calibration run. Permissions and the sandbox are not part
of a plugin and are not checked there.

## Known limits of the registration check

Tracked as open findings: an `if` field whose value is `-`, `args` for the
session-start hook joined into one argument, matchers written as regular
expressions (the check uses jq or Python, Claude Code uses JavaScript), a
parser error after partial output, and `protect-secrets` checked only for
Bash and Read, not for Edit and Write.
