# Adopting the starter in an existing repository

## Copy

| From the starter | Into your repository | If you already have one |
|---|---|---|
| `CLAUDE.md` | `CLAUDE.md` | Add the sections *How to work here*, *Hard rules* and *Guards* to yours; keep your project facts |
| `.claude/hooks/` | `.claude/hooks/` | New folder in most projects; then `chmod +x .claude/hooks/*.sh` |
| `.claude/agents/reviewer.md` | same | Keep the file name; another agent called `reviewer` must be renamed |
| `.claude/skills/` | same | Add both skill folders |
| `.claude/rules/guards.md` | same | Add the file |
| `.claude/settings.example.json` | `.claude/settings.json` | Merge, see below |
| `.gitignore` lines | `.gitignore` | Append the lines you do not have |
| `.mcp.json.example` | `.mcp.json` | Only if you use MCP; merge the `mcpServers` entries |
| `examples/workflows/guards-selftest.yml` | `.github/workflows/guards-selftest.yml` | Add as its own workflow (the repository's own `selftest.yml` also needs `scripts/`, `plugins/` and `examples/`) |
| `docs/` | optional | Reference for your team |

The MIT license of the starter applies to the copied files; keep its notice
with them.

## Merging settings.json

- `permissions.allow`, `ask`, `deny`: append the starter's entries to yours.
  Where an entry of yours allows what the starter denies, deny wins in
  Claude Code; decide which you want.
- `hooks`: append the starter's groups to each event (`SessionStart`,
  `PreToolUse`, `PostToolUse`, `ConfigChange`). Keep each guard exactly in
  the form the starter uses, or the selftest reports it as not registered.
- `sandbox`: if you have none, take the starter's block. If you have one,
  add `allowUnsandboxedCommands`, `credentials` and the `filesystem` entries.

Then run `bash .claude/hooks/selftest.sh` and `--calibrate`.

## Check the effective setup

The selftest checks the project file. What is active in a session comes
from several levels: managed settings, your personal `~/.claude/settings.json`,
the project's `.claude/settings.json` and the personal
`.claude/settings.local.json`
([settings precedence](https://code.claude.com/docs/en/settings#settings-precedence)).
In Claude Code, `/status` shows which sources are loaded and `/hooks` which
hooks run.

## Undo

1. Delete `.claude/hooks/`, `.claude/agents/reviewer.md`, the two skill
   folders and `.claude/rules/guards.md`.
2. Remove the starter's entries from `.claude/settings.json` (or restore your
   earlier version from git).
3. Remove the workflow file and, if copied, the `CLAUDE.md` sections.

Nothing outside the repository is changed by the starter, unless you also
installed managed settings ([team rollout](team-rollout.md)).
