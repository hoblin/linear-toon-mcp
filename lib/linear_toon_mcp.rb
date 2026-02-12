# frozen_string_literal: true

require "mcp"
require_relative "linear_toon_mcp/version"
require_relative "linear_toon_mcp/client"
require_relative "linear_toon_mcp/resolvers"
require_relative "linear_toon_mcp/tools/get_issue"
require_relative "linear_toon_mcp/tools/list_issues"
require_relative "linear_toon_mcp/tools/create_comment"
require_relative "linear_toon_mcp/tools/create_issue"
require_relative "linear_toon_mcp/tools/update_issue"
require_relative "linear_toon_mcp/tools/list_issue_statuses"
require_relative "linear_toon_mcp/tools/list_teams"
require_relative "linear_toon_mcp/tools/list_users"
require_relative "linear_toon_mcp/tools/list_issue_labels"
require_relative "linear_toon_mcp/tools/list_projects"
require_relative "linear_toon_mcp/tools/list_cycles"

# Token-efficient MCP server for Linear. Wraps Linear's GraphQL API
# and returns TOON-formatted responses for ~40-60% token savings.
module LinearToonMcp
  # Raised on Linear API HTTP errors, GraphQL errors, or missing data.
  class Error < StandardError; end

  # Build a configured MCP::Server with all registered tools.
  # @param client [Client] Linear API client (defaults to new instance from ENV)
  # @return [MCP::Server]
  def self.server(client: Client.new)
    MCP::Server.new(
      name: "linear-toon-mcp",
      version: VERSION,
      description: "Manage Linear issues, projects, and teams",
      tools: [Tools::GetIssue, Tools::ListIssues, Tools::ListIssueStatuses, Tools::ListTeams, Tools::ListUsers, Tools::ListIssueLabels, Tools::ListProjects, Tools::ListCycles, Tools::CreateComment, Tools::CreateIssue, Tools::UpdateIssue],
      server_context: {client:}
    )
  end
end
