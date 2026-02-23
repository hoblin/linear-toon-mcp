# frozen_string_literal: true

require "toon"

module LinearToonMcp
  module Tools
    # Fetch a single Linear project by ID, name, or slug and return it as TOON.
    # Supports optional includes for members, milestones, and resources.
    class GetProject < MCP::Tool
      description "Retrieve details of a specific project in Linear"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          query: {type: "string", description: "Project name, ID, or slug"},
          includeMembers: {type: "boolean", description: "Include project members (default: false)"},
          includeMilestones: {type: "boolean", description: "Include milestones (default: false)"},
          includeResources: {type: "boolean", description: "Include resources (documents, links, attachments) (default: false)"}
        },
        required: ["query"],
        additionalProperties: false
      )

      BASE_FIELDS = <<~GRAPHQL
        id
        name
        slugId
        url
        description
        state
        priority
        priorityLabel
        startDate
        targetDate
        createdAt
        updatedAt
        archivedAt
        progress
        scope
        completedScopeHistory
        lead { id name }
        teams { nodes { id name } }
      GRAPHQL

      MEMBERS_FIELDS = "members { nodes { id name email } }"
      MILESTONES_FIELDS = "projectMilestones { nodes { id name targetDate } }"
      RESOURCES_FIELDS = <<~GRAPHQL.strip
        documents { nodes { id title } }
        links { nodes { id url label } }
      GRAPHQL

      # standard:disable Naming/VariableName
      class << self
        # @param query [String] Project ID, name, or slug
        # @param includeMembers [Boolean] Include project members
        # @param includeMilestones [Boolean] Include project milestones
        # @param includeResources [Boolean] Include documents, links, attachments
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] TOON-encoded project or error
        def call(query:, includeMembers: false, includeMilestones: false, includeResources: false, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"
          project_id = Resolvers.resolve_project(client, query)
          graphql = build_query(includeMembers:, includeMilestones:, includeResources:)
          data = client.query(graphql, variables: {id: project_id})
          project = data["project"] or raise Error, "Project not found: #{query}"
          text = Toon.encode(project)
          MCP::Tool::Response.new([{type: "text", text:}])
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end

        private

        def build_query(includeMembers:, includeMilestones:, includeResources:)
          fields = [BASE_FIELDS.strip]
          fields << MEMBERS_FIELDS if includeMembers
          fields << MILESTONES_FIELDS if includeMilestones
          fields << RESOURCES_FIELDS if includeResources

          <<~GRAPHQL
            query($id: String!) {
              project(id: $id) {
                #{fields.join("\n        ")}
              }
            }
          GRAPHQL
        end
      end
      # standard:enable Naming/VariableName
    end
  end
end
