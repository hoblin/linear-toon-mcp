# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear workflow state (issue status) by UUID, type, or
    # name. Team-scoped.
    class WorkflowStateResolver < Base
      scoped_by :team_id
      lookup_by :type, :name
    end
  end
end
