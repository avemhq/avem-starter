# Changelog

## 1.0.0 (2026-10-21, first public version)

Tested with Claude Code 2.1.304 on macOS 27; CI runs on Linux and macOS.

- `SECURITY.md`: how to report a vulnerability privately, and what counts.
- CI: secret scan of every commit with the gitleaks CLI (exact version,
  checksum checked); the log shows only the exit code and counts, never the
  raw scanner output. Dependabot proposes updates for the pinned actions
  once a week.

- Guards fail closed: `onFailure: "block"` on every guard, and the guards
  block by themselves when they cannot read their input (no jq, no python3).
- `config-guard` on `ConfigChange`: a settings or skill change that breaks the
  guards is not applied to the running session.
- `recheck-guards` after Edit and Write on guards, settings, agents, skills,
  rules and the MCP config.
- Reviewer subagent without a shell (Read, Grep, Glob); `/pre-merge-review`
  hands it status, commits with their messages and the diff.
- Selftest: canonical registration form, exact frontmatter of reviewer and
  review skill, MCP config hints, calibration against broken settings,
  agents, skills and MCP configs; works in the project and the plugin layout.
- Plugin `avem-starter` (hooks, reviewer, skills) in this repository as
  marketplace `avem`; built by `scripts/build-plugin.sh`, CI checks the
  committed copy is current. Permissions and sandbox stay in the project
  settings.
- `Read(./.env.*)` with `Read(!.env.example)`: every .env variant blocked,
  the template readable.
- `scripts/acceptance.sh` collects the evidence for an acceptance record.
- Docs: adopting, team rollout with managed settings, before you roll out
  (EN and DE), threat model, MCP, decisions.
- Example: overdue invoices, one task from start to hand-over, with real
  review and drafting runs.

## 2026-10-08

First internal version: three guards, selftest with calibration, two skills.

## What can break on a Claude Code update

The selftest compares some files with exact text. Change them together:

| File | Constant in `.claude/hooks/selftest.sh` |
|---|---|
| `.claude/agents/reviewer.md` frontmatter | `REVIEWER_FM` |
| `.claude/skills/pre-merge-review/SKILL.md` frontmatter | `SKILL_FM` |
| Guard registration in `.claude/settings.json` | canonical form, see [docs/selftest.md](docs/selftest.md) |

CI does not run Claude Code: it tests the hooks with recorded inputs, so it
cannot see a new Claude Code version. If a version drops or retypes a field
the guards read (tool_name, source, the command or file path), they block; if it
changes a settings field, the session-start selftest only sees it where it
checks the exact form. After an update, run the selftest, check `/hooks` and
try one command the guards should block.
