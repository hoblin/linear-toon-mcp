# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Fetch a single Linear team by id, key, or name.
    class GetTeam < Get
      description "Retrieve a Linear team by id, key, or name"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          query: {type: "string", description: "Team name, key (e.g., VIB), or UUID"}
        },
        required: ["query"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($id: String!) {
          team(id: $id) {
            id
            name
            key
            description
            color
            icon
            timezone
            createdAt
          }
        }
      GRAPHQL

      def perform(query:)
        team_id = Resolvers::Team.call(value: query)
        data = client.query(QUERY, variables: {id: team_id})
        data["team"] or raise Error, "Team not found: #{query}"
      end
    end
  end
end
