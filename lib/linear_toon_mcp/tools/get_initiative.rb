# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Fetch a single Linear initiative by ID or name, with the projects
    # linked to it.
    class GetInitiative < Get
      description "Retrieve a Linear initiative by name or ID, with linked projects"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          query: {type: "string", description: "Initiative name or ID"},
          includeSubInitiatives: {type: "boolean", description: "Include sub-initiatives (default: false)"}
        },
        required: ["query"],
        additionalProperties: false
      )

      BASE_FIELDS = <<~GRAPHQL
        id
        name
        description
        content
        status
        color
        icon
        targetDate
        createdAt
        updatedAt
        archivedAt
        url
        owner { id name }
        parentInitiative { id name }
        projects { nodes { id name } }
      GRAPHQL

      SUB_INITIATIVES_FIELDS = "subInitiatives { nodes { id name status } }"

      # standard:disable Naming/VariableName
      # @param query [String] initiative name or UUID
      def perform(query:, includeSubInitiatives: false)
        initiative_id = Resolvers::Initiative.call(value: query)
        graphql = build_query(includeSubInitiatives: includeSubInitiatives)
        data = client.query(graphql, variables: {id: initiative_id})
        data["initiative"] or raise Error, "Initiative not found: #{query}"
      end

      private

      def build_query(includeSubInitiatives:)
        fields = [BASE_FIELDS.strip]
        fields << SUB_INITIATIVES_FIELDS if includeSubInitiatives

        <<~GRAPHQL
          query($id: String!) {
            initiative(id: $id) {
              #{fields.join("\n        ")}
            }
          }
        GRAPHQL
      end
      # standard:enable Naming/VariableName
    end
  end
end
