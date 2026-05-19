# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Base class for single-entity read tools. Queries by id and
    # extracts the named entity field; raises a labeled not-found error
    # when the field is +nil+. The entity field name derives from the
    # class name:
    #
    #   GetIssue.entity_name    # => "issue"
    #   GetProject.entity_name  # => "project"
    #
    # Subclasses define the +QUERY+ constant and override {#variables}
    # when the lookup key needs resolving first (e.g., name/slug → UUID).
    class Get < Base
      class << self
        # Overrides the derived GraphQL entity field name.
        def entity(name)
          @entity = name.to_s
        end

        # Returns the GraphQL entity field name.
        def entity_name
          @entity ||= derive_entity_name
        end

        # Returns the entity label for not-found messages.
        #
        #   GetIssue.entity_label  # => "Issue"
        def entity_label
          @entity_label ||= name.split("::").last.sub(/\AGet/, "")
        end

        # Returns the GraphQL query — the +QUERY+ constant on the subclass.
        def query_string
          const_get(:QUERY)
        end

        private

        def derive_entity_name
          entity = name.split("::").last.sub(/\AGet/, "")
          entity[0].downcase + entity[1..]
        end
      end

      # Queries {.query_string} with {#variables} and extracts the
      # entity field.
      #
      # @raise [Error] when the entity is not found
      def perform(**params)
        data = client.query(self.class.query_string, variables: variables(**params))
        data[self.class.entity_name] or raise Error, not_found_message(**params)
      end

      # Subclass hook. Returns the GraphQL variables hash for {#perform}.
      # Defaults to +{id: id}+; override when the lookup key needs
      # resolving first (e.g., name/slug → UUID).
      def variables(id:, **)
        {id: id}
      end

      # Subclass hook. Returns the not-found error message.
      def not_found_message(id: nil, **)
        "#{self.class.entity_label} not found: #{id}"
      end
    end
  end
end
