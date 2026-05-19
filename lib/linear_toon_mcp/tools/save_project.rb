# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a Linear project. +id+ presence determines create
    # vs update. On create, +name+ and +teams+ are required. Resolves
    # human-friendly names to IDs for teams, lead, members, labels,
    # status, and initiative. Linking to an initiative is a create-only
    # convenience — use {AddProjectToInitiative} on existing projects.
    class SaveProject < Base
      description "Create or update a Linear project (id presence determines)"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          id: {type: "string", description: "Project ID. If provided, updates the existing project"},
          name: {type: "string", description: "Project name (required when creating)"},
          teams: {type: "array", items: {type: "string"}, description: "Team names or UUIDs (required when creating; at least one)"},
          description: {type: "string", description: "Short summary"},
          content: {type: "string", description: "Long-form content as Markdown"},
          status: {type: "string", description: "Project status name or UUID (e.g., Planned, In Progress, Completed, Canceled)"},
          lead: {type: ["string", "null"], description: 'User name, email, UUID, or "me". Null to remove (update only)'},
          members: {type: "array", items: {type: "string"}, description: "User names, emails, or UUIDs"},
          startDate: {type: "string", description: "Start date (ISO format)"},
          targetDate: {type: "string", description: "Target date (ISO format)"},
          priority: {type: "number", description: "0=None, 1=Urgent, 2=High, 3=Medium, 4=Low"},
          labels: {type: "array", items: {type: "string"}, description: "Label names or UUIDs"},
          initiative: {type: "string", description: "Initiative name or UUID to link the project to (create only — rejected on update; use add_project_to_initiative for existing projects)"}
        },
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      PROJECT_FIELDS = <<~GRAPHQL
        id
        name
        description
        url
        priority
        priorityLabel
        startDate
        targetDate
        status { id name }
        lead { id name }
        teams { nodes { id name } }
      GRAPHQL

      CREATE_MUTATION = <<~GRAPHQL
        mutation($input: ProjectCreateInput!) {
          projectCreate(input: $input) {
            success
            project { #{PROJECT_FIELDS.strip} }
          }
        }
      GRAPHQL

      UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: ProjectUpdateInput!) {
          projectUpdate(id: $id, input: $input) {
            success
            project { #{PROJECT_FIELDS.strip} }
          }
        }
      GRAPHQL

      INITIATIVE_LINK_MUTATION = <<~GRAPHQL
        mutation($input: InitiativeToProjectCreateInput!) {
          initiativeToProjectCreate(input: $input) { success }
        }
      GRAPHQL

      # standard:disable Naming/VariableName, Metrics/MethodLength
      def perform(id: nil, **kwargs)
        if id
          reject_create_only_on_update(initiative: kwargs[:initiative])
          update(id, kwargs)
        else
          create(kwargs)
        end
      end

      private

      def create(kwargs)
        name = kwargs[:name] or raise Error, "name is required when creating a project"
        teams = kwargs[:teams] or raise Error, "teams is required when creating a project"
        raise Error, "teams must include at least one team" if teams.empty?

        team_ids = teams.map { |t| Resolvers::Team.call(value: t) }
        input = {name: name, teamIds: team_ids}
        add_direct_fields(input, kwargs)
        add_resolved_fields(input, kwargs)

        project = submit(CREATE_MUTATION, "projectCreate", input: input)
        warnings = post_create(project["id"], kwargs)
        warnings.empty? ? project : respond_with_warnings(project, warnings, context: "project was created")
      end

      def update(id, kwargs)
        input = {}
        add_direct_fields(input, kwargs)
        add_resolved_fields(input, kwargs)
        add_nullable_fields(input, kwargs)
        add_teams(input, kwargs) if kwargs.key?(:teams)
        submit(UPDATE_MUTATION, "projectUpdate", id: id, input: input)
      end

      def submit(mutation, mutation_key, **variables)
        data = client.query(mutation, variables: variables)
        result = data[mutation_key] or raise Error, "Project save failed: no result returned"
        raise Error, "Project save failed" unless result["success"]
        result["project"]
      end

      def add_direct_fields(input, kwargs)
        {description: :description, content: :content, startDate: :startDate,
         targetDate: :targetDate, priority: :priority}.each do |key, field|
          input[field] = kwargs[key] if kwargs.key?(key)
        end
        input[:name] = kwargs[:name] if kwargs.key?(:name) && !input.key?(:name)
      end

      def add_resolved_fields(input, kwargs)
        input[:statusId] = Resolvers::ProjectStatus.call(value: kwargs[:status]) if kwargs[:status]
        input[:leadId] = Resolvers::User.call(value: kwargs[:lead]) if kwargs[:lead]
        input[:memberIds] = kwargs[:members].map { |m| Resolvers::User.call(value: m) } if kwargs[:members]
        input[:labelIds] = Resolvers::IssueLabel.call_many(values: kwargs[:labels]) if kwargs[:labels]
      end

      def add_nullable_fields(input, kwargs)
        input[:leadId] = nil if kwargs.key?(:lead) && kwargs[:lead].nil?
      end

      def add_teams(input, kwargs)
        input[:teamIds] = kwargs[:teams].map { |t| Resolvers::Team.call(value: t) }
      end

      def post_create(project_id, kwargs)
        warnings = []
        if kwargs[:initiative]
          begin
            link_initiative(project_id, kwargs[:initiative])
          rescue Error => e
            warnings << e.message
          end
        end
        warnings
      end

      def link_initiative(project_id, initiative)
        initiative_id = Resolvers::Initiative.call(value: initiative)
        data = client.query(INITIATIVE_LINK_MUTATION,
          variables: {input: {projectId: project_id, initiativeId: initiative_id}})
        return if data.dig("initiativeToProjectCreate", "success")
        raise Error, "Failed to link project to initiative #{initiative.inspect}"
      end

      def reject_create_only_on_update(**create_only_fields)
        given = create_only_fields.compact.keys
        return if given.empty?
        names = given.map { |k| "`#{k}`" }.join(", ")
        raise Error, "Cannot pass #{names} on update — use add_project_to_initiative for existing projects"
      end
      # standard:enable Naming/VariableName, Metrics/MethodLength
    end
  end
end
