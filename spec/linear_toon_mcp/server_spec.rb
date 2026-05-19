# frozen_string_literal: true

RSpec.describe LinearToonMcp, ".server" do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:server) { described_class.server }

  before { described_class.client = client }

  describe "initialize" do
    subject(:result) do
      server.handle({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {protocolVersion: MCP::Configuration::LATEST_STABLE_PROTOCOL_VERSION, capabilities: {}, clientInfo: {name: "test"}}
      })
    end

    it "returns server info in handshake response" do
      expect(result).to include(
        result: include(
          serverInfo: include(:description, name: "linear-toon-mcp", version: LinearToonMcp::VERSION)
        )
      )
    end
  end

  describe "tools/list" do
    subject(:result) { server.handle({jsonrpc: "2.0", id: 1, method: "tools/list", params: {}}) }

    it "lists all tools" do
      expect(result[:result][:tools]).to contain_exactly(
        include(name: "get_issue", description: "Retrieve a Linear issue by ID, including its parent and direct child issues"),
        include(name: "list_issues", description: "List issues with optional filters and pagination"),
        include(name: "list_issue_statuses", description: "List available issue statuses in a Linear team"),
        include(name: "list_teams", description: "List teams in the workspace"),
        include(name: "list_users", description: "List users, optionally scoped to a team"),
        include(name: "list_issue_labels", description: "List issue labels, optionally scoped to a team"),
        include(name: "list_projects", description: "List projects, optionally scoped to a team"),
        include(name: "list_cycles", description: "List cycles for a team"),
        include(name: "get_project", description: "Retrieve details of a specific project in Linear"),
        include(name: "save_issue", description: "Create or update a Linear issue (id presence determines)"),
        include(name: "save_comment", description: "Create or update a comment on an issue, project, initiative, or project status update"),
        include(name: "delete_comment", description: "Delete a comment"),
        include(name: "list_comments", description: "List comments on an issue, project, initiative, or project status update"),
        include(name: "list_initiatives", description: "List initiatives with optional filters and pagination"),
        include(name: "get_initiative", description: "Retrieve a Linear initiative by name or ID, with linked projects"),
        include(name: "save_initiative", description: "Create or update a Linear initiative (id presence determines)"),
        include(name: "delete_initiative", description: "Delete a Linear initiative (hard by default; archive: true soft-deletes)"),
        include(name: "add_project_to_initiative", description: "Link a project to an initiative"),
        include(name: "remove_project_from_initiative", description: "Unlink a project from an initiative"),
        include(name: "list_status_updates", description: "List status updates on a project or initiative"),
        include(name: "get_status_update", description: "Retrieve a status update by ID (project or initiative)"),
        include(name: "save_status_update", description: "Create or update a project or initiative status update"),
        include(name: "delete_status_update", description: "Archive a status update (project or initiative)"),
        include(name: "save_project", description: "Create or update a Linear project (id presence determines)"),
        include(name: "archive_project", description: "Archive a Linear project (soft delete via projectArchive)"),
        include(name: "get_team", description: "Retrieve a Linear team by id, key, or name"),
        include(name: "get_user", description: 'Retrieve a Linear user by id, name, email, or "me"'),
        include(name: "get_issue_status", description: "Retrieve an issue status (workflow state) by name or UUID, scoped to a team"),
        include(name: "create_issue_label", description: "Create a Linear issue label, optionally scoped to a team")
      )
    end
  end
end
