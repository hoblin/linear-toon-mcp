# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear team by UUID, key (e.g. +"ENG"+ — uppercase short
    # identifier), or name (case-insensitive). Case decides which lookup
    # runs: uppercase tokens hit the +key+ filter, mixed-case fall through
    # to +name+.
    class TeamResolver < Base
      lookup_by :key, :name
    end
  end
end
