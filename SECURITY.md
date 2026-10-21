# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Report it privately: if the repository's **Security** tab offers
**Report a vulnerability** (GitHub private vulnerability reporting), use
it. Otherwise open an issue that only asks for a private contact, without
any details of the problem.

A useful report says:

- what you found and what it lets an agent or a person do,
- how to reproduce it (the command or input, and the guard involved),
- the version from `CHANGELOG.md` or the commit you tested.

## What counts

In scope: the guards in `.claude/hooks/` and `plugins/avem-starter/`, the
selftest, `.claude/settings.example.json`, `examples/managed-settings.json`
and the plugin build. Two kinds of finding matter most:

- a guard that lets through something `docs/threat-model.md` says it covers,
- a selftest that stays green while a guard is broken.

Known limits are not vulnerabilities: everything listed under "Does not
cover" and "Not covered at all" in `docs/threat-model.md`. The hooks match
the text of a command; the sandbox is the wall. A proposal to close one of
those limits is welcome as a normal issue.

## Versions

Fixes go into `main` and the next release in `CHANGELOG.md`.
