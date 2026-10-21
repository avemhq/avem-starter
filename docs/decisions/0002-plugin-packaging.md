# 0002: Packaging as a Claude Code plugin

Status: accepted, plugin avem-starter in marketplace avem (October 2026)

## Question

Can the starter ship as a plugin, so a team installs it with one command
instead of copying files, and do the selftest and the plugin's hooks work
together?

## Probe (20.10.2026, Claude Code 2.1.304, macOS)

A throwaway plugin was assembled from this repository: the hooks moved to
`hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh`, the
skills and the reviewer agent in their default plugin folders.

| Check | Result |
|---|---|
| `claude plugin validate` | passes once the name is changed: names starting with `claude-` are reserved, so the plugin cannot be called `claude-code-starter` |
| `protect-secrets` loaded from the plugin (`--plugin-dir`, `claude -p`) | `cat .env` blocked with the hook's reason |
| `onFailure: "block"` in plugin hooks | with `guard-git.sh` removed, `pwd` was blocked with `failed; blocking because onFailure is "block"` |

## What a plugin cannot carry

From the [plugin manifest reference](https://code.claude.com/docs/en/plugins-reference):

- **Permissions and sandbox.** A plugin's settings apply only `agent` and
  `subagentStatusLine`; the `allow`, `ask` and `deny` rules and the whole
  `sandbox` block still have to live in the project's `.claude/settings.json`.
- **CLAUDE.md.** A `CLAUDE.md` at the plugin root is not loaded; working
  rules would have to become a skill.
- **Hooks in plugin agents' frontmatter** are ignored (the reviewer has
  none, so this does not matter today).

## What the selftest would need

- A plugin mode that reads `hooks/hooks.json` and expects
  `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` as the canonical command.
- `config-guard` watches `.claude/skills/`; skills that come from the plugin
  are outside that path.
- The session-start selftest would run from the plugin, but the deny rules
  and the sandbox it should also check stay in the project.

## Decision

The plugin is a second way in, next to the copied files, not instead of
them: plugin for hooks, skills and the reviewer; a short project
`settings.json` for permissions and sandbox.

Built (20.10.2026): `scripts/build-plugin.sh <out-dir> <name> [version]`
assembles the plugin from this repository, so there is one source and no
second copy to keep in sync. The selftest recognises the plugin layout by
`.claude-plugin/plugin.json` next to its folder and then checks
`hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` as the
canonical command. CI builds the plugin into a temp folder and runs the
selftest and calibration there. The built plugin passes
`claude plugin validate`.

Name and distribution (20.10.2026): the plugin is called `avem-starter`.
This repository is its marketplace (`avem`, file
`.claude-plugin/marketplace.json`), and the plugin sits in
`plugins/avem-starter/`, built by `scripts/build-plugin.sh` from the project
files. CI rebuilds it and fails when the committed copy differs, so the two
cannot drift apart. `claude plugin validate` passes for the marketplace and
for the plugin. Install:
`/plugin install avem-starter --marketplace avemhq/avem-starter`
(Claude Code 2.1.275 or newer). An install from the marketplace on a clean
machine has not been tried yet; it needs the repository to be reachable.
