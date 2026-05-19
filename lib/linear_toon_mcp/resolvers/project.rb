# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project by name or slug.
    class Project < Base
      lookup_by :name, :slug
    end
  end
end
