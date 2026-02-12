# frozen_string_literal: true

require "mcp"
require_relative "linear_toon_mcp/version"
require_relative "linear_toon_mcp/client"
require_relative "linear_toon_mcp/tools/echo"
require_relative "linear_toon_mcp/tools/get_issue"

module LinearToonMcp
  class Error < StandardError; end

  def self.server(client: Client.new)
    MCP::Server.new(
      name: "linear-toon-mcp",
      version: VERSION,
      description: "Manage Linear issues, projects, and teams",
      tools: [Tools::Echo, Tools::GetIssue],
      server_context: {client:}
    )
  end
end
