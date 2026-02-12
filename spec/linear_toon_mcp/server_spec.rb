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
        include(name: "echo", description: "Accepts text input and returns it as-is"),
        include(name: "get_issue", description: "Retrieve a Linear issue by ID")
      )
    end
  end

  describe "tools/call" do
    subject(:result) do
      server.handle(jsonrpc: "2.0", id: 1, method: "tools/call",
        params: {name: "echo", arguments: {text: "ping"}})
    end

    it "returns the echoed text" do
      expect(result).to include(
        result: include(content: [{type: "text", text: "ping"}])
      )
    end
  end
end
