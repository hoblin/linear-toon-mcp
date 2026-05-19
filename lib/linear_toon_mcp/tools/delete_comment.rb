# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Delete a comment by id.
    class DeleteComment < Delete
      description "Delete a comment"

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Comment ID"}
        },
        required: ["id"],
        additionalProperties: false
      )

      MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          commentDelete(id: $id) { success entityId }
        }
      GRAPHQL

      def variables(id:)
        {id: id}
      end
    end
  end
end
