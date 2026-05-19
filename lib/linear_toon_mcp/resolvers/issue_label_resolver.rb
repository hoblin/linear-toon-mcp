# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear issue label by UUID or name. The +team_id:+ scope is
    # optional: when present the lookup matches either a team-scoped label or
    # a workspace-wide label (where the label's +team+ relation is +null+),
    # so a name like "Bug" cannot accidentally resolve to a same-named label
    # on a different team.
    class IssueLabelResolver < Base
      scoped_by :team_id, optional: true, workspace_fallback: true
      lookup_by :name

      private

      # Adds the scope to the message when a team was specified — the lookup
      # would have matched either the team or workspace labels, so the
      # generic "Label not found" undersells where we looked.
      def not_found_message(value)
        scope[:team_id] ? "Label not found on target team or workspace: #{value}" : super
      end
    end
  end
end
