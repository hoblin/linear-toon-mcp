# frozen_string_literal: true

require_relative "lib/linear_toon_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "linear-toon-mcp"
  spec.version = LinearToonMcp::VERSION
  spec.authors = ["Yevhenii Hurin"]
  spec.email = ["evgeny.gurin@gmail.com"]

  spec.summary = "Token-efficient MCP server for Linear using TOON format"
  spec.description = "A Ruby MCP server that wraps Linear's GraphQL API and returns " \
                     "TOON-formatted responses for ~40-60% token savings in LLM workflows."
  spec.homepage = "https://github.com/hoblin/linear-toon-mcp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => "https://github.com/hoblin/linear-toon-mcp",
    "changelog_uri" => "https://github.com/hoblin/linear-toon-mcp/blob/main/CHANGELOG.md"
  }

  spec.files = Dir.glob("{lib,bin}/**/*") + %w[README.md LICENSE]
  spec.bindir = "bin"
  spec.executables = ["linear-toon-mcp"]
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp", "~> 0.6"
  spec.add_dependency "toon-ruby", "~> 0.1"
end
