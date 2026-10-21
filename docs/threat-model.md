# Threat model: what each guard covers, and what it does not

Risk names from the [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/)
(read 20.10.2026). The hooks match the text of a command; they are a
seatbelt. The sandbox, a separate OS user or a dev container is the wall.

| Part | Covers | Risk (OWASP LLM 2025) | Does not cover |
|---|---|---|---|
| `protect-secrets` | the agent printing secret files, environment dumps, password manager and cloud secret reads | LLM02 Sensitive Information Disclosure | a program that opens the file itself; secrets already inside source code |
| Read deny rules and sandbox `denyRead` | reads of `.env`, keys, `~/.ssh`, `~/.aws` by Claude's tools and by every sandboxed command | LLM02 | native Windows (no sandbox); commands you allow outside the sandbox |
| `credentials.envVars` | `GITHUB_TOKEN`, `NPM_TOKEN` visible to sandboxed commands | LLM02 | tokens under other names: add them |
| `guard-git` | force push, history rewrites, deleting branches, discarding work | LLM06 Excessive Agency | damage outside git; a push from another tool |
| `block-external-send` | the agent sending mail, chat or SMS, publishing packages and images, production deploys | LLM06; LLM01 Prompt Injection when injected text asks the agent to send data out | network calls by programs the sandbox lets through; send paths not on the list |
| Sandbox network allowlist | any command reaching hosts you did not approve | LLM01, LLM02 | hooks, MCP servers and the status line, which run outside the sandbox |
| Reviewer without a shell | the reviewer changing code or running commands | LLM06 | a wrong review: it is a second opinion, not a test |
| `draft-external-message` | sending an unchecked message to a client | LLM09 Misinformation (claims without a source) | the person who sends it anyway |
| `onFailure: "block"`, parser check | a broken guard silently letting everything through | supports all of the above | a guard that wrongly reports success for another reason |
| `config-guard`, `recheck-guards`, session-start selftest | a settings or skill change that breaks the guards | supports all of the above | `disableAllHooks` set before the session starts; personal and managed settings |
| Managed settings | developers switching guards or deny rules off locally | LLM06 | administrators of the machine; other tools than Claude Code |
| MCP config check, exact versions, read-only GitHub endpoint | floating server versions, tokens in the file, write access you did not need | LLM03 Supply Chain, LLM06 | a compromised version you pinned; tokens in URLs or arguments |

Not covered at all by the starter: LLM04 (data and model poisoning), LLM07
(system prompt leakage), LLM08 (vector and embedding weaknesses) and LLM10
(unbounded consumption; use the plan's spend limits).
