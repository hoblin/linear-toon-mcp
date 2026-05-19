# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List cycles for a Linear team.
    # Returns TOON-encoded array of cycles with id, name, number, startsAt, and endsAt.
    class ListCycles < List
      description "List cycles for a team"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          team: {type: "string", description: "Team name or ID"}
        },
        required: ["team"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($filter: CycleFilter) {
          cycles(filter: $filter) { nodes { id name number startsAt endsAt } }
        }
      GRAPHQL

      # @param team [String] team name or UUID
      def variables(team:)
        team_id = Resolvers::Team.call(value: team)
        {filter: {team: {id: {eq: team_id}}}}
      end
    end
  end
end
