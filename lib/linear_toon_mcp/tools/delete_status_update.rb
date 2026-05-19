# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Archive a status update by id. Linear has no hard-delete mutation
    # for status updates — archiving is the canonical "delete" operation
    # and matches the official Linear MCP server's behaviour.
    # Determines the parent type (project vs initiative) by lookup, then
    # calls the corresponding archive mutation.
    class DeleteStatusUpdate < Base
      description "Archive a status update (project or initiative)"

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Status update ID"}
        },
        required: ["id"],
        additionalProperties: false
      )

      PROJECT_ARCHIVE_MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          projectUpdateArchive(id: $id) { success entity { id archivedAt } }
        }
      GRAPHQL

      INITIATIVE_ARCHIVE_MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          initiativeUpdateArchive(id: $id) { success entity { id archivedAt } }
        }
      GRAPHQL

      def perform(id:)
        update = GetStatusUpdate.new.perform(id: id)
        if update.key?("project")
          archive(PROJECT_ARCHIVE_MUTATION, "projectUpdateArchive", id)
        else
          archive(INITIATIVE_ARCHIVE_MUTATION, "initiativeUpdateArchive", id)
        end
      end

      private

      def archive(mutation, mutation_key, id)
        data = client.query(mutation, variables: {id: id})
        result = data[mutation_key] or raise Error, "Status update archive failed: no result returned"
        raise Error, "Status update archive failed" unless result["success"]
        result["entity"]
      end
    end
  end
end
