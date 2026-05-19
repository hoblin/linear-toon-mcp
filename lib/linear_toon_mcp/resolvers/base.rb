# frozen_string_literal: true

module LinearToonMcp
  module Resolvers
    # Convention-over-configuration base for entity resolvers.
    #
    # Derived from the class name (with the trailing +Resolver+ stripped — e.g.
    # +WorkflowStateResolver+ → +"WorkflowState"+):
    #
    # - {.connection_name} — the GraphQL connection field (+"workflowStates"+)
    # - {.filter_type_name} — the GraphQL filter input type (+"WorkflowStateFilter"+)
    # - {.entity_label} — the not-found label, using the trailing CamelCase
    #   word (+"State"+)
    #
    # Override any of those via {.connection}, {.filter_type}, {.label}.
    #
    # Resolution order:
    #
    # 1. UUIDs pass through unchanged.
    # 2. A configured {.shortcut} can intercept a literal token (e.g. +"me"+).
    # 3. Each {.lookup_by} attribute is tried in declared order; its predicate
    #    decides whether to attempt it for the current value, and its filter
    #    is merged with any {.scoped_by} scope filter.
    # 4. The first lookup that returns a node wins.
    # 5. Otherwise raise {LinearToonMcp::Error} with {#not_found_message}.
    class Base
      # Catalog of well-known lookup attributes. Each entry pairs a predicate
      # (does this value look like the attribute?) with a filter builder.
      # Linear workflow state enum values — used by the +:type+ attribute
      # predicate to recognize state-type lookups (e.g. +"started"+) without
      # colliding with same-named human labels (e.g. +"Started"+).
      WORKFLOW_STATE_TYPE_RE = /\A(backlog|unstarted|started|completed|canceled|triage)\z/

      # Linear team key shape — uppercase letter followed by uppercase letters,
      # digits, underscores, or hyphens (e.g. +"ENG"+, +"LIN-1"+). Distinguishes
      # key lookups from team-name lookups by case.
      TEAM_KEY_RE = /\A[A-Z][A-Z0-9_-]*\z/

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
          matches: ->(v) { v.match?(TEAM_KEY_RE) },
          filter: ->(v) { {key: {eq: v}} }
        },
        type: {
          matches: ->(v) { v.match?(WORKFLOW_STATE_TYPE_RE) },
          filter: ->(v) { {type: {eq: v}} }
        }
      }.freeze

      # Built-in non-filter shortcut handlers. Subclasses opt in via {.shortcut}.
      SHORTCUTS = {
        viewer: lambda { |client|
          data = client.query("query { viewer { id } }")
          data.dig("viewer", "id") || raise(Error, "Could not resolve current user")
        }
      }.freeze

      class << self
        # DSL --------------------------------------------------------------

        # Declare ordered lookup attributes. Symbols draw from {ATTRIBUTES}.
        # @param attrs [Array<Symbol>]
        def lookup_by(*attrs)
          @attributes = attrs.freeze
        end

        # Declare a parent-scoping kwarg expected by {.call}.
        # The kwarg name (e.g. +:team_id+) implies the GraphQL filter key
        # (+:team+ → +{team: {id: {eq: value}}}+).
        # @param key [Symbol] kwarg name passed to {.call}
        # @param optional [Boolean] omit the scope filter when scope arg is nil
        # @param workspace_fallback [Boolean] when set, the scope filter becomes
        #   an +or:+ matching either the scoped parent or workspace-level
        #   records (parent +null+). Used by {IssueLabelResolver} so a name
        #   lookup resolves either a team-scoped or workspace-wide label.
        def scoped_by(key, optional: false, workspace_fallback: false)
          @scope_config = {key: key, optional: optional, workspace_fallback: workspace_fallback}.freeze
        end

        # Declare a literal token that short-circuits to a non-filter lookup.
        # @param token [String] literal value to match (e.g. +"me"+)
        # @param via [Symbol, Proc] built-in handler (+:viewer+) or a custom
        #   callable receiving the client and returning a UUID
        def shortcut(token, via:)
          @shortcut_config = {token: token, via: via}.freeze
        end

        # Override the derived GraphQL connection name.
        def connection(name)
          @connection = name.to_s
        end

        # Override the derived GraphQL filter type name.
        def filter_type(name)
          @filter_type = name.to_s
        end

        # Override the derived not-found label.
        def label(name)
          @label = name.to_s
        end

        # Accessors --------------------------------------------------------

        # @return [Array<Symbol>] attributes declared via {.lookup_by}
        def attributes
          @attributes || []
        end

        attr_reader :scope_config, :shortcut_config

        # Derived names ----------------------------------------------------

        # @return [String] e.g. +"workflowStates"+ for +WorkflowStateResolver+
        def connection_name
          @connection ||= "#{entity_name[0].downcase}#{entity_name[1..]}s"
        end

        # @return [String] e.g. +"WorkflowStateFilter"+
        def filter_type_name
          @filter_type ||= "#{entity_name}Filter"
        end

        # @return [String] trailing CamelCase word — e.g. +"State"+ for +"WorkflowState"+
        def entity_label
          @label ||= entity_name.scan(/[A-Z][a-z]+/).last || entity_name
        end

        # @return [String] class name with +Resolver+ stripped
        def entity_name
          @entity_name ||= name.split("::").last.sub(/Resolver\z/, "")
        end

        # @return [String] memoized GraphQL query
        def query
          @query ||= <<~GRAPHQL
            query($filter: #{filter_type_name}) {
              #{connection_name}(filter: $filter, first: 1) { nodes { id } }
            }
          GRAPHQL
        end

        # Entry points -----------------------------------------------------

        # @param client [Client]
        # @param value [String]
        # @param scope [Hash] parent-scoping kwargs
        # @return [String] resolved UUID
        # @raise [Error] when no attribute resolves the value
        def call(client, value, **scope)
          new(client, **scope).resolve(value)
        end

        # Batch convenience — resolves each value via {.call}. Scope kwargs
        # are forwarded to every per-value lookup.
        # @param client [Client]
        # @param values [Array<String>]
        # @param scope [Hash] parent-scoping kwargs forwarded to each {.call}
        # @return [Array<String>]
        def call_many(client, values, **scope)
          values.map { |v| call(client, v, **scope) }
        end
      end

      def initialize(client, **scope)
        @client = client
        @scope = scope
      end

      def resolve(value)
        return value if value.match?(UUID_RE)
        return apply_shortcut if shortcut_match?(value)

        self.class.attributes.each do |attr|
          definition = ATTRIBUTES.fetch(attr) { raise ArgumentError, "Unknown attribute: #{attr.inspect}" }
          next unless definition[:matches].call(value)

          id = lookup(definition[:filter].call(value).merge(scope_filter))
          return id if id
        end

        raise Error, not_found_message(value)
      end

      private

      attr_reader :client, :scope

      def shortcut_match?(value)
        cfg = self.class.shortcut_config
        cfg && value == cfg[:token]
      end

      def apply_shortcut
        cfg = self.class.shortcut_config
        handler = cfg[:via].is_a?(Symbol) ? SHORTCUTS.fetch(cfg[:via]) : cfg[:via]
        handler.call(client)
      end

      def scope_filter
        cfg = self.class.scope_config
        return {} unless cfg

        value = scope[cfg[:key]]
        if value.nil?
          return {} if cfg[:optional]
          raise ArgumentError, "Missing required scope: #{cfg[:key]}"
        end

        parent = cfg[:key].to_s.sub(/_id\z/, "").to_sym
        if cfg[:workspace_fallback]
          {or: [{parent => {null: true}}, {parent => {id: {eq: value}}}]}
        else
          {parent => {id: {eq: value}}}
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
