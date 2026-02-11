# linear-toon-mcp

Lightweight MCP server for Linear that returns TOON-formatted responses for token-efficient LLM interactions.

## What is this?

A Ruby-based [Model Context Protocol](https://modelcontextprotocol.io) server that wraps [Linear's GraphQL API](https://developers.linear.app/docs) and returns responses in [TOON format](https://toonformat.dev/) (Token-Oriented Object Notation) instead of JSON, achieving ~40-60% token savings.

## Why?

The official Linear MCP server returns verbose JSON responses that consume significant context window space. For LLM-powered workflows (Claude Code, etc.), every token matters. TOON format preserves all the data while being dramatically more compact — especially for uniform arrays of issues, projects, and comments.

## Stack

- **[mcp](https://rubygems.org/gems/mcp)** — MCP server framework (stdio transport)
- **[toon-ruby](https://github.com/andrepcg/toon-ruby)** — JSON-to-TOON conversion
- **Net::HTTP** — Minimal GraphQL client for Linear API (no heavy dependencies)

## Installation

```bash
gem install linear-toon-mcp
```

## Configuration

Set your Linear API key as an environment variable:

```bash
export LINEAR_API_KEY=lin_api_xxxxx
```

Get your API key from [Linear Settings > API](https://linear.app/settings/api).

### Claude Code

Add to your MCP config (`.mcp.json` or Claude Code settings):

```json
{
  "mcpServers": {
    "linear": {
      "command": "linear-toon-mcp",
      "env": {
        "LINEAR_API_KEY": "lin_api_xxxxx"
      }
    }
  }
}
```

## Development

```bash
git clone git@github.com:hoblin/linear-toon-mcp.git
cd linear-toon-mcp
bundle install
```

## License

MIT
