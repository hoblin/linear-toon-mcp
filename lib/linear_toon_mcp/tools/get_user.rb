# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Fetch a single Linear user by id, name, email, or the literal "me".
    class GetUser < Get
      description "Retrieve a Linear user by id, name, email, or \"me\""

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          query: {type: "string", description: 'User name, email, UUID, or "me"'}
        },
        required: ["query"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($id: String!) {
          user(id: $id) {
            id
            name
            displayName
            email
            active
            admin
            createdAt
          }
        }
      GRAPHQL

      def perform(query:)
        user_id = Resolvers::User.call(value: query)
        data = client.query(QUERY, variables: {id: user_id})
        data["user"] or raise Error, "User not found: #{query}"
      end
    end
  end
end
