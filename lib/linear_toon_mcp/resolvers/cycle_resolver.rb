# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear cycle by UUID, number (digit-only string → integer
    # filter), or name. Always team-scoped — pass +team_id:+ to disambiguate
    # same-numbered cycles across teams.
    class CycleResolver < Base
      scoped_by :team_id
      lookup_by :number, :name
    end
  end
end
