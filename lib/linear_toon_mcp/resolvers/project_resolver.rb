# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project by UUID, name, or slug.
    class ProjectResolver < Base
      lookup_by :name, :slug
    end
  end
end
