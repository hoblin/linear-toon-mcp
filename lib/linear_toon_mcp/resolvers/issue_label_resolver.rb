# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
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
