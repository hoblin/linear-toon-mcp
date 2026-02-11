# frozen_string_literal: true

RSpec.describe LinearToonMcp, ".server" do
  subject(:server) { described_class.server }

  it "responds to MCP protocol handshake" do
    response = server.handle({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test" } }
    })

    expect(response[:result][:serverInfo][:name]).to eq("linear-toon-mcp")
    expect(response[:result][:serverInfo][:version]).to eq(LinearToonMcp::VERSION)
  end

  it "lists the echo tool" do
    response = server.handle({ jsonrpc: "2.0", id: 2, method: "tools/list" })

    tools = response[:result][:tools]
    expect(tools.size).to eq(1)
    expect(tools.first[:name]).to eq("echo")
    expect(tools.first[:description]).to eq("Accepts text input and returns it as-is")
  end

  it "calls the echo tool and returns text as-is" do
    response = server.handle({
      jsonrpc: "2.0",
      id: 3,
      method: "tools/call",
      params: { name: "echo", arguments: { text: "ping" } }
    })

    expect(response[:result][:content]).to eq([{ type: "text", text: "ping" }])
  end
end
