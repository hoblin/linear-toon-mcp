# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Base class for entity resolvers. Subclasses declare their lookup
    # attributes and any required parent scope. UUIDs always pass through
    # unchanged regardless of the declared attributes.
    #
    # Defaults derive from the class name:
    #
    #   WorkflowState.connection_name   # => "workflowStates"
    #   WorkflowState.filter_type_name  # => "WorkflowStateFilter"
    #   WorkflowState.entity_label      # => "State"
    #
    # Override any default via {.connection}, {.filter_type}, or {.label}.
    class Base
      # Lookup attribute catalog: value predicate paired with GraphQL filter builder.
      ATTRIBUTES = {
        name: {
          matches: ->(_v) { true },
          filter: ->(v) { {name: {eqIgnoreCase: v}} }
        },
        email: {
          matches: ->(v) { v.include?("@") },
          filter: ->(v) { {email: {eq: v}} }
        },
        number: {
          matches: ->(v) { v.match?(NUMERIC_RE) },
          filter: ->(v) { {number: {eq: v.to_i}} }
        },
        slug: {
          matches: ->(_v) { true },
          filter: ->(v) { {slugId: {eqIgnoreCase: v}} }
        },
        key: {
          matches: ->(v) { v.match?(/\A[A-Z]+\z/) },
          filter: ->(v) { {key: {eq: v}} }
        },
        type: {
          matches: ->(v) { v.match?(/\A[a-z]+\z/) },
          filter: ->(v) { {type: {eq: v}} }
        }
      }.freeze

      class << self
        # Declares lookup attributes for this resolver, in priority order.
        #
        #   class Team < Base
        #     lookup_by :key, :name
        #   end
        #
        # @param attrs [Array<Symbol>] attribute names from {ATTRIBUTES}
        def lookup_by(*attrs)
          @attributes = attrs.freeze
        end

        # Declares a parent-scoping kwarg expected by {.call}. The kwarg name
        # implies the GraphQL filter key — +:team_id+ produces
        # +{team: {id: {eq: value}}}+.
        #
        #   class Cycle < Base
        #     scoped_by :team_id
        #     lookup_by :name
        #   end
        #
        # @param key [Symbol] kwarg name passed to {.call}
        # @param optional [Boolean] omit the scope filter when scope arg is nil
        # @param workspace_fallback [Boolean] when set, the scope filter becomes
        #   an +or:+ matching either the scoped parent or workspace-level
        #   records (parent +null+)
        def scoped_by(key, optional: false, workspace_fallback: false)
          @scope_config = {key: key, optional: optional, workspace_fallback: workspace_fallback}.freeze
        end

        # Overrides the derived GraphQL connection name.
        def connection(name)
          @connection = name.to_s
        end

        # Overrides the derived GraphQL filter type name.
        def filter_type(name)
          @filter_type = name.to_s
        end

        # Overrides the derived not-found label.
        def label(name)
          @label = name.to_s
        end

        # Returns the attributes declared via {.lookup_by}.
        def attributes
          @attributes || []
        end

        attr_reader :scope_config

        # Returns the GraphQL connection name.
        #
        #   WorkflowState.connection_name  # => "workflowStates"
        def connection_name
          @connection ||= "#{entity_name[0].downcase}#{entity_name[1..]}s"
        end

        # Returns the GraphQL filter input type name.
        #
        #   WorkflowState.filter_type_name  # => "WorkflowStateFilter"
        def filter_type_name
          @filter_type ||= "#{entity_name}Filter"
        end

        # Returns the not-found label — the trailing CamelCase word of
        # {.entity_name}.
        #
        #   WorkflowState.entity_label  # => "State"
        def entity_label
          @label ||= entity_name.scan(/[A-Z][a-z]+/).last || entity_name
        end

        # Returns the entity name.
        #
        #   WorkflowState.entity_name  # => "WorkflowState"
        def entity_name
          @entity_name ||= name.split("::").last
        end

        # Returns the memoized GraphQL query.
        def query
          @query ||= <<~GRAPHQL
            query($filter: #{filter_type_name}) {
              #{connection_name}(filter: $filter, first: 1) { nodes { id } }
            }
          GRAPHQL
        end

        # Resolves +value+ to a UUID.
        #
        #   Team.call(client, value: "Engineering")
        #   WorkflowState.call(client, value: "Done", team_id: tid)
        #
        # @param client [Client]
        # @param value [String]
        # @param scope [Hash] parent-scope kwargs (e.g. +team_id:+)
        # @return [String] resolved UUID
        # @raise [Error] when no attribute resolves the value
        def call(client, value:, **scope)
          new(client, **scope).resolve(value)
        end

        # Resolves each value via {.call}, forwarding scope.
        #
        #   IssueLabel.call_many(client, values: ["bug", "p1"], team_id: tid)
        #
        # @return [Array<String>]
        def call_many(client, values:, **scope)
          values.map { |v| call(client, value: v, **scope) }
        end
      end

      def initialize(client, **scope)
        @client = client
        @scope = scope
      end

      # Resolves +value+ to a UUID. UUIDs pass through unchanged; otherwise
      # each {.lookup_by} attribute is tried in declared order and the first
      # GraphQL lookup that returns a node wins.
      #
      # @raise [Error] when nothing resolves +value+
      def resolve(value)
        return value if value.match?(UUID_RE)

        self.class.attributes.each do |attr|
          definition = ATTRIBUTES.fetch(attr) { raise Error, "Unknown attribute: #{attr.inspect}" }
          next unless definition[:matches].call(value)

          id = lookup(definition[:filter].call(value).merge(scope_filter))
          return id if id
        end

        raise Error, not_found_message(value)
      end

      private

      attr_reader :client, :scope

      def scope_filter
        cfg = self.class.scope_config
        return {} unless cfg

        scope_id = scope[cfg[:key]]
        if scope_id.nil?
          return {} if cfg[:optional]
          raise Error, "Missing required scope: #{cfg[:key]}"
        end

        parent_field = cfg[:key].to_s.sub(/_id\z/, "").to_sym
        if cfg[:workspace_fallback]
          {or: [{parent_field => {null: true}}, {parent_field => {id: {eq: scope_id}}}]}
        else
          {parent_field => {id: {eq: scope_id}}}
        end
      end

      def lookup(filter)
        data = client.query(self.class.query, variables: {filter:})
        data.dig(self.class.connection_name, "nodes", 0, "id")
      end

      def not_found_message(value)
        "#{self.class.entity_label} not found: #{value}"
      end
    end
  end
end
