# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project milestone by UUID or name. Project-scoped.
    class ProjectMilestoneResolver < Base
      scoped_by :project_id
      lookup_by :name
    end
  end
end
