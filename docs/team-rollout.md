# Rolling the guards out to a team

The starter alone is a project setting: it is in the repository, everyone
who clones it gets it, and everyone can switch it off on their own machine
(`"disableAllHooks": true` in `.claude/settings.local.json` at session
start, or simply by not trusting the folder). `config-guard` blocks such a
change while a session runs, not before it starts. For a firm rule that
nobody switches off locally, put the core into **managed settings**.

## What managed settings change

Managed settings sit above every other level. A developer's own settings,
project files and command-line flags never override them; only managed
settings can disable managed hooks
([managed settings](https://code.claude.com/docs/en/managed-settings),
[settings reference: disableAllHooks](https://code.claude.com/docs/en/settings-reference#disableallhooks)).

[examples/managed-settings.json](../examples/managed-settings.json) holds:

| Key | Effect |
|---|---|
| `permissions.deny` | The secret-file and destructive-git rules; nobody can allow them back locally |
| `permissions.disableBypassPermissionsMode` | Nobody starts Claude Code with `--dangerously-skip-permissions` |
| `hooks` | The three guards, from a path only an administrator can write, with `onFailure: "block"` |
| `sandbox.enabled`, `failIfUnavailable`, `allowUnsandboxedCommands: false` | Bash commands run sandboxed, without a retry outside it; Claude Code refuses to start if the sandbox cannot. With the retry disabled here, Claude Code ignores `sandbox.excludedCommands` from the repository's settings; the documentation does not say the same for exclusions in a person's own settings, so check that list during the rollout |
| `sandbox.credentials.envVars` | `GITHUB_TOKEN` and `NPM_TOKEN` are removed from sandboxed commands |

The project files stay as they are: the session-start selftest,
`recheck-guards`, `config-guard`, the reviewer and the skills keep working
from the repository.

Two stricter keys exist, each with a price:

- `allowManagedHooksOnly: true` runs only managed hooks (and hooks of
  plugins the managed settings force-enable). The project's own hooks,
  including the selftest at session start, then stop running.
- `allowManagedPermissionRulesOnly: true` ignores the `allow`, `ask` and
  `deny` rules of projects and users. The team's build and test commands
  then have to be allowed in the managed file too.

## Install

1. Copy the three guards and `_common.sh` to a folder only administrators
   can write, for example `/Library/Application Support/ClaudeCode/guards/`
   on macOS or `/etc/claude-code/guards/` on Linux and WSL. Adjust the paths
   in the example to match.
2. Save the example as `managed-settings.json` in the system folder:
   - macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`
   - Linux and WSL: `/etc/claude-code/managed-settings.json`
   - Windows: `C:\Program Files\ClaudeCode\managed-settings.json`

   Or deliver the same keys through your device management (macOS
   configuration profile, Windows policy) or through server-managed
   settings.
3. On one machine, run `/status` in Claude Code: the `Setting sources` line
   must show `Enterprise managed settings`. Run `/hooks`: the three guards
   must be listed from the managed source.
4. Roll out to the rest of the team.

## Windows

The guards are bash scripts, and the sandbox does not exist on native
Windows. On Windows machines, run Claude Code inside WSL2 or a dev
container; there the guards and the sandbox work as on Linux. On native
Windows with `onFailure: "block"` and no bash, every guarded tool call is
blocked: safe, but not usable.

## Onboarding a developer

- [ ] Claude Code 2.1.295 or newer (`claude --version`)
- [ ] macOS, or Linux and WSL2 with bubblewrap and socat
- [ ] `/status` shows `Enterprise managed settings`
- [ ] `/hooks` lists the three guards from the managed source
- [ ] In the project: `bash .claude/hooks/selftest.sh` ends with
      `Result: all ... checks passed.`
- [ ] Trust dialog accepted for the project folder
- [ ] One test each: `cat .env` is blocked, `git push --force` is blocked,
      `npm publish` is blocked
- [ ] Ten minutes on the working rules in `CLAUDE.md`: drafts, never sends;
      blocked commands are reported, not reworded

## Limits

A developer with administrator rights on the machine can edit the managed
file itself, which is why device management redeploys it on a schedule.
Managed settings bind Claude Code only, not other tools.
