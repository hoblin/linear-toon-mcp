# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear workflow state (issue status) by UUID, type (one of
    # +backlog+/+unstarted+/+started+/+completed+/+canceled+/+triage+,
    # lowercase), or name. Always team-scoped — pass +team_id:+ to
    # disambiguate same-named states across teams. Case decides which lookup
    # runs: lowercase enum tokens hit the +type+ filter, anything else falls
    # through to +name+.
    class WorkflowStateResolver < Base
      scoped_by :team_id
      lookup_by :type, :name
    end
  end
end
