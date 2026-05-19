# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a Linear issue. +id+ presence determines create
    # vs update. Resolves human-friendly names to IDs for team, assignee,
    # state, labels, project, cycle, and milestone. Relation params and
    # +parentId+ accept either issue UUIDs or human identifiers
    # (e.g., LIN-123).
    class SaveIssue < Base
      description "Create or update a Linear issue (id presence determines)"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          id: {type: "string", description: "Issue ID. If provided, updates the existing issue"},
          title: {type: "string", description: "Issue title (required when creating)"},
          team: {type: "string", description: "Team name or ID (required when creating)"},
          description: {type: "string", description: "Content as Markdown"},
          assignee: {type: ["string", "null"], description: 'User ID, name, email, or "me". Null to remove (update only)'},
          priority: {type: "number", description: "0=None, 1=Urgent, 2=High, 3=Normal, 4=Low"},
          state: {type: "string", description: "State name or ID"},
          labels: {type: "array", items: {type: "string"}, description: "Label names or IDs"},
          project: {type: "string", description: "Project name or ID"},
          cycle: {type: "string", description: "Cycle name, number, or ID"},
          estimate: {type: "number", description: "Issue estimate value"},
          dueDate: {type: "string", description: "Due date (ISO format)"},
          parentId: {type: ["string", "null"], description: "Parent issue UUID or identifier. Null to remove (update only)"},
          blocks: {type: "array", items: {type: "string"}, description: "Issue UUIDs or identifiers this blocks. On update, replaces existing"},
          relatedTo: {type: "array", items: {type: "string"}, description: "Related issue UUIDs or identifiers. On update, replaces existing"},
          duplicateOf: {type: ["string", "null"], description: "Duplicate-of issue UUID or identifier. Null to remove (update only)"},
          milestone: {type: "string", description: "Milestone name or ID"},
          delegate: {type: ["string", "null"], description: "Agent name or ID. Null to remove (update only)"},
          links: {type: "array", items: {type: "object", properties: {url: {type: "string"}, title: {type: "string"}}, required: ["url", "title"]}, description: "Link attachments [{url, title}]. Appended on both create and update"}
        },
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      ISSUE_FIELDS = <<~GRAPHQL
        id identifier title url
        state { name }
        assignee { id name }
        team { id name }
        labels { nodes { name } }
        project { id name }
      GRAPHQL

      CREATE_MUTATION = <<~GRAPHQL
        mutation($input: IssueCreateInput!) {
          issueCreate(input: $input) {
            success
            issue { #{ISSUE_FIELDS.strip} }
          }
        }
      GRAPHQL

      UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: IssueUpdateInput!) {
          issueUpdate(id: $id, input: $input) {
            success
            issue { #{ISSUE_FIELDS.strip} }
          }
        }
      GRAPHQL

      RELATION_CREATE_MUTATION = <<~GRAPHQL
        mutation($input: IssueRelationCreateInput!) {
          issueRelationCreate(input: $input) { success }
        }
      GRAPHQL

      RELATION_DELETE_MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          issueRelationDelete(id: $id) { success }
        }
      GRAPHQL

      RELATIONS_QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) {
            relations { nodes { id type relatedIssue { id } } }
          }
        }
      GRAPHQL

      ISSUE_TEAM_QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) { team { id } }
        }
      GRAPHQL

      LINK_MUTATION = <<~GRAPHQL
        mutation($url: String!, $issueId: String!, $title: String) {
          attachmentLinkURL(url: $url, issueId: $issueId, title: $title) { success }
        }
      GRAPHQL

      RELATION_TYPE_MAP = {
        blocks: "blocks",
        relatedTo: "related",
        duplicateOf: "duplicate"
      }.freeze

      # standard:disable Naming/VariableName, Metrics/MethodLength
      def perform(id: nil, **kwargs)
        raise Error, "Cannot specify both assignee and delegate" if kwargs.key?(:assignee) && kwargs.key?(:delegate)
        id ? update(id, kwargs) : create(kwargs)
      end

      private

      def create(kwargs)
        title = kwargs[:title] or raise Error, "title is required when creating an issue"
        team = kwargs[:team] or raise Error, "team is required when creating an issue"
        team_id = Resolvers::Team.call(value: team)

        input = {title: title, teamId: team_id}
        add_direct_fields(input, kwargs)
        add_resolved_fields_create(input, team_id, kwargs)

        issue = submit(CREATE_MUTATION, "issueCreate", input: input)
        warnings = post_create(issue["id"], kwargs)
        warnings.empty? ? issue : respond_with_warnings(issue, warnings, context: "issue was created")
      end

      def update(id, kwargs)
        input = {}
        team_id = resolve_team_id(id, kwargs)
        add_direct_fields(input, kwargs)
        add_nullable_fields(input, kwargs)
        add_resolved_fields_update(input, team_id, kwargs)

        issue = submit(UPDATE_MUTATION, "issueUpdate", id: id, input: input)
        warnings = post_update(id, kwargs)
        warnings.empty? ? issue : respond_with_warnings(issue, warnings, context: "issue was updated")
      end

      def submit(mutation, mutation_key, **variables)
        data = client.query(mutation, variables: variables)
        result = data[mutation_key] or raise Error, "Issue save failed: no result returned"
        raise Error, "Issue save failed" unless result["success"]
        result["issue"]
      end

      def resolve_team_id(issue_id, kwargs)
        return Resolvers::Team.call(value: kwargs[:team]) if kwargs.key?(:team)
        return unless kwargs.key?(:state) || kwargs.key?(:cycle) || kwargs.key?(:labels)

        data = client.query(ISSUE_TEAM_QUERY, variables: {id: issue_id})
        data.dig("issue", "team", "id") or raise Error, "Could not determine issue team"
      end

      def add_direct_fields(input, kwargs)
        {description: :description, priority: :priority, estimate: :estimate,
         dueDate: :dueDate}.each do |key, field|
          input[field] = kwargs[key] if kwargs.key?(key)
        end
        input[:title] = kwargs[:title] if kwargs.key?(:title) && !input.key?(:title)
      end

      def add_nullable_fields(input, kwargs)
        if kwargs.key?(:assignee)
          input[:assigneeId] = kwargs[:assignee] ? Resolvers::User.call(value: kwargs[:assignee]) : nil
        end
        if kwargs.key?(:delegate)
          input[:assigneeId] = kwargs[:delegate] ? Resolvers::User.call(value: kwargs[:delegate]) : nil
        end
        input[:parentId] = kwargs[:parentId] if kwargs.key?(:parentId)
      end

      def add_resolved_fields_create(input, team_id, kwargs)
        if kwargs[:assignee] || kwargs[:delegate]
          input[:assigneeId] =
            Resolvers::User.call(value: kwargs[:delegate] || kwargs[:assignee])
        end
        input[:stateId] = Resolvers::WorkflowState.call(value: kwargs[:state], team_id: team_id) if kwargs[:state]
        input[:labelIds] = Resolvers::IssueLabel.call_many(values: kwargs[:labels], team_id: team_id) if kwargs[:labels]
        project_id = Resolvers::Project.call(value: kwargs[:project]) if kwargs[:project]
        input[:projectId] = project_id if project_id
        input[:cycleId] = Resolvers::Cycle.call(value: kwargs[:cycle], team_id: team_id) if kwargs[:cycle]
        input[:parentId] = kwargs[:parentId] if kwargs[:parentId]
        return unless kwargs[:milestone]
        raise Error, "milestone requires project" unless project_id
        input[:projectMilestoneId] = Resolvers::ProjectMilestone.call(value: kwargs[:milestone], project_id: project_id)
      end

      def add_resolved_fields_update(input, team_id, kwargs)
        input[:teamId] = team_id if kwargs.key?(:team) && team_id
        if kwargs.key?(:state) && team_id
          input[:stateId] = Resolvers::WorkflowState.call(value: kwargs[:state], team_id: team_id)
        end
        if kwargs.key?(:labels) && team_id
          input[:labelIds] = Resolvers::IssueLabel.call_many(values: kwargs[:labels], team_id: team_id)
        end
        project_id = nil
        if kwargs.key?(:project) && kwargs[:project]
          project_id = Resolvers::Project.call(value: kwargs[:project])
          input[:projectId] = project_id
        end
        if kwargs.key?(:milestone)
          raise Error, "milestone requires project" unless project_id
          input[:projectMilestoneId] =
            Resolvers::ProjectMilestone.call(value: kwargs[:milestone], project_id: project_id)
        end
        if kwargs.key?(:cycle) && team_id
          input[:cycleId] = Resolvers::Cycle.call(value: kwargs[:cycle], team_id: team_id)
        end
      end

      def post_create(issue_id, kwargs)
        warnings = []
        begin
          append_relations(issue_id, kwargs)
        rescue Error => e
          warnings << e.message
        end
        begin
          create_links(issue_id, kwargs[:links])
        rescue Error => e
          warnings << e.message
        end
        warnings
      end

      def post_update(issue_id, kwargs)
        warnings = []
        begin
          replace_relations(issue_id, kwargs)
        rescue Error => e
          warnings << e.message
        end
        begin
          create_links(issue_id, kwargs[:links])
        rescue Error => e
          warnings << e.message
        end
        warnings
      end

      def append_relations(issue_id, kwargs)
        Array(kwargs[:blocks]).each { |id| create_relation(issue_id, id, "blocks") }
        Array(kwargs[:relatedTo]).each { |id| create_relation(issue_id, id, "related") }
        create_relation(issue_id, kwargs[:duplicateOf], "duplicate") if kwargs[:duplicateOf]
      end

      def replace_relations(issue_id, kwargs)
        RELATION_TYPE_MAP.each do |param, type|
          next unless kwargs.key?(param)
          values = (param == :duplicateOf) ? [kwargs[param]].compact : Array(kwargs[param])
          delete_existing_relations(issue_id, type)
          values.each { |related_id| create_relation(issue_id, related_id, type) }
        end
      end

      def create_relation(issue_id, related_issue_id, type)
        input = {issueId: issue_id, relatedIssueId: related_issue_id, type: type}
        data = client.query(RELATION_CREATE_MUTATION, variables: {input: input})
        return if data.dig("issueRelationCreate", "success")
        raise Error, "Failed to create #{type} relation with #{related_issue_id}"
      end

      def delete_existing_relations(issue_id, type)
        data = client.query(RELATIONS_QUERY, variables: {id: issue_id})
        relations = data.dig("issue", "relations", "nodes") || []
        relations.each do |rel|
          next unless rel["type"] == type
          del = client.query(RELATION_DELETE_MUTATION, variables: {id: rel["id"]})
          next if del.dig("issueRelationDelete", "success")
          raise Error, "Failed to delete #{type} relation #{rel["id"]}"
        end
      end

      def create_links(issue_id, links)
        return unless links
        links.each do |link|
          vars = {url: link[:url], issueId: issue_id, title: link[:title]}
          data = client.query(LINK_MUTATION, variables: vars)
          next if data.dig("attachmentLinkURL", "success")
          raise Error, "Failed to attach link: #{link[:url]}"
        end
      end
      # standard:enable Naming/VariableName, Metrics/MethodLength
    end
  end
end
