# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project status by name (workspace-scoped).
    class ProjectStatus < Base
      connection :projectStatuses
      filter_type :ProjectStatusFilter
      lookup_by :name
    end
  end
end
