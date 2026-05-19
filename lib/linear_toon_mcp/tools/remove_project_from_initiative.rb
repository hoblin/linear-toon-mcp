# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Unlink a project from an initiative. Accepts names or UUIDs for
    # both; resolves them through {Resolvers::Initiative} and
    # {Resolvers::Project}, finds the matching join record id, then
    # submits +initiativeToProjectDelete+.
    class RemoveProjectFromInitiative < Delete
      description "Unlink a project from an initiative"

      annotations(
        read_only_hint: false,
        destructive_hint: true,
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

      mutation :initiativeToProjectDelete
      entity :initiativeToProject
      label "Project-initiative link"

      MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          initiativeToProjectDelete(id: $id) { success entityId }
        }
      GRAPHQL

      LINK_LOOKUP_QUERY = <<~GRAPHQL
        query($projectId: String!) {
          project(id: $projectId) {
            initiativeToProjects { nodes { id initiative { id } } }
          }
        }
      GRAPHQL

      def variables(initiative:, project:)
        initiative_id = Resolvers::Initiative.call(value: initiative)
        project_id = Resolvers::Project.call(value: project)
        {id: lookup_join_id(initiative_id, project_id, initiative, project)}
      end

      private

      def lookup_join_id(initiative_id, project_id, initiative_label, project_label)
        data = client.query(LINK_LOOKUP_QUERY, variables: {projectId: project_id})
        nodes = data.dig("project", "initiativeToProjects", "nodes") || []
        match = nodes.find { |n| n.dig("initiative", "id") == initiative_id }
        return match["id"] if match
        raise Error, "Project #{project_label.inspect} is not linked to initiative #{initiative_label.inspect}"
      end
    end
  end
end
