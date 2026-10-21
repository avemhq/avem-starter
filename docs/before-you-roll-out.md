# Before you roll out: data, cost, open questions

Two pages for the managing director. Facts carry their source and date;
everything else is marked as an estimate. Nothing here is legal advice.

## Where the data goes

- Claude Code runs on the developer's machine. To answer, it sends the
  prompts and the parts of files it reads to the model provider, encrypted
  in transit (TLS 1.2 or newer)
  ([data usage](https://code.claude.com/docs/en/data-usage), read 20.10.2026).
- **Training:** under commercial terms (Team, Enterprise, API) Anthropic
  does not train models on code or prompts from Claude Code, unless the
  customer opts in. Consumer plans (Free, Pro, Max) have a setting for
  that. Use a commercial plan for company work (same source).
- **Retention:** commercial accounts 30 days as standard; zero data
  retention is available for qualified Enterprise accounts. Locally, Claude
  Code keeps session transcripts in plain text under `~/.claude/projects/`
  for 30 days by default (`cleanupPeriodDays`) (same source).
- **Telemetry:** usage metrics without code, prompts or file paths; can be
  switched off with `DISABLE_TELEMETRY=1` or
  `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` (same source).
- **Alternatives:** the same models through Amazon Bedrock or Google Cloud
  run in that cloud, and error reports, telemetry and `/feedback` are off
  there by default. Microsoft Foundry depends on the hosting option: hosted
  on Azure, prompts and completions stay in Azure, but usage metadata and
  content flagged by Anthropic's safety systems still go to Anthropic;
  hosted on Anthropic, requests run on Anthropic's infrastructure. Session
  surveys and the WebFetch domain check run with every provider (same
  source).

What the starter adds: the usual ways to read secret files stay blocked
(`protect-secrets`, deny rules, sandbox), `GITHUB_TOKEN` and `NPM_TOKEN`
are removed from sandboxed commands (add your own token names), and the
usual send, publish and deploy commands are blocked (`block-external-send`).
None of this is complete: see [threat-model.md](threat-model.md).

## What it costs per person

From [claude.com/pricing](https://claude.com/pricing), read 20.10.2026, in
US dollars, before tax:

| Plan | Price | Note |
|---|---|---|
| Team, standard seat | 20 per seat and month (annual), 25 (monthly) | includes Claude Code |
| Team, premium seat | 100 per seat and month (annual), 125 (monthly) | five times the usage of a standard seat |
| Enterprise, self-serve | 20 per seat and month (annual), 20 seats minimum | usage billed on top, by model and task |

Worked example for 10 people, annual billing: 8 standard seats and 2 premium
seats for the two heaviest users cost 8 × 20 + 2 × 100 = 360 dollars a month,
4'320 a year. Whether standard seats are enough for daily coding work is an
estimate to measure in the first month, not a fact.

## Open questions for your data protection officer (Switzerland, revDSG)

Questions, not answers:

1. Does code or a prompt contain personal data of customers or staff? Then
   the transfer to the provider abroad needs a basis; which one applies?
2. Is the provider's data processing agreement in place for the plan you
   choose, and who signs it?
3. Do staff need to be informed that an AI tool reads their working files,
   and is local transcript storage of 30 days acceptable?
4. Which repositories are excluded from AI use altogether?
5. Is zero data retention or a cloud provider within a specific region
   required for some projects?

## What a rollout costs in time

Setup on one machine about 30 minutes with the starter; a team of 10 about
half a day including managed settings and the onboarding checklist
([team rollout](team-rollout.md)) [estimate].
