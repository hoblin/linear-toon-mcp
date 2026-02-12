# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # Update an existing Linear issue by ID. Supports partial updates,
    # null to remove fields, and relation replacement semantics.
    class UpdateIssue < MCP::Tool
      description "Update an existing Linear issue"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: true
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          id: {type: "string", description: "Issue ID"},
          title: {type: "string", description: "Issue title"},
          team: {type: "string", description: "Team name or ID"},
          description: {type: "string", description: "Content as Markdown"},
          assignee: {type: ["string", "null"], description: 'User ID, name, email, or "me". Null to remove'},
          priority: {type: "number", description: "0=None, 1=Urgent, 2=High, 3=Normal, 4=Low"},
          state: {type: "string", description: "State name or ID"},
          labels: {type: "array", items: {type: "string"}, description: "Label names or IDs"},
          project: {type: "string", description: "Project name or ID"},
          cycle: {type: "string", description: "Cycle name, number, or ID"},
          estimate: {type: "number", description: "Issue estimate value"},
          dueDate: {type: "string", description: "Due date (ISO format)"},
          parentId: {type: ["string", "null"], description: "Parent issue ID. Null to remove"},
          blockedBy: {type: "array", items: {type: "string"}, description: "Issue IDs blocking this. Replaces existing; omit to keep unchanged"},
          blocks: {type: "array", items: {type: "string"}, description: "Issue IDs this blocks. Replaces existing; omit to keep unchanged"},
          relatedTo: {type: "array", items: {type: "string"}, description: "Related issue IDs. Replaces existing; omit to keep unchanged"},
          duplicateOf: {type: ["string", "null"], description: "Duplicate of issue ID. Null to remove"},
          milestone: {type: "string", description: "Milestone name or ID"},
          delegate: {type: ["string", "null"], description: "Agent name or ID. Null to remove"},
          links: {type: "array", items: {type: "object", properties: {url: {type: "string"}, title: {type: "string"}}, required: ["url", "title"]}, description: "Link attachments [{url, title}]"}
        },
        required: ["id"],
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: IssueUpdateInput!) {
          issueUpdate(id: $id, input: $input) {
            success
            issue {
              id identifier title url
              state { name }
              assignee { id name }
              team { id name }
              labels { nodes { name } }
              project { id name }
            }
          }
        }
      GRAPHQL

      RELATIONS_QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) {
            relations { nodes { id type relatedIssue { id } } }
          }
        }
      GRAPHQL

      RELATION_DELETE_MUTATION = <<~GRAPHQL
        mutation($id: String!) {
          issueRelationDelete(id: $id) { success }
        }
      GRAPHQL

      ISSUE_TEAM_QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) { team { id } }
        }
      GRAPHQL

      RELATION_TYPE_MAP = {
        blockedBy: "isBlockedBy",
        blocks: "blocks",
        relatedTo: "related",
        duplicateOf: "duplicate"
      }.freeze

      # standard:disable Naming/VariableName, Metrics/MethodLength
      class << self
        # @param id [String] issue ID
        # @param server_context [Hash, nil] must contain +:client+ key
        # @return [MCP::Tool::Response] TOON-encoded issue or error
        def call(id:, server_context: nil, **kwargs)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"

          input = {}
          team_id = resolve_team_id(client, id, kwargs)
          build_input(input, client, team_id, kwargs)

          data = client.query(MUTATION, variables: {id:, input:})
          result = data["issueUpdate"]
          raise Error, "Issue update failed" unless result["success"]

          issue = result["issue"]
          replace_relations(client, id, kwargs)
          create_links(client, id, kwargs[:links])

          text = Toon.encode(issue)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end

        private

        def resolve_team_id(client, issue_id, kwargs)
          return Resolvers.resolve_team(client, kwargs[:team]) if kwargs.key?(:team)
          return unless needs_team_id?(kwargs)

          data = client.query(ISSUE_TEAM_QUERY, variables: {id: issue_id})
          data.dig("issue", "team", "id") or raise Error, "Could not determine issue team"
        end

        def needs_team_id?(kwargs)
          kwargs.key?(:state) || kwargs.key?(:cycle)
        end

        def build_input(input, client, team_id, kwargs)
          add_direct_fields(input, kwargs)
          add_nullable_fields(input, client, kwargs)
          add_resolved_fields(input, client, team_id, kwargs)
        end

        def add_direct_fields(input, kwargs)
          {title: :title, description: :description, priority: :priority,
           estimate: :estimate, dueDate: :dueDate}.each do |key, field|
            input[field] = kwargs[key] if kwargs.key?(key)
          end
        end

        def add_nullable_fields(input, client, kwargs)
          if kwargs.key?(:assignee)
            input[:assigneeId] = kwargs[:assignee] ? Resolvers.resolve_user(client, kwargs[:assignee]) : nil
          end
          if kwargs.key?(:delegate)
            input[:assigneeId] = kwargs[:delegate] ? Resolvers.resolve_user(client, kwargs[:delegate]) : nil
          end
          input[:parentId] = kwargs[:parentId] if kwargs.key?(:parentId)
        end

        def add_resolved_fields(input, client, team_id, kwargs)
          if kwargs.key?(:team) && kwargs[:team]
            input[:teamId] = Resolvers.resolve_team(client, kwargs[:team])
          end
          if kwargs.key?(:state) && team_id
            input[:stateId] = Resolvers.resolve_state(client, team_id, kwargs[:state])
          end
          input[:labelIds] = Resolvers.resolve_labels(client, kwargs[:labels]) if kwargs.key?(:labels)
          if kwargs.key?(:project) && kwargs[:project]
            project_id = Resolvers.resolve_project(client, kwargs[:project])
            input[:projectId] = project_id
          end
          if kwargs.key?(:milestone)
            raise Error, "milestone requires project" unless project_id
            input[:projectMilestoneId] = Resolvers.resolve_milestone(client, project_id, kwargs[:milestone])
          end
          input[:cycleId] = Resolvers.resolve_cycle(client, team_id, kwargs[:cycle]) if kwargs.key?(:cycle) && team_id
        end

        def replace_relations(client, issue_id, kwargs)
          RELATION_TYPE_MAP.each do |param, type|
            next unless kwargs.key?(param)
            values = (param == :duplicateOf) ? [kwargs[param]].compact : Array(kwargs[param])
            delete_existing_relations(client, issue_id, type)
            values.each do |related_id|
              input = {issueId: issue_id, relatedIssueId: related_id, type:}
              client.query(CreateIssue::RELATION_MUTATION, variables: {input:})
            end
          end
        end

        def delete_existing_relations(client, issue_id, type)
          data = client.query(RELATIONS_QUERY, variables: {id: issue_id})
          relations = data.dig("issue", "relations", "nodes") || []
          relations.each do |rel|
            next unless rel["type"] == type
            del = client.query(RELATION_DELETE_MUTATION, variables: {id: rel["id"]})
            next if del.dig("issueRelationDelete", "success")
            raise Error, "Failed to delete #{type} relation #{rel["id"]}"
          end
        end

        def create_links(client, issue_id, links)
          return unless links

          links.each do |link|
            vars = {url: link["url"], issueId: issue_id, title: link["title"]}
            data = client.query(CreateIssue::LINK_MUTATION, variables: vars)
            next if data.dig("attachmentLinkURL", "success")
            raise Error, "Failed to attach link: #{link["url"]}"
          end
        end
      end
      # standard:enable Naming/VariableName, Metrics/MethodLength
    end
  end
end
