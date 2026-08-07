# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Delete a project milestone by id. Issues assigned to the milestone
    # are detached, not deleted.
    class DeleteProjectMilestone < Delete
      description "Delete a project milestone (issues are detached, not deleted)"

      label "Milestone"

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Milestone ID"}
        },
        required: ["id"],
        additionalProperties: false
      )

      MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          projectMilestoneDelete(id: $id) { success entityId }
        }
      GRAPHQL

      def variables(id:)
        {id: id}
      end
    end
  end
end
