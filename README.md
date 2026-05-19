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
claude mcp add linear-toon -e LINEAR_API_KEY=lin_api_xxxxx -- linear-toon-mcp
```

## Tools

| Tool | Description |
|------|-------------|
| `get_issue` | Retrieve a Linear issue by ID or identifier (e.g., `LIN-123`). Returns issue details including title, description, state, assignee, labels, project, attachments, and the parent and direct child issues (each with identifier, title, state, and url). |
| `list_issues` | List issues with optional filters (team, assignee, state, label, priority, project, cycle) and cursor-based pagination. Supports name or UUID for most filters. |
| `list_issue_statuses` | List available workflow states for a team. Returns status id, type (backlog/unstarted/started/completed/canceled), and name. Accepts team name or UUID. |
| `list_teams` | List all teams in the workspace. Returns team id, name, and key. |
| `list_users` | List users in the workspace, optionally scoped to a team. Returns user id, name, and email. |
| `list_issue_labels` | List issue labels, optionally scoped to a team. Returns label id and name. |
| `list_projects` | List projects, optionally scoped to a team. Returns project id, name, and state. |
| `list_cycles` | List cycles for a team. Returns cycle id, name, number, startsAt, and endsAt. Requires team name or UUID. |
| `get_project` | Retrieve a specific project by name, ID, or slug. Returns project details including state, priority, dates, progress, and lead. Optional includes for members, milestones, and resources. |
| `create_issue` | Create a new Linear issue. Accepts human-friendly names for team, assignee, state, labels, project, cycle, and milestone (resolved to IDs automatically; label names resolve against the target team or workspace-wide labels). Relation params (`blocks`, `relatedTo`, `duplicateOf`) and `parentId` accept either issue UUIDs or human identifiers (e.g., `LIN-123`). Supports issue relations and link attachments. |
| `update_issue` | Update an existing Linear issue by ID. Supports partial updates, null to remove fields, and relation replacement. Relation params (`blocks`, `relatedTo`, `duplicateOf`) and `parentId` accept either issue UUIDs or human identifiers (e.g., `LIN-123`). Label names resolve against the issue's team or workspace-wide labels. |
| `create_comment` | Create a comment on a Linear issue. Supports Markdown content and threaded replies via parentId. |
| `list_comments` | List comments for a specific Linear issue in chronological order. Returns each comment's id, body, author, and timestamps. |
| `list_initiatives` | List initiatives with filters (status, owner, parent initiative, date ranges) and cursor-based pagination. Optional `includeProjects` adds linked projects. |
| `get_initiative` | Retrieve a Linear initiative by name or ID. Returns linked projects (id and name). Optional `includeSubInitiatives`. |
| `save_initiative` | Create or update a Linear initiative (id presence determines). Resolves `owner` and `parentInitiative` names to IDs. Exposes both `description` (short summary, ~255 chars) and `content` (long Markdown). |
| `delete_initiative` | Delete an initiative by name or ID. Hard-deletes via `initiativeDelete` by default; `archive: true` soft-deletes via `initiativeArchive`. Hard delete is refused while projects are still linked — unlink first or archive. |
| `add_project_to_initiative` | Link a project to an initiative. Accepts names or UUIDs for both. |
| `remove_project_from_initiative` | Unlink a project from an initiative. Accepts names or UUIDs for both; finds and deletes the underlying join record. |
| `list_status_updates` | List status updates posted to a project or initiative. Exactly one of `project:` or `initiative:` (name or UUID) is required. Cursor-paginated. |
| `get_status_update` | Retrieve a status update by ID. Works for both project and initiative updates — internally tries each. |
| `save_status_update` | Create or update a status update on a project or initiative (id presence determines). `health` enum: `onTrack` / `atRisk` / `offTrack`. Body is Markdown. |
| `delete_status_update` | Archive a status update by ID. Linear has no hard-delete for status updates; this maps to `*UpdateArchive`. |

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
