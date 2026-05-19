# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List comments on a Linear issue in chronological order.
    # Returns each comment's author, body, and timestamps.
    class ListComments < List
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
      # @param issueId [String] Linear issue ID or identifier (e.g., "LIN-123")
      def perform(issueId:)
        data = client.query(QUERY, variables: {id: issueId})
        issue = data["issue"] or raise Error, "Issue not found: #{issueId}"
        issue["comments"]
      end
      # standard:enable Naming/VariableName
    end
  end
end
