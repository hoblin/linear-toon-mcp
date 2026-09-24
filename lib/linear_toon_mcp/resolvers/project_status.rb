# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear project status by name (workspace-scoped).
    class ProjectStatus < Base
      connection :projectStatuses

      class << self
        # Linear's projectStatuses field accepts no filter argument.
        def query
          @query ||= "query { #{connection_name} { nodes { id name } } }"
        end
      end

      # Resolves +value+ to a UUID. UUIDs pass through unchanged; otherwise the
      # workspace status list is matched by name, ignoring case.
      #
      # @raise [Error] when no status matches +value+
      def resolve(value)
        return value if value.match?(UUID_RE)

        status = statuses.find { |node| node["name"].casecmp?(value) }
        status&.fetch("id") || raise(Error, not_found_message(value))
      end

      private

      def statuses
        client.query(self.class.query).dig(self.class.connection_name, "nodes") || []
      end
    end
  end
end
