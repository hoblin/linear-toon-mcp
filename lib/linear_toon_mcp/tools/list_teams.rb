# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # List all teams in the Linear workspace.
    # Returns TOON-encoded array of teams with id, name, and key.
    class ListTeams < MCP::Tool
      description "List teams in the workspace"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {},
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query {
          teams { nodes { id name key } }
        }
      GRAPHQL

      class << self
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded team list or error
        def call(server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"
          data = client.query(QUERY)
          teams = data["teams"] or raise Error, "Unexpected response: missing teams field"
          text = Toon.encode(teams)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
    end
  end
end
