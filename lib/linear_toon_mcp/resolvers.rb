# frozen_string_literal: true

module LinearToonMcp
  # Resolvers translate human-friendly identifiers — UUIDs, names, emails,
  # slugs, numbers, the literal "me" — into Linear API UUIDs.
  #
  # @example
  #   Resolvers::Team.call(client, "Engineering")
  #   Resolvers::WorkflowState.call(client, "In Progress", team_id: tid)
  #   Resolvers::IssueLabel.call_many(client, ["bug", "p1"], team_id: tid)
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
