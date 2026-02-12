# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Token-efficient MCP server for Linear. Wraps Linear's GraphQL API and returns TOON-formatted responses (~40-60% token savings vs JSON). Distributed as a Ruby gem with a stdio binary.

## Commands

```bash
bundle exec rspec                          # run all specs
bundle exec rspec spec/path/to_spec.rb     # run single spec file
bundle exec rspec spec/path/to_spec.rb:42  # run single example by line
bundle exec standardrb                     # lint
bundle exec standardrb --fix               # lint + autofix
```

## Architecture

**Entry point:** `bin/linear-toon-mcp` — starts stdio MCP transport.

**Server factory:** `LinearToonMcp.server` (in `lib/linear_toon_mcp.rb`) — creates `MCP::Server` with registered tools.

**Tools:** Each tool is a class under `LinearToonMcp::Tools` inheriting `MCP::Tool`. Lives in `lib/linear_toon_mcp/tools/`. Tools define `description`, `annotations`, `input_schema`, and a `self.call(**kwargs, server_context: nil)` class method returning `MCP::Tool::Response`.

**Response pipeline:** Linear GraphQL response -> Ruby hash -> `Toon.encode(data)` -> `MCP::Tool::Response` with text content type.

**Linear client:** `LinearToonMcp::Client` — plain `Net::HTTP` against `https://api.linear.app/graphql`. Auth via `LINEAR_API_KEY` env var. Hardcoded query strings, no GraphQL client gem. Injected into tools via `server_context: {client:}`.

## Key Dependencies

- `mcp` (~> 0.6) — MCP server framework
- `toon-ruby` (~> 0.1) — JSON-to-TOON serialization (`Toon.encode(data)`)
- `standard` — linter (dev)
- Ruby >= 3.2, toolchain managed by mise (Ruby 3.4)

## Versioning & Releases

Each new tool (or set of tools) bumps the minor version. Version `1.0.0` = feature parity with official Linear MCP server. When adding tools, always:

1. Bump version in `lib/linear_toon_mcp/version.rb`
2. Update the Tools table in `README.md`

Release flow (after merging to main):

1. Commit version bump: `git commit -am "Bump version to x.y.z"`
2. Tag: `git tag vx.y.z`
3. Push with tags: `git push origin main --tags`
4. GitHub Actions publishes the gem to RubyGems.org via trusted publishing

## Design Principles

- Always follow instructions and issue descriptions
- From the start narrow down the ticket scope and focus on what is required
- Always follow best practices: YAGNI, SOLID, DRY
- Information provider, not analyzer — return data, let LLM reason
- Minimal tool set and minimal GraphQL fields per query
- Every response goes through TOON encoding
- No heavy dependencies (no graphql-client gems)
- Public gem — YARD docs required on all public interfaces
- Tools must guard against nil API responses (e.g., issue not found)

## Skills

Use these skills to follow best practices for the relevant domain:

- `/rspec` — when working with specs
- `/mcp-server` — when working on MCP tools
- `/gh-issue` — when creating or editing GitHub issues
