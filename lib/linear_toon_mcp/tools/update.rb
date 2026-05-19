# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Base class for update-mutation tools. Submits the +MUTATION+
    # constant, asserts the +success+ flag, and returns the updated
    # entity. The mutation field and entity key derive from the class
    # name:
    #
    #   UpdateIssue.mutation_name  # => "issueUpdate"
    #   UpdateIssue.entity_name    # => "issue"
    #
    # Subclasses define the +MUTATION+ constant and override {#variables}
    # to construct the GraphQL +id+ + +input+ payload.
    class Update < Base
      class << self
        # Returns the GraphQL mutation field name.
        def mutation_name
          @mutation_name ||= "#{entity_name}Update"
        end

        # Returns the entity field name inside the mutation payload.
        def entity_name
          @entity_name ||= derive_entity_name
        end

        # Returns the entity label for error messages.
        #
        #   UpdateIssue.entity_label  # => "Issue"
        def entity_label
          @entity_label ||= name.split("::").last.sub(/\AUpdate/, "")
        end

        # Returns the GraphQL mutation — the +MUTATION+ constant on the
        # subclass.
        def mutation_string
          const_get(:MUTATION)
        end

        private

        def derive_entity_name
          entity = name.split("::").last.sub(/\AUpdate/, "")
          entity[0].downcase + entity[1..]
        end
      end

      # Submits {.mutation_string} with {#variables}, validates the
      # +success+ flag, and returns the updated entity.
      #
      # @raise [Error] when the mutation fails
      def perform(**params)
        data = client.query(self.class.mutation_string, variables: variables(**params))
        result = data[self.class.mutation_name] or raise Error, "#{self.class.entity_label} update failed: no result returned"
        raise Error, "#{self.class.entity_label} update failed" unless result["success"]

        result[self.class.entity_name]
      end

      # Subclass hook. Returns the GraphQL +{id:, input:}+ hash for
      # the mutation. Subclasses must implement.
      def variables(**)
        raise NotImplementedError, "#{self.class.name} must implement #variables"
      end
    end
  end
end
