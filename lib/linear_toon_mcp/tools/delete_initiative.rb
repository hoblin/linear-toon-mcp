# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Delete a Linear initiative by name or ID. Hard-deletes via
    # +initiativeDelete+ by default; pass +archive: true+ to soft-delete
    # via +initiativeArchive+. Hard deletes are refused when projects are
    # still linked to the initiative — unlink first or pass +archive: true+.
    class DeleteInitiative < Delete
      description "Delete a Linear initiative (hard by default; archive: true soft-deletes)"

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          query: {type: "string", description: "Initiative name or ID"},
          archive: {type: "boolean", description: "Archive (soft-delete) instead of hard delete (default false)"}
        },
        required: ["query"],
        additionalProperties: false
      )

      MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          initiativeDelete(id: $id) { success entityId }
        }
      GRAPHQL

      ARCHIVE_MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          initiativeArchive(id: $id) { success entity { id name archivedAt } }
        }
      GRAPHQL

      LINKED_PROJECTS_QUERY = <<~GRAPHQL
        query($id: String!) {
          initiative(id: $id) {
            projects(first: 1) { nodes { id } }
          }
        }
      GRAPHQL

      def perform(query:, archive: false)
        initiative_id = Resolvers::Initiative.call(value: query)
        archive ? archive_initiative(initiative_id) : hard_delete(initiative_id, query)
      end

      private

      def hard_delete(initiative_id, query)
        guard_linked_projects(initiative_id, query)
        data = client.query(MUTATION, variables: {id: initiative_id})
        result = data["initiativeDelete"] or raise Error, "Initiative deletion failed: no result returned"
        raise Error, "Initiative deletion failed" unless result["success"]
        {"success" => true, "entityId" => result["entityId"]}
      end

      def archive_initiative(initiative_id)
        data = client.query(ARCHIVE_MUTATION, variables: {id: initiative_id})
        result = data["initiativeArchive"] or raise Error, "Initiative archive failed: no result returned"
        raise Error, "Initiative archive failed" unless result["success"]
        result["entity"]
      end

      def guard_linked_projects(initiative_id, query)
        data = client.query(LINKED_PROJECTS_QUERY, variables: {id: initiative_id})
        nodes = data.dig("initiative", "projects", "nodes") || []
        return if nodes.empty?
        raise Error, "Initiative #{query.inspect} still has linked projects — unlink them first or pass archive: true"
      end
    end
  end
end
