# Handoff: linear-toon-mcp Project Kickoff

## Context

We're building a lightweight Ruby MCP server that proxies Linear's GraphQL API and returns TOON-formatted responses instead of JSON for token efficiency in LLM workflows (Claude Code).

## Problem Statement

The official Linear MCP server (`@linear/mcp-server`) returns verbose JSON responses that waste context window tokens. A single `list_issues` call for a project returned 61K+ characters — too large even for the tool result buffer. TOON format achieves ~40-60% token savings, especially on uniform arrays of objects (exactly what issue lists are).

## Architecture Decisions

### Transport: stdio (local)
- No HTTP server needed — this runs locally as a subprocess
- Claude Code spawns it via `command: "linear-toon-mcp"` in MCP config
- Same pattern as most MCP servers

### GraphQL client: plain Net::HTTP
- No `graphql-client` gem, no `gqli`, no heavy dependencies
- Hardcoded GraphQL query strings for exactly the fields we need
- Endpoint: `https://api.linear.app/graphql`
- Auth: `Authorization: <LINEAR_API_KEY>` header (key from env)

### Response format: TOON via toon-ruby
- Every tool response runs through `Toon.encode(hash)` before returning
- API: `require 'toon'; Toon.encode(data)` — that's the entire API
- Returns text content type in MCP responses

### Distribution: Ruby gem with bin/ executable
- `gem install linear-toon-mcp`
- Binary: `linear-toon-mcp` (the stdio server entry point)
- Dependencies: `mcp`, `toon-ruby`, `net-http` (stdlib)

## Key Libraries

### mcp gem (MCP server framework)
- Class-based tools: `class MyTool < MCP::Tool`
- Tool response: `MCP::Tool::Response.new([{ type: "text", text: toon_string }])`
- Stdio transport: `MCP::Server::Transports::StdioTransport.new(server).open`
- Server init: `MCP::Server.new(name:, version:, tools: [ToolClass1, ToolClass2])`
- Input validation via `input_schema` with JSON Schema
- Annotations: `read_only_hint`, `destructive_hint`, etc.

### toon-ruby gem
- Single method: `Toon.encode(hash_or_array)`
- Options: `indent:` (default 2), `delimiter:` (default ','), `length_marker:` (default false)
- Best for uniform arrays of objects (issue lists, project lists)

### Linear GraphQL API
- Endpoint: `https://api.linear.app/graphql`
- Auth: `Authorization: lin_api_xxxxx` header
- GraphQL only (no REST)
- Official docs: https://developers.linear.app/docs
- Schema explorer: https://studio.apollographql.com/public/Linear-API/schema/reference

## Tools to Implement (initial set)

| Tool | GraphQL Operation | Purpose | Read-only? |
|------|------------------|---------|------------|
| `get_issue` | `issue(id:)` | Fetch single issue with relations | Yes |
| `list_issues` | `issues(filter:)` | Search/filter issues | Yes |
| `list_project_issues` | `project(id:).issues` | All issues in a project | Yes |
| `get_project` | `project(id:)` | Project details + milestones | Yes |
| `list_teams` | `teams` | Team listing | Yes |
| `update_issue` | `issueUpdate` | Change status/assignee/labels | No |
| `create_comment` | `commentCreate` | Add comments to issues | No |

Start with read-only tools first, add mutations later.

## Design Principles (from MCP skill)

- **Information provider, not analyzer** — return structured data, let LLM reason
- **Context preservation** — only return requested fields, no data dumps
- **Domain-aligned vocabulary** — `get_issue` not `query_issue_by_id`
- **Minimal tool set** — 7 tools vs official server's 30+
- **Minimal fields per query** — only request GraphQL fields we actually use

## Token Savings Example

A list of 50 issues in JSON: ~15,000 tokens
Same data in TOON: ~6,000-9,000 tokens (40-60% reduction)

The savings compound: fewer tokens per response = more room for conversation context = better agent performance.

## File Structure (planned)

```
linear-toon-mcp/
  bin/
    linear-toon-mcp          # Entry point (stdio server)
  lib/
    linear_toon_mcp.rb        # Main require
    linear_toon_mcp/
      server.rb               # MCP server setup
      client.rb               # Linear GraphQL client
      tools/                  # One file per tool
        get_issue.rb
        list_issues.rb
        list_project_issues.rb
        get_project.rb
        list_teams.rb
        update_issue.rb
        create_comment.rb
  linear-toon-mcp.gemspec
  Gemfile
  README.md
```

## References

- TOON format spec: https://toonformat.dev/
- toon-ruby: https://github.com/andrepcg/toon-ruby
- mcp gem: https://rubygems.org/gems/mcp
- MCP protocol: https://modelcontextprotocol.io
- Linear API docs: https://developers.linear.app/docs
- Linear GraphQL playground: https://studio.apollographql.com/public/Linear-API/schema/reference

## Next Steps

The next step is planning.
