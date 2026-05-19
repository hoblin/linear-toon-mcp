# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear team by UUID, key, or name.
    class TeamResolver < Base
      lookup_by :key, :name
    end
  end
end
