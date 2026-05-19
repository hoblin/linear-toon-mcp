# frozen_string_literal: true

module LinearToonMcp
  # Resolvers translate human-friendly identifiers — UUIDs, names, emails,
  # slugs, numbers, the literal "me" — into Linear API UUIDs. They read
  # {LinearToonMcp.client} for API calls.
  #
  # @example
  #   Resolvers::Team.call(value: "Engineering")
  #   Resolvers::WorkflowState.call(value: "In Progress", team_id: tid)
  #   Resolvers::IssueLabel.call_many(values: ["bug", "p1"], team_id: tid)
  module Resolvers
    UUID_RE = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    NUMERIC_RE = /\A\d+\z/
  end
end

require_relative "resolvers/base"
require_relative "resolvers/team"
require_relative "resolvers/user"
require_relative "resolvers/workflow_state"
require_relative "resolvers/issue_label"
require_relative "resolvers/project"
require_relative "resolvers/cycle"
require_relative "resolvers/project_milestone"
