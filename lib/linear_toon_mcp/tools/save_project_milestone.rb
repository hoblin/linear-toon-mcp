# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a project milestone. +id+ presence determines
    # create vs update. On create, +name+ and +project+ are required;
    # +project+ is resolved via {Resolvers::Project}. Linear has no
    # move-between-projects update, so +project+ is rejected on update.
    class SaveProjectMilestone < Base
      description "Create or update a project milestone (id presence determines)"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          id: {type: "string", description: "Milestone ID. If provided, updates the existing milestone; otherwise creates"},
          project: {type: "string", description: "Project name, ID, or slug (required when creating — rejected on update)"},
          name: {type: "string", description: "Milestone name (required when creating)"},
          description: {type: "string", description: "Description as Markdown"},
          targetDate: {type: "string", description: "Target date (ISO format, YYYY-MM-DD)"},
          sortOrder: {type: "number", description: "Position among the project's milestones — lower sorts first"}
        },
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      RETURN_FIELDS = <<~GRAPHQL
        id
        name
        description
        targetDate
        sortOrder
        status
        project { id name }
      GRAPHQL

      CREATE_MUTATION = <<~GRAPHQL
        mutation($input: ProjectMilestoneCreateInput!) {
          projectMilestoneCreate(input: $input) {
            success
            projectMilestone { #{RETURN_FIELDS.strip} }
          }
        }
      GRAPHQL

      UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: ProjectMilestoneUpdateInput!) {
          projectMilestoneUpdate(id: $id, input: $input) {
            success
            projectMilestone { #{RETURN_FIELDS.strip} }
          }
        }
      GRAPHQL

      def perform(id: nil, **kwargs)
        id ? update(id, kwargs) : create(kwargs)
      end

      private

      def create(kwargs)
        raise Error, "name is required when creating a milestone" unless kwargs[:name]
        project = kwargs[:project] or raise Error, "project is required when creating a milestone"

        input = build_input(kwargs).merge(projectId: Resolvers::Project.call(value: project))
        submit(CREATE_MUTATION, "projectMilestoneCreate", input:)
      end

      def update(id, kwargs)
        if kwargs.key?(:project)
          raise Error, "Cannot pass `project` on update — milestones cannot be moved between projects"
        end

        submit(UPDATE_MUTATION, "projectMilestoneUpdate", id:, input: build_input(kwargs))
      end

      def submit(mutation, mutation_key, **variables)
        data = client.query(mutation, variables:)
        result = data[mutation_key] or raise Error, "Milestone save failed: no result returned"
        raise Error, "Milestone save failed" unless result["success"]
        result["projectMilestone"]
      end

      def build_input(kwargs)
        {name: :name, description: :description, targetDate: :targetDate,
         sortOrder: :sortOrder}.each_with_object({}) do |(key, field), input|
          input[field] = kwargs[key] if kwargs.key?(key)
        end
      end
    end
  end
end
