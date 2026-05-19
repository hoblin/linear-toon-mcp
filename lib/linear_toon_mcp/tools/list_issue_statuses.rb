# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List available workflow states for a Linear team.
    # Returns TOON-encoded array of statuses with id, type, and name.
    class ListIssueStatuses < List
      description "List available issue statuses in a Linear team"

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

      connection :workflowStates

      QUERY = <<~GRAPHQL
        query($filter: WorkflowStateFilter) {
          workflowStates(filter: $filter) { nodes { id type name } }
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
