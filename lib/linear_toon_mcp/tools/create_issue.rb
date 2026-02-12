# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # Create a new Linear issue with full parameter support.
    # Resolves human-friendly names to IDs for team, assignee, state, labels,
    # project, cycle, and milestone. Supports post-mutation relations and links.
    class CreateIssue < MCP::Tool
      description "Create a new Linear issue"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          title: {type: "string", description: "Issue title"},
          team: {type: "string", description: "Team name or ID"},
          description: {type: "string", description: "Content as Markdown"},
          assignee: {type: "string", description: 'User ID, name, email, or "me"'},
          priority: {type: "number", description: "0=None, 1=Urgent, 2=High, 3=Normal, 4=Low"},
          state: {type: "string", description: "State name or ID"},
          labels: {type: "array", items: {type: "string"}, description: "Label names or IDs"},
          project: {type: "string", description: "Project name or ID"},
          cycle: {type: "string", description: "Cycle name, number, or ID"},
          estimate: {type: "number", description: "Issue estimate value"},
          dueDate: {type: "string", description: "Due date (ISO format)"},
          parentId: {type: "string", description: "Parent issue ID"},
          blockedBy: {type: "array", items: {type: "string"}, description: "Issue IDs/identifiers blocking this"},
          blocks: {type: "array", items: {type: "string"}, description: "Issue IDs/identifiers this blocks"},
          relatedTo: {type: "array", items: {type: "string"}, description: "Related issue IDs/identifiers"},
          duplicateOf: {type: "string", description: "Duplicate of issue ID/identifier"},
          milestone: {type: "string", description: "Milestone name or ID"},
          delegate: {type: "string", description: "Agent name or ID"},
          links: {type: "array", items: {type: "object", properties: {url: {type: "string"}, title: {type: "string"}}, required: ["url", "title"]}, description: "Link attachments [{url, title}]"}
        },
        required: ["title", "team"],
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      MUTATION = <<~GRAPHQL
        mutation($input: IssueCreateInput!) {
          issueCreate(input: $input) {
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

      RELATION_MUTATION = <<~GRAPHQL
        mutation($input: IssueRelationCreateInput!) {
          issueRelationCreate(input: $input) { success }
        }
      GRAPHQL

      LINK_MUTATION = <<~GRAPHQL
        mutation($url: String!, $issueId: String!, $title: String) {
          attachmentLinkURL(url: $url, issueId: $issueId, title: $title) { success }
        }
      GRAPHQL

      # standard:disable Naming/VariableName, Metrics/MethodLength
      class << self
        # @param title [String] issue title
        # @param team [String] team name or UUID
        # @param server_context [Hash, nil] must contain +:client+ key
        # @return [MCP::Tool::Response] TOON-encoded issue or error
        def call(title:, team:, server_context: nil, **kwargs)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"

          team_id = Resolvers.resolve_team(client, team)
          input = {title:, teamId: team_id}

          add_direct_fields(input, **kwargs)
          resolve_fields(input, client, team_id, **kwargs)

          data = client.query(MUTATION, variables: {input:})
          result = data["issueCreate"]
          raise Error, "Issue creation failed" unless result["success"]

          issue = result["issue"]
          create_relations(client, issue["id"], **kwargs)
          create_links(client, issue["id"], kwargs[:links])

          text = Toon.encode(issue)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end

        private

        def add_direct_fields(input, description: nil, priority: nil, estimate: nil,
          dueDate: nil, parentId: nil, **)
          input[:description] = description if description
          input[:priority] = priority if priority
          input[:estimate] = estimate if estimate
          input[:dueDate] = dueDate if dueDate
          input[:parentId] = parentId if parentId
        end

        def resolve_fields(input, client, team_id, assignee: nil, state: nil, labels: nil,
          project: nil, cycle: nil, milestone: nil, delegate: nil, **)
          input[:assigneeId] = Resolvers.resolve_user(client, delegate || assignee) if assignee || delegate
          input[:stateId] = Resolvers.resolve_state(client, team_id, state) if state
          input[:labelIds] = Resolvers.resolve_labels(client, labels) if labels
          project_id = Resolvers.resolve_project(client, project) if project
          input[:projectId] = project_id if project_id
          input[:cycleId] = Resolvers.resolve_cycle(client, team_id, cycle) if cycle
          if milestone
            raise Error, "milestone requires project" unless project_id
            input[:projectMilestoneId] = Resolvers.resolve_milestone(client, project_id, milestone)
          end
        end

        def create_relations(client, issue_id, blockedBy: nil, blocks: nil, relatedTo: nil, duplicateOf: nil, **)
          Array(blockedBy).each { |id| create_relation(client, issue_id, id, "isBlockedBy") }
          Array(blocks).each { |id| create_relation(client, issue_id, id, "blocks") }
          Array(relatedTo).each { |id| create_relation(client, issue_id, id, "related") }
          create_relation(client, issue_id, duplicateOf, "duplicate") if duplicateOf
        end

        def create_relation(client, issue_id, related_issue_id, type)
          input = {issueId: issue_id, relatedIssueId: related_issue_id, type:}
          data = client.query(RELATION_MUTATION, variables: {input:})
          return if data.dig("issueRelationCreate", "success")
          raise Error, "Failed to create #{type} relation with #{related_issue_id}"
        end

        def create_links(client, issue_id, links)
          return unless links

          links.each do |link|
            data = client.query(LINK_MUTATION, variables: {url: link["url"], issueId: issue_id, title: link["title"]})
            next if data.dig("attachmentLinkURL", "success")
            raise Error, "Failed to attach link: #{link["url"]}"
          end
        end
      end
      # standard:enable Naming/VariableName, Metrics/MethodLength
    end
  end
end
