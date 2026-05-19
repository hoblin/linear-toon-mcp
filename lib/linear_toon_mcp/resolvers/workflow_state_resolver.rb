# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    class WorkflowStateResolver < Base
      scoped_by :team_id
      lookup_by :name
    end
  end
end
