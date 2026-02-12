# linear-toon-mcp

[![CI](https://github.com/hoblin/linear-toon-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/hoblin/linear-toon-mcp/actions/workflows/ci.yml)

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

```bash
claude mcp add -e LINEAR_API_KEY=lin_api_xxxxx linear-toon -- linear-toon-mcp
```

## Tools

| Tool | Description |
|------|-------------|
| `get_issue` | Retrieve a Linear issue by ID or identifier (e.g., `LIN-123`). Returns issue details including title, description, state, assignee, labels, project, and attachments. |
| `list_issues` | List issues with optional filters (team, assignee, state, label, priority, project, cycle) and cursor-based pagination. Supports name or UUID for most filters. |

## Development

```bash
git clone git@github.com:hoblin/linear-toon-mcp.git
cd linear-toon-mcp
bundle install
bundle exec rspec        # run tests
bundle exec standardrb   # lint
```

## Versioning

Version `1.0.0` means feature parity with the official Linear MCP server. Until then, each new tool (or set of tools) bumps the minor version. The single source of truth is `lib/linear_toon_mcp/version.rb`.

## Releasing

1. Update the version in `lib/linear_toon_mcp/version.rb`
2. Commit: `git commit -am "Bump version to x.y.z"`
3. Tag: `git tag vx.y.z`
4. Push: `git push origin main --tags`

The [release workflow](.github/workflows/release.yml) will run CI and publish the gem to RubyGems.org via [trusted publishing](https://guides.rubygems.org/trusted-publishing/).

## License

MIT
