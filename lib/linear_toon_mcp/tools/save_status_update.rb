# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a status update on a project or initiative.
    # +id+ presence determines create vs update. On create, exactly one of
    # +project:+ or +initiative:+ identifies the parent. On update, the
    # parent is inferred from the existing record — +project:+ and
    # +initiative:+ are ignored.
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
          project: {type: "string", description: "Project name or ID (create only; required when id is absent)"},
          initiative: {type: "string", description: "Initiative name or ID (create only; required when id is absent)"},
          body: {type: "string", description: "Update body as Markdown"},
          health: {type: "string", description: "Status update health indicator", enum: ["onTrack", "atRisk", "offTrack"]},
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
        input = build_input(fields)
        id ? update(id, input) : create(project: project, initiative: initiative, input: input)
      end

      private

      def create(project:, initiative:, input:)
        parent = exactly_one_parent(project: project, initiative: initiative)
        case parent
        in [:project, value]
          project_id = Resolvers::Project.call(value: value)
          submit(PROJECT_CREATE_MUTATION, "projectUpdateCreate", "projectUpdate",
            variables: {input: input.merge(projectId: project_id)})
        in [:initiative, value]
          initiative_id = Resolvers::Initiative.call(value: value)
          submit(INITIATIVE_CREATE_MUTATION, "initiativeUpdateCreate", "initiativeUpdate",
            variables: {input: input.merge(initiativeId: initiative_id)})
        end
      end

      def update(id, input)
        existing = GetStatusUpdate.new.perform(id: id)
        if existing.key?("project")
          submit(PROJECT_UPDATE_MUTATION, "projectUpdateUpdate", "projectUpdate",
            variables: {id: id, input: input})
        else
          submit(INITIATIVE_UPDATE_MUTATION, "initiativeUpdateUpdate", "initiativeUpdate",
            variables: {id: id, input: input})
        end
      end

      def exactly_one_parent(project:, initiative:)
        raise Error, "Provide exactly one of `project` or `initiative`" if (project && initiative) || (!project && !initiative)
        project ? [:project, project] : [:initiative, initiative]
      end

      def build_input(fields)
        input = {}
        {body: :body, health: :health, isDiffHidden: :isDiffHidden}.each do |key, field|
          input[field] = fields[key] if fields.key?(key)
        end
        input
      end

      def submit(mutation, mutation_key, entity_key, variables:)
        data = client.query(mutation, variables: variables)
        result = data[mutation_key] or raise Error, "Status update save failed: no result returned"
        raise Error, "Status update save failed" unless result["success"]
        result[entity_key]
      end
      # standard:enable Naming/VariableName
    end
  end
end
