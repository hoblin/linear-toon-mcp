# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a status update on a Linear project or initiative.
    # When +id+ is present, updates the existing record; otherwise creates
    # a new one. Exactly one of +project:+ or +initiative:+ identifies the
    # parent.
    class SaveStatusUpdate < Base
      description "Create or update a project or initiative status update"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Status update ID. If provided, updates the existing record"},
          project: {type: "string", description: "Project name or ID (provide exactly one parent)"},
          initiative: {type: "string", description: "Initiative name or ID (provide exactly one parent)"},
          body: {type: "string", description: "Update body as Markdown"},
          health: {type: "string", description: "Project health indicator", enum: ["onTrack", "atRisk", "offTrack"]},
          isDiffHidden: {type: "boolean", description: "Hide auto-generated diff from the update"}
        },
        additionalProperties: false
      )

      RETURN_FIELDS = <<~GRAPHQL
        id
        body
        health
        isStale
        isDiffHidden
        createdAt
        updatedAt
        editedAt
        url
        user { id name }
      GRAPHQL

      PROJECT_CREATE_MUTATION = <<~GRAPHQL
        mutation($input: ProjectUpdateCreateInput!) {
          projectUpdateCreate(input: $input) {
            success
            projectUpdate {
              #{RETURN_FIELDS.strip}
              project { id name }
            }
          }
        }
      GRAPHQL

      PROJECT_UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: ProjectUpdateUpdateInput!) {
          projectUpdateUpdate(id: $id, input: $input) {
            success
            projectUpdate {
              #{RETURN_FIELDS.strip}
              project { id name }
            }
          }
        }
      GRAPHQL

      INITIATIVE_CREATE_MUTATION = <<~GRAPHQL
        mutation($input: InitiativeUpdateCreateInput!) {
          initiativeUpdateCreate(input: $input) {
            success
            initiativeUpdate {
              #{RETURN_FIELDS.strip}
              initiative { id name }
            }
          }
        }
      GRAPHQL

      INITIATIVE_UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: InitiativeUpdateUpdateInput!) {
          initiativeUpdateUpdate(id: $id, input: $input) {
            success
            initiativeUpdate {
              #{RETURN_FIELDS.strip}
              initiative { id name }
            }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      def perform(id: nil, project: nil, initiative: nil, **fields)
        parent = exactly_one_parent(project: project, initiative: initiative)
        input = build_input(fields)

        case [id, parent]
        in [nil, [:project, value]]
          create_project_update(value, input)
        in [nil, [:initiative, value]]
          create_initiative_update(value, input)
        in [_, [:project, _]]
          update_project_update(id, input)
        in [_, [:initiative, _]]
          update_initiative_update(id, input)
        end
      end

      private

      def exactly_one_parent(project:, initiative:)
        raise Error, "Provide exactly one of project: or initiative:" if (project && initiative) || (!project && !initiative)
        project ? [:project, project] : [:initiative, initiative]
      end

      def build_input(fields)
        input = {}
        input[:body] = fields[:body] if fields.key?(:body)
        input[:health] = fields[:health] if fields.key?(:health)
        input[:isDiffHidden] = fields[:isDiffHidden] if fields.key?(:isDiffHidden)
        input
      end

      def create_project_update(value, input)
        project_id = Resolvers::Project.call(value: value)
        data = client.query(PROJECT_CREATE_MUTATION, variables: {input: input.merge(projectId: project_id)})
        extract(data, "projectUpdateCreate", "projectUpdate", verb: "creation")
      end

      def create_initiative_update(value, input)
        initiative_id = Resolvers::Initiative.call(value: value)
        data = client.query(INITIATIVE_CREATE_MUTATION, variables: {input: input.merge(initiativeId: initiative_id)})
        extract(data, "initiativeUpdateCreate", "initiativeUpdate", verb: "creation")
      end

      def update_project_update(id, input)
        data = client.query(PROJECT_UPDATE_MUTATION, variables: {id: id, input: input})
        extract(data, "projectUpdateUpdate", "projectUpdate", verb: "update")
      end

      def update_initiative_update(id, input)
        data = client.query(INITIATIVE_UPDATE_MUTATION, variables: {id: id, input: input})
        extract(data, "initiativeUpdateUpdate", "initiativeUpdate", verb: "update")
      end

      def extract(data, mutation_key, entity_key, verb:)
        result = data[mutation_key] or raise Error, "Status update #{verb} failed: no result returned"
        raise Error, "Status update #{verb} failed" unless result["success"]
        result[entity_key]
      end
      # standard:enable Naming/VariableName
    end
  end
end
