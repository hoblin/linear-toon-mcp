# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List projects in the Linear workspace, optionally scoped to a team.
    # Returns TOON-encoded array of projects with id, name, and state.
    class ListProjects < List
      description "List projects, optionally scoped to a team"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          team: {type: "string", description: "Team name or ID"}
        },
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($filter: ProjectFilter) {
          projects(filter: $filter) { nodes { id name state } }
        }
      GRAPHQL

      # @param team [String, nil] team name or UUID (optional scope)
      def variables(team: nil)
        return {} unless team
        team_id = Resolvers::Team.call(value: team)
        {filter: {accessibleTeams: {id: {eq: team_id}}}}
      end
    end
  end
end
