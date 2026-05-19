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

Most parameters accept either a UUID or a human identifier (issue identifier like `LIN-123`, team key like `VIB`, project/initiative/label name, user email or `"me"`); the server resolves it. `save_*` tools dispatch by `id` presence — provide an `id` to update, omit it to create. All responses are TOON-encoded.

### Issues

| Tool | Description |
|------|-------------|
| `get_issue` | Retrieve an issue by ID or identifier (e.g., `LIN-123`). Returns the issue plus its parent and direct children. |
| `list_issues` | List issues with filters (team, assignee, state, label, priority, project, cycle) and cursor pagination. |
| `save_issue` | Create or update an issue. Accepts names for team, assignee, state, labels, project, cycle, and milestone. Relation params (`blocks`, `relatedTo`, `duplicateOf`) and `parentId` accept UUIDs or identifiers. On create, relations are appended; on update, they replace existing. Null clears nullable fields on update. |

### Comments

| Tool | Description |
|------|-------------|
| `list_comments` | List comments on an issue, project, initiative, or project status update (exactly one parent). Cursor-paginated. |
| `save_comment` | Create or update a comment. On create, exactly one of `issue` / `project` / `initiative` / `projectUpdate` identifies the parent. Supports threaded replies via `parentId`. |
| `delete_comment` | Delete a comment by ID. |

### Projects

| Tool | Description |
|------|-------------|
| `list_projects` | List projects, optionally scoped to a team. Returns id, name, and status. |
| `get_project` | Retrieve a project by name, ID, or slug. Optional includes for members, milestones, and resources. |
| `save_project` | Create or update a project. On create, `name` and `teams` (one or more) are required. Resolves names to IDs for teams, lead, members, labels, status, and initiative (initiative links on creation only — use `add_project_to_initiative` afterwards). |
| `archive_project` | Archive a project (recoverable soft delete). Linear has no hard-delete for projects. |

### Initiatives

| Tool | Description |
|------|-------------|
| `list_initiatives` | List initiatives with filters (status, owner, parent initiative, date ranges) and cursor pagination. Optional `includeProjects` adds linked projects. |
| `get_initiative` | Retrieve an initiative by name or ID. Returns linked projects. Optional `includeSubInitiatives`. |
| `save_initiative` | Create or update an initiative. Resolves `owner` and `parentInitiative` names to IDs. Exposes both `description` (short summary, ~255 chars) and `content` (long Markdown). |
| `delete_initiative` | Delete an initiative. `archive: true` soft-deletes via `initiativeArchive`. Hard delete is refused while projects are still linked — unlink first or archive. |
| `add_project_to_initiative` | Link a project to an initiative. |
| `remove_project_from_initiative` | Unlink a project from an initiative; finds and deletes the underlying join record. |

### Status updates

| Tool | Description |
|------|-------------|
| `list_status_updates` | List status updates posted to a project or initiative (exactly one parent). Cursor-paginated. |
| `get_status_update` | Retrieve a status update by ID — transparently fetches whichever parent type owns it. |
| `save_status_update` | Create or update a status update on a project or initiative. `health` enum: `onTrack` / `atRisk` / `offTrack`. Body is Markdown. |
| `delete_status_update` | Archive a status update by ID. Linear has no hard-delete for status updates; this maps to `*UpdateArchive`. |

### Workspace

| Tool | Description |
|------|-------------|
| `list_teams` | List all teams. Returns id, name, and key. |
| `get_team` | Retrieve a team by id, key (e.g., `VIB`), or name. |
| `list_users` | List users, optionally scoped to a team. |
| `get_user` | Retrieve a user by id, name, email, or `"me"`. |
| `list_cycles` | List cycles for a team. Returns id, name, number, startsAt, endsAt. |
| `list_issue_statuses` | List workflow states for a team. Returns id, type (`backlog`, `unstarted`, `started`, `completed`, `canceled`, `triage`, `duplicate`), and name. |
| `get_issue_status` | Retrieve a workflow state by name or UUID, team-scoped. |
| `list_issue_labels` | List issue labels, optionally scoped to a team. |
| `create_issue_label` | Create an issue label. Omit `team` for a workspace-wide label. |

## Development

```bash
git clone git@github.com:hoblin/linear-toon-mcp.git
cd linear-toon-mcp
bundle install
bundle exec rspec        # run tests
bundle exec standardrb   # lint
```

## Versioning

[Semantic versioning](https://semver.org/). Breaking tool removals or rename go in a major bump, new tools or new optional parameters go in a minor, fixes and internal refactors go in a patch. The single source of truth is `lib/linear_toon_mcp/version.rb`.

## Releasing

1. Update the version in `lib/linear_toon_mcp/version.rb`
2. Commit: `git commit -am "Bump version to x.y.z"`
3. Tag: `git tag vx.y.z`
4. Push: `git push origin main --tags`

The [release workflow](.github/workflows/release.yml) will run CI and publish the gem to RubyGems.org via [trusted publishing](https://guides.rubygems.org/trusted-publishing/).

## License

MIT
