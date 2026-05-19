# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    class ProjectMilestoneResolver < Base
      scoped_by :project_id
      lookup_by :name
    end
  end
end
