# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create a comment on a Linear issue. Supports Markdown content
    # and threaded replies via parentId.
    class CreateComment < Create
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
      def variables(issueId:, body:, parentId: nil)
        input = {issueId:, body:}
        input[:parentId] = parentId if parentId
        {input:}
      end
      # standard:enable Naming/VariableName
    end
  end
end
