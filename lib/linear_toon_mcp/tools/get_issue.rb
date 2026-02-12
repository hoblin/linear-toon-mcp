# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    class GetIssue < MCP::Tool
      description "Retrieve a Linear issue by ID"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Issue ID or identifier (e.g., LIN-123)"}
        },
        required: ["id"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) {
            id
            identifier
            title
            description
            priority
            url
            createdAt
            updatedAt
            state { name }
            assignee { name }
            labels { nodes { name } }
          }
        }
      GRAPHQL

      class << self
        def call(id:, server_context: nil)
          client = server_context&.dig(:client) || Client.new
          data = client.query(QUERY, variables: {id:})
          text = Toon.encode(data["issue"])
          MCP::Tool::Response.new([{type: "text", text:}])
        end
      end
    end
  end
end
