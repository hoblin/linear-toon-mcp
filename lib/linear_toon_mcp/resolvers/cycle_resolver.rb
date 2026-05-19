# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    class CycleResolver < Base
      scoped_by :team_id
      lookup_by :number, :name
    end
  end
end
