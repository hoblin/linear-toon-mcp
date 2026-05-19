# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List all teams in the Linear workspace.
    # Returns TOON-encoded array of teams with id, name, and key.
    class ListTeams < List
      description "List teams in the workspace"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {},
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query {
          teams { nodes { id name key } }
        }
      GRAPHQL
    end
  end
end
