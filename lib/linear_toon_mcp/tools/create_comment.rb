# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # Create a comment on a Linear issue. Supports Markdown content
    # and threaded replies via parentId.
    class CreateComment < MCP::Tool
      description "Create a comment on a Linear issue"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          issueId: {type: "string", description: "Issue ID"},
          body: {type: "string", description: "Content as Markdown"},
          parentId: {type: "string", description: "Parent comment ID (for replies)"}
        },
        required: ["issueId", "body"],
        additionalProperties: false
      )

      MUTATION = <<~GRAPHQL
        mutation($input: CommentCreateInput!) {
          commentCreate(input: $input) {
            success
            comment {
              id
              body
              createdAt
              user { id name }
              issue { id identifier }
            }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      class << self
        # @param issueId [String] Linear issue ID
        # @param body [String] comment content as Markdown
        # @param parentId [String, nil] parent comment ID for threaded replies
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded comment or error
        def call(issueId:, body:, parentId: nil, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"

          input = {issueId:, body:}
          input[:parentId] = parentId if parentId

          data = client.query(MUTATION, variables: {input:})
          result = data["commentCreate"]
          raise Error, "Comment creation failed" unless result["success"]

          text = Toon.encode(result["comment"])
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end
      end
      # standard:enable Naming/VariableName
    end
  end
end
