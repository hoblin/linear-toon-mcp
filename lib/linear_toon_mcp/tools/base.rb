# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # Base class for MCP tools. Subclasses implement {#perform} and
    # inherit the standard envelope: TOON-encoded responses and a single
    # +rescue LinearToonMcp::Error+ at the boundary. The Linear client is
    # read from {LinearToonMcp.client}.
    #
    #   class ListTeams < Tools::List
    #     description "..."
    #     input_schema(...)
    #     QUERY = "..."
    #   end
    #
    # Verb subclasses ({Tools::List}, {Tools::Get}, {Tools::Create},
    # {Tools::Update}, {Tools::Delete}) layer the CRUD-specific shape on
    # top — connection extraction, mutation success checks, and so on.
    class Base < MCP::Tool
      class << self
        # Entry point invoked by the MCP server. Instantiates the tool
        # and dispatches to its {#perform}. {LinearToonMcp::Error}s
        # raised anywhere along the path become error responses.
        #
        # @return [MCP::Tool::Response]
        def call(server_context: nil, **params)
          new.call(**params)
        rescue Error => e
          error_response(e.message)
        end

        # Wraps +data+ in a successful MCP response with TOON-encoded text.
        def success_response(data)
          MCP::Tool::Response.new([{type: "text", text: Toon.encode(data)}])
        end

        # Wraps +message+ in an error MCP response.
        def error_response(message)
          MCP::Tool::Response.new([{type: "text", text: message}], error: true)
        end
      end

      # Runs the tool with validated parameters and returns the MCP
      # response. Subclasses normally override {#perform}, not this method.
      # When {#perform} returns an {MCP::Tool::Response}, it is passed
      # through unchanged — letting subclasses craft the response directly
      # (e.g., to append post-mutation warnings).
      def call(**params)
        result = perform(**params)
        result.is_a?(MCP::Tool::Response) ? result : self.class.success_response(result)
      rescue Error => e
        self.class.error_response(e.message)
      end

      # Subclass hook. Returns the Ruby value to TOON-encode, or a
      # pre-built {MCP::Tool::Response}.
      def perform(**)
        raise NotImplementedError, "#{self.class.name} must implement #perform"
      end

      private

      # The active Linear API client.
      def client
        LinearToonMcp.client
      end

      # Returns an {MCP::Tool::Response} with TOON-encoded +data+ followed
      # by a +WARNING (<context>): ...+ line when +warnings+ is non-empty.
      # Used by mutating tools whose post-mutation steps may fail
      # partially (issue created, but link attach failed).
      def respond_with_warnings(data, warnings, context:)
        text = Toon.encode(data)
        text += "\nWARNING (#{context}): #{warnings.join("; ")}" if warnings.any?
        MCP::Tool::Response.new([{type: "text", text:}])
      end
    end
  end
end
