---
paths:
  - ".claude/hooks/**"
  - ".claude/agents/**"
  - ".claude/settings*.json"
  - ".mcp.json*"
---

# Working on the guards

This rule loads only when Claude touches the guard files.

- Every new or changed block rule gets at least one `expect_block` and one
  `expect_pass` case in `.claude/hooks/selftest.sh`, in the same change.
- After the change run `bash .claude/hooks/selftest.sh` and
  `bash .claude/hooks/selftest.sh --calibrate`. Both must pass; report the
  last line of each.
- Hooks stay compatible with bash 3.2: no associative arrays, no `${var,,}`,
  no `mapfile`. Check with `SELFTEST_SHELL=/bin/bash`.
- Guards that run before a tool keep `"onFailure": "block"`, so a broken
  guard stops the tool call instead of letting everything through.
- MCP servers: exact versions, secrets only as `${VAR}`, read-only endpoints
  where the provider offers them.
