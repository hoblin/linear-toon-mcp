# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project by UUID, name (case-insensitive), or slug.
    # Name is tried first; the slug filter runs as a fallback when the name
    # lookup returns no project.
    class ProjectResolver < Base
      lookup_by :name, :slug
    end
  end
end
