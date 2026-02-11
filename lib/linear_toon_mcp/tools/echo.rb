# frozen_string_literal: true

module LinearToonMcp
  module Tools
    class Echo < MCP::Tool
      description "Accepts text input and returns it as-is"

      input_schema(
        properties: {
          text: { type: "string", description: "Text to echo back" }
        },
        required: ["text"],
        additionalProperties: false
      )

      class << self
        def call(text:, server_context: nil)
          MCP::Tool::Response.new([{ type: "text", text: }])
        end
      end
    end
  end
end
