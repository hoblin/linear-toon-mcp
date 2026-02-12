# frozen_string_literal: true

RSpec.describe LinearToonMcp, ".server" do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:server) { described_class.server(client:) }

  describe "initialize" do
    subject(:result) do
      server.handle(jsonrpc: "2.0", id: 1, method: "initialize",
        params: {protocolVersion: "2024-11-05", capabilities: {}, clientInfo: {name: "test"}})
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
    subject(:result) { server.handle(jsonrpc: "2.0", id: 1, method: "tools/list", params: {}) }

    it "lists all tools" do
      expect(result[:result][:tools]).to contain_exactly(
        include(name: "get_issue", description: "Retrieve a Linear issue by ID"),
        include(name: "list_issues", description: "List issues with optional filters and pagination"),
        include(name: "list_issue_statuses", description: "List available issue statuses in a Linear team"),
        include(name: "create_comment", description: "Create a comment on a Linear issue"),
        include(name: "create_issue", description: "Create a new Linear issue"),
        include(name: "update_issue", description: "Update an existing Linear issue")
      )
    end
  end
end
