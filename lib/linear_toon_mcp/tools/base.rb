# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # Base class for all MCP tools. Subclasses implement {#perform};
    # responses are TOON-encoded and {LinearToonMcp::Error} is caught at
    # the boundary. The Linear client is read from {LinearToonMcp.client}.
    #
    #   class ListTeams < Tools::List
    #     description "..."
    #     input_schema(...)
    #     QUERY = "..."
    #   end
    class Base < MCP::Tool
      class << self
        # Entry point invoked by the MCP server. Instantiates the tool
        # and dispatches to its {#perform}. Any {LinearToonMcp::Error}
        # raised along the way becomes an error response.
        #
        # @return [MCP::Tool::Response]
        def call(server_context: nil, **params)
          new.call(**params)
        rescue Error => e
          error_response(e.message)
        end

        # Returns a successful MCP response with TOON-encoded +data+.
        # @return [MCP::Tool::Response]
        def success_response(data)
          MCP::Tool::Response.new([{type: "text", text: Toon.encode(data)}])
        end

        # Returns an error MCP response carrying +message+.
        # @return [MCP::Tool::Response]
        def error_response(message)
          MCP::Tool::Response.new([{type: "text", text: message}], error: true)
        end
      end

      # Runs the tool with validated parameters and returns the MCP
      # response. Subclasses override {#perform}, not this method.
      # When {#perform} returns an {MCP::Tool::Response}, it is passed
      # through unchanged.
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

      def client
        LinearToonMcp.client
      end

      # Returns an {MCP::Tool::Response} with TOON-encoded +data+ followed
      # by a +WARNING (<context>): ...+ line when +warnings+ is non-empty.
      #
      # @return [MCP::Tool::Response]
      def respond_with_warnings(data, warnings, context:)
        text = Toon.encode(data)
        text += "\nWARNING (#{context}): #{warnings.join("; ")}" if warnings.any?
        MCP::Tool::Response.new([{type: "text", text:}])
      end
    end
  end
end
