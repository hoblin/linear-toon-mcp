# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Fetch a single workflow state (issue status) by name or UUID,
    # scoped to a team.
    class GetIssueStatus < Get
      description "Retrieve an issue status (workflow state) by name or UUID, scoped to a team"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          query: {type: "string", description: "State name (e.g., In Progress) or UUID"},
          team: {type: "string", description: "Team name, key, or UUID"}
        },
        required: ["query", "team"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($id: String!) {
          workflowState(id: $id) {
            id
            name
            type
            description
            color
            position
            team { id name }
          }
        }
      GRAPHQL

      def perform(query:, team:)
        team_id = Resolvers::Team.call(value: team)
        state_id = Resolvers::WorkflowState.call(value: query, team_id: team_id)
        data = client.query(QUERY, variables: {id: state_id})
        data["workflowState"] or raise Error, "Issue status not found: #{query}"
      end
    end
  end
end
