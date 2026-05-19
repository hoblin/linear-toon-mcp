# frozen_string_literal: true

require "mcp"
require_relative "linear_toon_mcp/version"
require_relative "linear_toon_mcp/client"
require_relative "linear_toon_mcp/resolvers"
require_relative "linear_toon_mcp/tools"

# Token-efficient MCP server for Linear. Wraps Linear's GraphQL API
# and returns TOON-formatted responses for ~40-60% token savings.
module LinearToonMcp
  # Raised on Linear API HTTP errors, GraphQL errors, or missing data.
  class Error < StandardError; end

  class << self
    # Returns the active Linear API client, lazily instantiated from
    # +LINEAR_API_KEY+ on first access.
    def client
      @client ||= Client.new
    end

    # Assigns the active Linear API client.
    attr_writer :client
  end

  # Builds the configured MCP::Server with all registered tools.
  # @return [MCP::Server]
  def self.server
    MCP::Server.new(
      name: "linear-toon-mcp",
      version: VERSION,
      description: "Manage Linear issues, projects, and teams",
      tools: [
        Tools::GetIssue, Tools::ListIssues, Tools::ListIssueStatuses,
        Tools::ListTeams, Tools::ListUsers, Tools::ListIssueLabels,
        Tools::ListProjects, Tools::ListCycles, Tools::GetProject,
        Tools::CreateComment, Tools::ListComments,
        Tools::CreateIssue, Tools::UpdateIssue,
        Tools::ListInitiatives, Tools::GetInitiative, Tools::SaveInitiative,
        Tools::DeleteInitiative, Tools::AddProjectToInitiative,
        Tools::RemoveProjectFromInitiative,
        Tools::ListStatusUpdates, Tools::GetStatusUpdate,
        Tools::SaveStatusUpdate, Tools::DeleteStatusUpdate
      ]
    )
  end
end
