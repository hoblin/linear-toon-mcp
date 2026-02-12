# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # List cycles for a Linear team.
    # Returns TOON-encoded array of cycles with id, name, number, startsAt, and endsAt.
    class ListCycles < MCP::Tool
      description "List cycles for a team"

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
        query($filter: CycleFilter) {
          cycles(filter: $filter) { nodes { id name number startsAt endsAt } }
        }
      GRAPHQL

      class << self
        # @param team [String] team name or UUID
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded cycle list or error
        def call(team:, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"
          team_id = Resolvers.resolve_team(client, team)
          data = client.query(QUERY, variables: {filter: {team: {id: {eq: team_id}}}})
          cycles = data["cycles"] or raise Error, "Unexpected response: missing cycles field"
          text = Toon.encode(cycles)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
    end
  end
end
