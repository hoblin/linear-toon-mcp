# CLAUDE.md

## Project

Ruby gem implementing an MCP server that wraps Linear's GraphQL API and returns every response through TOON encoding.

## Commands

```bash
bundle exec rspec [spec/path/to_spec.rb[:42]]   # all specs / file / single example
bundle exec standardrb [--fix]
```

## Architecture

**Entry point:** `bin/linear-toon-mcp` — starts stdio MCP transport.

**Server factory:** `LinearToonMcp.server` in `lib/linear_toon_mcp.rb` — returns an `MCP::Server` with all tools registered.

**Tools:** Each tool is a class under `LinearToonMcp::Tools` inheriting `MCP::Tool`. Lives in `lib/linear_toon_mcp/tools/`. Tools define `description`, `annotations`, `input_schema`, and a `self.call(**kwargs, server_context: nil)` class method returning `MCP::Tool::Response`.

**Response pipeline:** Linear GraphQL response -> Ruby hash -> `Toon.encode(data)` -> `MCP::Tool::Response` with text content type.

**Linear client:** `LinearToonMcp::Client` — plain `Net::HTTP` against `https://api.linear.app/graphql`. Auth via `LINEAR_API_KEY` env var. Hardcoded query strings, no GraphQL client gem. Injected into tools via `server_context: {client:}`.

## Key Dependencies

- `mcp` ~> 0.11
- `toon-ruby` ~> 0.1 — exposes `Toon.encode(data)`
- `standard` (dev)
- Ruby >= 3.2, toolchain managed by mise (Ruby 3.4)

## Versioning & Releases

Each new tool (or set of tools) bumps the minor version. Version `1.0.0` = feature parity with official Linear MCP server. On every tool addition:

1. Bump version in `lib/linear_toon_mcp/version.rb`
2. Update the Tools table in `README.md`

Release flow (after merging to main):

1. Commit version bump: `git commit -am "Bump version to x.y.z"`
2. Tag: `git tag vx.y.z`
3. Push with tags: `git push origin main --tags`
4. GitHub Actions publishes the gem to RubyGems.org via trusted publishing

## Design Principles

- Information provider, not analyzer — return data, let LLM reason
- Minimal tool set and minimal GraphQL fields per query
- Every response goes through TOON encoding
- No heavy dependencies (no graphql-client gems)
- Public gem — YARD docs required on all public interfaces
- Tools must guard against nil API responses (e.g., issue not found)
