# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # List available workflow states for a Linear team.
    # Returns TOON-encoded array of statuses with id, type, and name.
    class ListIssueStatuses < MCP::Tool
      description "List available issue statuses in a Linear team"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          team: {type: "string", description: "Team name or ID"}
        },
        required: ["team"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($filter: WorkflowStateFilter) {
          workflowStates(filter: $filter) { nodes { id type name } }
        }
      GRAPHQL

      class << self
        # @param team [String] team name or UUID
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded status list or error
        def call(team:, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"
          team_id = Resolvers.resolve_team(client, team)
          data = client.query(QUERY, variables: {filter: {team: {id: {eq: team_id}}}})
          states = data["workflowStates"] or raise Error, "Unexpected response: missing workflowStates field"
          text = Toon.encode(states)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
    end
  end
end
