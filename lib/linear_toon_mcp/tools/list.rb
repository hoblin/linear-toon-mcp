# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Base class for list tools. Queries a top-level GraphQL connection
    # and returns its +nodes+ + +pageInfo+. The connection name derives
    # from the class name:
    #
    #   ListTeams.connection_name        # => "teams"
    #   ListIssueLabels.connection_name  # => "issueLabels"
    #
    # Override with {.connection} when the GraphQL field diverges
    # (e.g., +ListIssueStatuses+ → +workflowStates+).
    #
    # Subclasses define the +QUERY+ constant and override {#variables}
    # to compute GraphQL variables from inputs.
    class List < Base
      class << self
        # Overrides the derived GraphQL connection name.
        def connection(name)
          @connection = name.to_s
        end

        # Returns the GraphQL connection field name.
        def connection_name
          @connection ||= derive_connection_name
        end

        # Returns the GraphQL query — the +QUERY+ constant on the subclass.
        def query_string
          const_get(:QUERY)
        end

        private

        def derive_connection_name
          entity = name.split("::").last.sub(/\AList/, "")
          entity[0].downcase + entity[1..]
        end
      end

      # Queries {.query_string} with {#variables} and extracts the
      # connection field.
      #
      # @raise [Error] when the connection field is missing
      def perform(**params)
        data = client.query(self.class.query_string, variables: variables(**params))
        data[self.class.connection_name] or raise Error, "Unexpected response: missing #{self.class.connection_name} field"
      end

      # Subclass hook. Returns the GraphQL variables hash for {#perform}.
      # Defaults to no variables.
      def variables(**)
        {}
      end
    end
  end
end
