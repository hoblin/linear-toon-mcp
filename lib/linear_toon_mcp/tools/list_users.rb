# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List users in the Linear workspace, optionally scoped to a team.
    # Returns TOON-encoded array of users with id, name, and email.
    class ListUsers < List
      description "List users, optionally scoped to a team"

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
        query {
          users { nodes { id name email } }
        }
      GRAPHQL

      TEAM_MEMBERS_QUERY = <<~GRAPHQL
        query($id: String!) {
          team(id: $id) { members { nodes { id name email } } }
        }
      GRAPHQL

      # @param team [String, nil] team name or UUID (optional scope)
      def perform(team: nil)
        return super if team.nil?
        team_id = Resolvers::Team.call(value: team)
        data = client.query(TEAM_MEMBERS_QUERY, variables: {id: team_id})
        data.dig("team", "members") or raise Error, "Unexpected response: missing team members field"
      end
    end
  end
end
