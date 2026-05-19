# frozen_string_literal: true

module LinearToonMcp
  # Resolvers translate human-friendly identifiers — UUIDs, names, emails,
  # slugs, numbers, the literal "me" — into Linear API UUIDs.
  #
  # Each entity is a subclass of {Base}. Connection name, filter type, and
  # not-found label derive from the class name by convention; subclasses
  # declare which lookup attributes apply via {Base.lookup_by} (drawn from the
  # {Base::ATTRIBUTES} catalog), any required parent scope via
  # {Base.scoped_by}, and optional non-filter shortcuts via {Base.shortcut}.
  #
  # @example
  #   Resolvers::TeamResolver.call(client, "Engineering")
  #   Resolvers::WorkflowStateResolver.call(client, "In Progress", team_id: tid)
  #   Resolvers::IssueLabelResolver.call_many(client, ["bug", "p1"], team_id: tid)
  module Resolvers
    UUID_RE = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    NUMERIC_RE = /\A\d+\z/
  end
end

require_relative "resolvers/base"
require_relative "resolvers/team_resolver"
require_relative "resolvers/user_resolver"
require_relative "resolvers/workflow_state_resolver"
require_relative "resolvers/issue_label_resolver"
require_relative "resolvers/project_resolver"
require_relative "resolvers/cycle_resolver"
require_relative "resolvers/project_milestone_resolver"
