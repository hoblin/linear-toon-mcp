# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # List projects in the Linear workspace, optionally scoped to a team.
    # Returns TOON-encoded array of projects with id, name, and state.
    class ListProjects < MCP::Tool
      description "List projects in the workspace"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          team: {type: "string", description: "Team name or ID (optional)"}
        },
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($filter: ProjectFilter) {
          projects(filter: $filter) { nodes { id name state } }
        }
      GRAPHQL

      class << self
        # @param team [String, nil] team name or UUID (optional scope)
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded project list or error
        def call(team: nil, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"

          variables = {}
          if team
            team_id = Resolvers.resolve_team(client, team)
            variables[:filter] = {accessibleTeams: {id: {eq: team_id}}}
          end

          data = client.query(QUERY, variables:)
          projects = data["projects"] or raise Error, "Unexpected response: missing projects field"
          text = Toon.encode(projects)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
    end
  end
end
