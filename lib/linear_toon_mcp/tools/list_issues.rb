# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # List Linear issues with optional filters and pagination.
    # Returns TOON-encoded array with page info for cursor-based pagination.
    class ListIssues < MCP::Tool
      description "List issues with optional filters and pagination"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          assignee: {type: "string", description: 'User ID, name, email, or "me"'},
          createdAt: {type: "string", description: "Created after: ISO-8601 date/duration (e.g., -P1D)"},
          cursor: {type: "string", description: "Next page cursor"},
          cycle: {type: "string", description: "Cycle name, number, or ID"},
          delegate: {type: "string", description: "Agent name or ID"},
          includeArchived: {type: "boolean", description: "Include archived items (default true)"},
          label: {type: "string", description: "Label name or ID"},
          limit: {type: "integer", description: "Max results (default 50, max 250)"},
          orderBy: {type: "string", description: "createdAt or updatedAt (default updatedAt)", enum: ["createdAt", "updatedAt"]},
          parentId: {type: "string", description: "Parent issue ID"},
          priority: {type: "integer", description: "0=None, 1=Urgent, 2=High, 3=Normal, 4=Low"},
          project: {type: "string", description: "Project name or ID"},
          query: {type: "string", description: "Search issue title or description"},
          state: {type: "string", description: "State name or ID"},
          team: {type: "string", description: "Team name or ID"},
          updatedAt: {type: "string", description: "Updated after: ISO-8601 date/duration (e.g., -P1D)"}
        },
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($filter: IssueFilter, $first: Int, $after: String, $orderBy: PaginationOrderBy, $includeArchived: Boolean) {
          issues(filter: $filter, first: $first, after: $after, orderBy: $orderBy, includeArchived: $includeArchived) {
            nodes {
              id
              identifier
              title
              priority
              priorityLabel
              url
              createdAt
              updatedAt
              state { name }
              assignee { id name }
              labels { nodes { name } }
              project { id name }
              team { id name }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      GRAPHQL

      UUID_RE = Resolvers::UUID_RE
      NUMERIC_RE = Resolvers::NUMERIC_RE

      # standard:disable Naming/VariableName
      class << self
        # @param assignee [String, nil] user ID, name, email, or "me"
        # @param createdAt [String, nil] ISO-8601 date or duration
        # @param cursor [String, nil] pagination cursor
        # @param cycle [String, nil] cycle name, number, or ID
        # @param delegate [String, nil] agent name or ID
        # @param includeArchived [Boolean, nil] include archived issues
        # @param label [String, nil] label name or ID
        # @param limit [Integer, nil] max results (default 50, max 250)
        # @param orderBy [String, nil] "createdAt" or "updatedAt"
        # @param parentId [String, nil] parent issue ID
        # @param priority [Integer, nil] 0-4
        # @param project [String, nil] project name or ID
        # @param query [String, nil] search title or description
        # @param state [String, nil] state name or ID
        # @param team [String, nil] team name or ID
        # @param updatedAt [String, nil] ISO-8601 date or duration
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded issue list or error
        def call(assignee: nil, createdAt: nil, cursor: nil, cycle: nil,
          delegate: nil, includeArchived: nil, label: nil, limit: nil, orderBy: nil,
          parentId: nil, priority: nil, project: nil, query: nil, state: nil,
          team: nil, updatedAt: nil, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"

          filter = build_filter(
            assignee:, team:, project:, state:, label:,
            priority:, parentId:, cycle:, delegate:,
            query:, createdAt:, updatedAt:
          )

          variables = {
            first: (limit || 50).clamp(1, 250),
            orderBy: orderBy || "updatedAt",
            includeArchived: includeArchived != false
          }
          variables[:filter] = filter unless filter.empty?
          variables[:after] = cursor if cursor

          data = client.query(QUERY, variables:)
          issues = data["issues"] or raise Error, "Unexpected response: missing issues field"
          text = Toon.encode(issues)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end

        private

        def build_filter(assignee:, team:, project:, state:, label:,
          priority:, parentId:, cycle:, delegate:,
          query:, createdAt:, updatedAt:)
          filter = {}
          filter[:assignee] = assignee_filter(assignee) if assignee
          filter[:team] = name_or_id(team) if team
          filter[:project] = name_or_id(project) if project
          filter[:state] = name_or_id(state) if state
          filter[:labels] = {some: name_or_id(label)} if label
          filter[:priority] = {eq: priority} if priority
          filter[:parent] = {id: {eq: parentId}} if parentId
          filter[:cycle] = cycle_filter(cycle) if cycle
          filter[:delegate] = name_or_id(delegate) if delegate
          if query
            filter[:or] = [
              {title: {containsIgnoreCase: query}},
              {description: {containsIgnoreCase: query}}
            ]
          end
          filter[:createdAt] = {gte: resolve_date(createdAt)} if createdAt
          filter[:updatedAt] = {gte: resolve_date(updatedAt)} if updatedAt
          filter
        end
        # standard:enable Naming/VariableName

        def assignee_filter(value)
          return {isMe: {eq: true}} if value == "me"
          return {id: {eq: value}} if value.match?(UUID_RE)
          return {email: {eq: value}} if value.include?("@")
          {name: {eqIgnoreCase: value}}
        end

        def name_or_id(value)
          value.match?(UUID_RE) ? {id: {eq: value}} : {name: {eqIgnoreCase: value}}
        end

        def cycle_filter(value)
          return {id: {eq: value}} if value.match?(UUID_RE)
          return {number: {eq: value.to_i}} if value.match?(NUMERIC_RE)
          {name: {eqIgnoreCase: value}}
        end

        def resolve_date(value)
          return value unless value.start_with?("-P")
          match = value.match(/\A-P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?\z/)
          raise Error, "Invalid duration: #{value}" unless match
          days = match.captures.zip([365, 30, 7, 1]).sum { |c, m| (c&.to_i || 0) * m }
          (Time.now.utc - (days * 86_400)).iso8601
        end
      end
    end
  end
end
