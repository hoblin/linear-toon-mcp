# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create a Linear issue label. Optionally scope the label to a team
    # — omit +team+ to create a workspace-wide label.
    class CreateIssueLabel < Create
      description "Create a Linear issue label, optionally scoped to a team"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          name: {type: "string", description: "Label name"},
          color: {type: "string", description: "Hex color (e.g., #5E6AD2)"},
          team: {type: "string", description: "Team name, key, or UUID. Omit for a workspace-wide label"}
        },
        required: ["name"],
        additionalProperties: false
      )

      MUTATION = <<~GRAPHQL
        mutation($input: IssueLabelCreateInput!) {
          issueLabelCreate(input: $input) {
            success
            issueLabel {
              id
              name
              color
              team { id name }
            }
          }
        }
      GRAPHQL

      def variables(name:, color: nil, team: nil)
        input = {name: name}
        input[:color] = color if color
        input[:teamId] = Resolvers::Team.call(value: team) if team
        {input: input}
      end
    end
  end
end
