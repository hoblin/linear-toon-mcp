# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear workflow state (issue status) by type or name.
    # Team-scoped.
    class WorkflowState < Base
      scoped_by :team_id
      lookup_by :type, :name
    end
  end
end
