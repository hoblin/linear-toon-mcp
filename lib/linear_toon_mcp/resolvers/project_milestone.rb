# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project milestone by name. Project-scoped.
    class ProjectMilestone < Base
      scoped_by :project_id
      lookup_by :name
    end
  end
end
