# MCP servers

`.mcp.json.example` contains one server: GitHub's read-only MCP endpoint,
authenticated with a token from your environment.

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/readonly",
      "headers": {
        "Authorization": "Bearer ${GITHUB_MCP_TOKEN}"
      }
    }
  }
}
```

Rename it to `.mcp.json` to use it. Claude Code asks once per project before
it starts servers from that file.

## Adding a local server

A local server that runs through `npx` or `uvx` should name an exact
version, and its secrets should come from the environment:

```json
{
  "mcpServers": {
    "internal-tools": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@your-org/internal-mcp-server@1.4.2"],
      "env": {
        "INTERNAL_API_KEY": "${INTERNAL_API_KEY}"
      }
    }
  }
}
```

`@your-org/internal-mcp-server` is a placeholder, not a real package.

## Rules the selftest checks

Credential-like headers and env entries written as `${VAR}`, exact package
versions for `npx` and `uvx`, https for remote servers. It is a hint for the
common slips, not a guarantee; see [selftest](selftest.md).

The settings deny every MCP tool whose name contains `delete`
(`mcp__*__*delete*`). Prefer read-only endpoints where the provider offers
them.
