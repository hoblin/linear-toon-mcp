# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List issue labels in the Linear workspace, optionally scoped to a team.
    # Returns TOON-encoded array of labels with id and name.
    class ListIssueLabels < List
      description "List issue labels, optionally scoped to a team"

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
        query($filter: IssueLabelFilter) {
          issueLabels(filter: $filter) { nodes { id name } }
        }
      GRAPHQL

      # @param team [String, nil] team name or UUID (optional scope)
      def variables(team: nil)
        return {} unless team
        team_id = Resolvers::Team.call(value: team)
        {filter: {team: {id: {eq: team_id}}}}
      end
    end
  end
end
