# frozen_string_literal: true

RSpec.describe LinearToonMcp, ".server" do
  subject(:server) { described_class.server }

  def rpc(method, id: 1, **params)
    server.handle({ jsonrpc: "2.0", id:, method:, params: })
  end

  describe "initialize" do
    subject(:result) { rpc("initialize", protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test" }) }

    it "returns server info in handshake response" do
      expect(result).to include(
        result: include(
          serverInfo: { name: "linear-toon-mcp", version: LinearToonMcp::VERSION }
        )
      )
    end
  end

  describe "tools/list" do
    subject(:result) { rpc("tools/list") }

    it "lists the echo tool" do
      expect(result[:result][:tools]).to contain_exactly(
        include(name: "echo", description: "Accepts text input and returns it as-is")
      )
    end
  end

  describe "tools/call" do
    subject(:result) { rpc("tools/call", name: "echo", arguments: { text: "ping" }) }

    it "returns the echoed text" do
      expect(result).to include(
        result: include(content: [{ type: "text", text: "ping" }])
      )
    end
  end
end
