# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    class TeamResolver < Base
      lookup_by :name
    end
  end
end
