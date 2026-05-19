# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Fetch a single status update by id. Returns the update regardless
    # of whether it belongs to a project or an initiative — the parent
    # is included in the response.
    class GetStatusUpdate < Base
      description "Retrieve a status update by ID (project or initiative)"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Status update ID"}
        },
        required: ["id"],
        additionalProperties: false
      )

      READ_FIELDS = <<~GRAPHQL
        id
        body
        health
        isStale
        isDiffHidden
        createdAt
        updatedAt
        editedAt
        archivedAt
        url
        user { id name }
      GRAPHQL

      PROJECT_UPDATE_QUERY = <<~GRAPHQL
        query($id: String!) {
          projectUpdate(id: $id) {
            #{READ_FIELDS.strip}
            project { id name }
          }
        }
      GRAPHQL

      INITIATIVE_UPDATE_QUERY = <<~GRAPHQL
        query($id: String!) {
          initiativeUpdate(id: $id) {
            #{READ_FIELDS.strip}
            initiative { id name }
          }
        }
      GRAPHQL

      def perform(id:)
        fetch_project_update(id) || fetch_initiative_update(id) ||
          raise(Error, "Status update not found: #{id}")
      end

      private

      def fetch_project_update(id)
        data = client.query(PROJECT_UPDATE_QUERY, variables: {id: id})
        data["projectUpdate"]
      rescue Error => e
        # Linear surfaces missing records as a GraphQL "Entity not found"
        # error; swallow only that case so the fallback gets a turn.
        raise unless e.message.include?("Entity not found")
      end

      def fetch_initiative_update(id)
        data = client.query(INITIATIVE_UPDATE_QUERY, variables: {id: id})
        data["initiativeUpdate"]
      rescue Error => e
        raise unless e.message.include?("Entity not found")
      end
    end
  end
end
