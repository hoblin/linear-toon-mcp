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
            priorityLabel
            url
            branchName
            createdAt
            updatedAt
            archivedAt
            completedAt
            dueDate
            state { name }
            assignee { id name }
            creator { id name }
            labels { nodes { name } }
            project { id name }
            team { id name }
            attachments { nodes { id title url } }
          }
        }
      GRAPHQL

      class << self
        # @param id [String] Linear issue ID or identifier (e.g., "LIN-123")
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded issue or error
        def call(id:, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"
          data = client.query(QUERY, variables: {id:})
          issue = data["issue"] or raise Error, "Issue not found: #{id}"
          text = Toon.encode(issue)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
    end
  end
end
