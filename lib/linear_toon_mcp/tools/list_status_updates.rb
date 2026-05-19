# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List status updates posted to a Linear project or initiative.
    # Exactly one of +project:+ or +initiative:+ must be provided.
    class ListStatusUpdates < Base
      description "List status updates on a project or initiative"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          project: {type: "string", description: "Project name or ID (provide exactly one parent)"},
          initiative: {type: "string", description: "Initiative name or ID (provide exactly one parent)"},
          cursor: {type: "string", description: "Next page cursor"},
          limit: {type: "integer", description: "Max results (default 50, max 250)"},
          orderBy: {type: "string", description: "createdAt or updatedAt (default updatedAt)", enum: ["createdAt", "updatedAt"]},
          includeArchived: {type: "boolean", description: "Include archived updates (default false)"}
        },
        additionalProperties: false
      )

      READ_FIELDS = <<~GRAPHQL
        id
        body
        health
        isStale
        isDiffHidden
        createdAt
        updatedAt
        editedAt
        archivedAt
        url
        user { id name }
      GRAPHQL

      PROJECT_QUERY = <<~GRAPHQL
        query($filter: ProjectUpdateFilter, $first: Int, $after: String, $orderBy: PaginationOrderBy, $includeArchived: Boolean) {
          projectUpdates(filter: $filter, first: $first, after: $after, orderBy: $orderBy, includeArchived: $includeArchived) {
            nodes {
              #{READ_FIELDS.strip}
              project { id name }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
      GRAPHQL

      INITIATIVE_QUERY = <<~GRAPHQL
        query($filter: InitiativeUpdateFilter, $first: Int, $after: String, $orderBy: PaginationOrderBy, $includeArchived: Boolean) {
          initiativeUpdates(filter: $filter, first: $first, after: $after, orderBy: $orderBy, includeArchived: $includeArchived) {
            nodes {
              #{READ_FIELDS.strip}
              initiative { id name }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      def perform(project: nil, initiative: nil, cursor: nil, limit: nil,
        orderBy: nil, includeArchived: false)
        parent = exactly_one_parent(project: project, initiative: initiative)
        variables = pagination_variables(cursor: cursor, limit: limit, orderBy: orderBy, includeArchived: includeArchived)

        case parent
        in [:project, value]
          project_id = Resolvers::Project.call(value: value)
          variables[:filter] = {project: {id: {eq: project_id}}}
          data = client.query(PROJECT_QUERY, variables: variables)
          data["projectUpdates"] or raise Error, "Unexpected response: missing projectUpdates field"
        in [:initiative, value]
          initiative_id = Resolvers::Initiative.call(value: value)
          variables[:filter] = {initiative: {id: {eq: initiative_id}}}
          data = client.query(INITIATIVE_QUERY, variables: variables)
          data["initiativeUpdates"] or raise Error, "Unexpected response: missing initiativeUpdates field"
        end
      end

      private

      def exactly_one_parent(project:, initiative:)
        raise Error, "Provide exactly one of `project` or `initiative`" if (project && initiative) || (!project && !initiative)
        project ? [:project, project] : [:initiative, initiative]
      end

      def pagination_variables(cursor:, limit:, orderBy:, includeArchived:)
        variables = {
          first: (limit || 50).clamp(1, 250),
          orderBy: orderBy || "updatedAt",
          includeArchived: includeArchived == true
        }
        variables[:after] = cursor if cursor
        variables
      end
      # standard:enable Naming/VariableName
    end
  end
end
