# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    class ProjectResolver < Base
      lookup_by :name, :slug
    end
  end
end
