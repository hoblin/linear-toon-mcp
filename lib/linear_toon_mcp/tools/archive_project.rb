# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Archive a Linear project by name or UUID. Linear's project archive
    # is recoverable (matches the Linear UI's archive behaviour);
    # there's no hard-delete equivalent and we intentionally don't
    # expose one.
    class ArchiveProject < Base
      description "Archive a Linear project (soft delete via projectArchive)"

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          project: {type: "string", description: "Project name or UUID"}
        },
        required: ["project"],
        additionalProperties: false
      )

      MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          projectArchive(id: $id) { success entity { id name archivedAt } }
        }
      GRAPHQL

      def perform(project:)
        project_id = Resolvers::Project.call(value: project)
        data = client.query(MUTATION, variables: {id: project_id})
        result = data["projectArchive"] or raise Error, "Project archive failed: no result returned"
        raise Error, "Project archive failed" unless result["success"]
        result["entity"]
      end
    end
  end
end
