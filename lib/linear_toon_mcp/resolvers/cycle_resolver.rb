# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear cycle by number or name. Team-scoped.
    class CycleResolver < Base
      scoped_by :team_id
      lookup_by :number, :name
    end
  end
end
