# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear issue label by UUID or name. Optionally scoped to a
    # team; when scoped, matches either the team's labels or workspace-wide
    # labels (team +null+).
    class IssueLabelResolver < Base
      scoped_by :team_id, optional: true, workspace_fallback: true
      lookup_by :name

      private

      def not_found_message(value)
        scope[:team_id] ? "Label not found on target team or workspace: #{value}" : super
      end
    end
  end
end
