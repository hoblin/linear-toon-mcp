# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Resolves a Linear user by email, name, or the literal +"me"+.
    class User < Base
      VIEWER_QUERY = "query { viewer { id } }"

      lookup_by :email, :name

      def resolve(value)
        return resolve_viewer if value == "me"
        super
      end

      private

      def resolve_viewer
        data = client.query(VIEWER_QUERY)
        data.dig("viewer", "id") || raise(Error, "Could not resolve current user")
      end
    end
  end
end
