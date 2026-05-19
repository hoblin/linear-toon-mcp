# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project milestone by UUID or name. Always
    # project-scoped — pass +project_id:+ since milestones only exist within
    # a project and names are not unique across projects.
    class ProjectMilestoneResolver < Base
      scoped_by :project_id
      lookup_by :name
    end
  end
end
