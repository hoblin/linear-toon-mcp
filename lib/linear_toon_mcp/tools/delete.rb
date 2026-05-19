# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Base class for delete-mutation tools. Submits the +MUTATION+
    # constant, asserts the +success+ flag, and returns
    # +{success: true, entityId: ...}+ from Linear's +DeletePayload+.
    # The mutation field derives from the class name:
    #
    #   DeleteInitiative.mutation_name  # => "initiativeDelete"
    #
    # Subclasses define the +MUTATION+ constant and override {#variables}
    # to build the +{id:}+ payload. Override the derived names with
    # {.mutation} or {.entity} when they diverge from the class name
    # (e.g., remove-link tools whose mutation targets a join record).
    class Delete < Base
      class << self
        # Overrides the derived GraphQL mutation field name.
        def mutation(name)
          @mutation_name = name.to_s
        end

        # Overrides the derived entity label.
        def entity(name)
          @entity_name = name.to_s
        end

        # Overrides the derived entity label used in error messages.
        def label(name)
          @entity_label = name.to_s
        end

        # Returns the GraphQL mutation field name.
        def mutation_name
          @mutation_name ||= "#{entity_name}Delete"
        end

        # Returns the entity name (used to derive {.entity_label}).
        def entity_name
          @entity_name ||= derive_entity_name
        end

        # Returns the entity label for error messages.
        #
        #   DeleteInitiative.entity_label  # => "Initiative"
        def entity_label
          @entity_label ||= name.split("::").last.sub(/\ADelete/, "")
        end

        # Returns the GraphQL mutation — the +MUTATION+ constant on the subclass.
        def mutation_string
          const_get(:MUTATION)
        end

        private

        def derive_entity_name
          entity = name.split("::").last.sub(/\ADelete/, "")
          entity[0].downcase + entity[1..]
        end
      end

      # Submits {.mutation_string} with {#variables}, validates the
      # +success+ flag, and returns +{success: true, entityId: ...}+.
      #
      # @raise [Error] when the mutation fails
      def perform(**params)
        data = client.query(self.class.mutation_string, variables: variables(**params))
        result = data[self.class.mutation_name] or raise Error, "#{self.class.entity_label} deletion failed: no result returned"
        raise Error, "#{self.class.entity_label} deletion failed" unless result["success"]

        {success: true, entityId: result["entityId"]}
      end

      # Subclass hook. Returns the GraphQL +{id:}+ hash for the mutation.
      def variables(**)
        raise NotImplementedError, "#{self.class.name} must implement #variables"
      end
    end
  end
end
