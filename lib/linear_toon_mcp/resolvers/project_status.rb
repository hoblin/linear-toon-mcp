# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project status by name (workspace-scoped).
    class ProjectStatus < Base
      QUERY = "query { projectStatuses { nodes { id name } } }"

      def resolve(value)
        return value if value.match?(UUID_RE)

        status = statuses.find { |node| node["name"].casecmp?(value) }
        status&.fetch("id") || raise(Error, not_found_message(value))
      end

      private

      def statuses
        client.query(QUERY).dig("projectStatuses", "nodes") || []
      end
    end
  end
end
