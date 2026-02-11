# frozen_string_literal: true

require "mcp"
require_relative "linear_toon_mcp/version"
require_relative "linear_toon_mcp/tools/echo"

module LinearToonMcp
  class Error < StandardError; end

  def self.server
    MCP::Server.new(
      name: "linear-toon-mcp",
      version: VERSION,
      description: "Token-efficient MCP server for Linear using TOON format",
      tools: [Tools::Echo]
    )
  end
end
