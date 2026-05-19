# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Link a project to an initiative. Resolves both names to UUIDs via
    # {Resolvers::Initiative} and {Resolvers::Project} and creates the
    # {InitiativeToProject} join record. The returned +id+ is the join
    # record's id — pass it to {RemoveProjectFromInitiative} to unlink.
    class AddProjectToInitiative < Create
      description "Link a project to an initiative"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          initiative: {type: "string", description: "Initiative name or ID"},
          project: {type: "string", description: "Project name or ID"}
        },
        required: ["initiative", "project"],
        additionalProperties: false
      )

      mutation :initiativeToProjectCreate
      entity :initiativeToProject
      label "Project-initiative link"

      MUTATION = <<~GRAPHQL
        mutation($input: InitiativeToProjectCreateInput!) {
          initiativeToProjectCreate(input: $input) {
            success
            initiativeToProject {
              id
              initiative { id name }
              project { id name }
            }
          }
        }
      GRAPHQL

      def variables(initiative:, project:)
        initiative_id = Resolvers::Initiative.call(value: initiative)
        project_id = Resolvers::Project.call(value: project)
        {input: {initiativeId: initiative_id, projectId: project_id}}
      end
    end
  end
end
