# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # List comments on a Linear issue in chronological order.
    # Returns each comment's author, body, and timestamps.
    class ListComments < MCP::Tool
      description "List comments for a specific Linear issue"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          issueId: {type: "string", description: "Issue ID or identifier (e.g., LIN-123)"}
        },
        required: ["issueId"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) {
            comments(orderBy: createdAt) {
              nodes {
                id
                body
                createdAt
                editedAt
                user { id name }
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      class << self
        # @param issueId [String] Linear issue ID or identifier (e.g., "LIN-123")
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded comments connection or error
        def call(issueId:, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"
          data = client.query(QUERY, variables: {id: issueId})
          issue = data["issue"] or raise Error, "Issue not found: #{issueId}"
          text = Toon.encode(issue["comments"])
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
      # standard:enable Naming/VariableName
    end
  end
end
