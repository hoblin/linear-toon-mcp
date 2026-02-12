# frozen_string_literal: true

module LinearToonMcp
  # Shared resolvers for converting human-friendly names to Linear API UUIDs.
  # Each resolver passes through UUIDs unchanged and performs a GraphQL lookup otherwise.
  module Resolvers
    UUID_RE = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    NUMERIC_RE = /\A\d+\z/

    TEAM_QUERY = <<~GRAPHQL
      query($filter: TeamFilter) {
        teams(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    VIEWER_QUERY = "query { viewer { id } }"

    USER_QUERY = <<~GRAPHQL
      query($filter: UserFilter) {
        users(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    STATE_QUERY = <<~GRAPHQL
      query($filter: WorkflowStateFilter) {
        workflowStates(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    LABEL_QUERY = <<~GRAPHQL
      query($filter: IssueLabelFilter) {
        issueLabels(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    PROJECT_QUERY = <<~GRAPHQL
      query($filter: ProjectFilter) {
        projects(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    CYCLE_QUERY = <<~GRAPHQL
      query($filter: CycleFilter) {
        cycles(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    MILESTONE_QUERY = <<~GRAPHQL
      query($filter: ProjectMilestoneFilter) {
        projectMilestones(filter: $filter, first: 1) { nodes { id } }
      }
    GRAPHQL

    module_function

    # @param client [Client]
    # @param value [String] team UUID or name
    # @return [String] team UUID
    # @raise [Error] when team not found
    def resolve_team(client, value)
      return value if value.match?(UUID_RE)
      data = client.query(TEAM_QUERY, variables: {filter: {name: {eqIgnoreCase: value}}})
      data.dig("teams", "nodes", 0, "id") or raise Error, "Team not found: #{value}"
    end

    # @param client [Client]
    # @param value [String] user UUID, "me", email, or name
    # @return [String] user UUID
    # @raise [Error] when user not found
    def resolve_user(client, value)
      return value if value.match?(UUID_RE)

      if value == "me"
        data = client.query(VIEWER_QUERY)
        return data.dig("viewer", "id") || raise(Error, "Could not resolve current user")
      end

      filter = value.include?("@") ? {email: {eq: value}} : {name: {eqIgnoreCase: value}}
      data = client.query(USER_QUERY, variables: {filter:})
      data.dig("users", "nodes", 0, "id") or raise Error, "User not found: #{value}"
    end

    # @param client [Client]
    # @param team_id [String] team UUID (for scoping)
    # @param value [String] state UUID or name
    # @return [String] state UUID
    # @raise [Error] when state not found
    def resolve_state(client, team_id, value)
      return value if value.match?(UUID_RE)
      filter = {name: {eqIgnoreCase: value}, team: {id: {eq: team_id}}}
      data = client.query(STATE_QUERY, variables: {filter:})
      data.dig("workflowStates", "nodes", 0, "id") or raise Error, "State not found: #{value}"
    end

    # @param client [Client]
    # @param value [String] label UUID or name
    # @return [String] label UUID
    # @raise [Error] when label not found
    def resolve_label(client, value)
      return value if value.match?(UUID_RE)
      data = client.query(LABEL_QUERY, variables: {filter: {name: {eqIgnoreCase: value}}})
      data.dig("issueLabels", "nodes", 0, "id") or raise Error, "Label not found: #{value}"
    end

    # @param client [Client]
    # @param values [Array<String>] label UUIDs or names
    # @return [Array<String>] label UUIDs
    def resolve_labels(client, values)
      values.map { |v| resolve_label(client, v) }
    end

    # @param client [Client]
    # @param value [String] project UUID or name
    # @return [String] project UUID
    # @raise [Error] when project not found
    def resolve_project(client, value)
      return value if value.match?(UUID_RE)
      data = client.query(PROJECT_QUERY, variables: {filter: {name: {eqIgnoreCase: value}}})
      data.dig("projects", "nodes", 0, "id") or raise Error, "Project not found: #{value}"
    end

    # @param client [Client]
    # @param team_id [String] team UUID (for scoping)
    # @param value [String] cycle UUID, number, or name
    # @return [String] cycle UUID
    # @raise [Error] when cycle not found
    def resolve_cycle(client, team_id, value)
      return value if value.match?(UUID_RE)

      filter = if value.match?(NUMERIC_RE)
        {number: {eq: value.to_i}, team: {id: {eq: team_id}}}
      else
        {name: {eqIgnoreCase: value}, team: {id: {eq: team_id}}}
      end

      data = client.query(CYCLE_QUERY, variables: {filter:})
      data.dig("cycles", "nodes", 0, "id") or raise Error, "Cycle not found: #{value}"
    end

    # @param client [Client]
    # @param project_id [String] project UUID (for scoping)
    # @param value [String] milestone UUID or name
    # @return [String] milestone UUID
    # @raise [Error] when milestone not found
    def resolve_milestone(client, project_id, value)
      return value if value.match?(UUID_RE)
      filter = {name: {eqIgnoreCase: value}, project: {id: {eq: project_id}}}
      data = client.query(MILESTONE_QUERY, variables: {filter:})
      data.dig("projectMilestones", "nodes", 0, "id") or raise Error, "Milestone not found: #{value}"
    end
  end
end
