# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear initiative by name.
    class Initiative < Base
      lookup_by :name
    end
  end
end
