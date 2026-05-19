# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List comments on an issue, project, initiative, or project status
    # update. Exactly one parent identifies the conversation.
    class ListComments < List
      description "List comments on an issue, project, initiative, or project status update"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          issue: {type: "string", description: "Issue UUID or identifier (provide exactly one parent)"},
          project: {type: "string", description: "Project name or UUID (provide exactly one parent)"},
          initiative: {type: "string", description: "Initiative name or UUID (provide exactly one parent)"},
          projectUpdate: {type: "string", description: "Project status update UUID (provide exactly one parent)"},
          cursor: {type: "string", description: "Next page cursor"},
          limit: {type: "integer", description: "Max results (default 50, max 250)"},
          orderBy: {type: "string", description: "createdAt or updatedAt (default createdAt)", enum: ["createdAt", "updatedAt"]}
        },
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      QUERY = <<~GRAPHQL
        query($filter: CommentFilter, $first: Int, $after: String, $orderBy: PaginationOrderBy) {
          comments(filter: $filter, first: $first, after: $after, orderBy: $orderBy) {
            nodes {
              id
              body
              createdAt
              editedAt
              user { id name }
              parent { id }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      def variables(issue: nil, project: nil, initiative: nil, projectUpdate: nil,
        cursor: nil, limit: nil, orderBy: nil)
        vars = {
          first: (limit || 50).clamp(1, 250),
          orderBy: orderBy || "createdAt",
          filter: parent_filter(issue:, project:, initiative:, projectUpdate:)
        }
        vars[:after] = cursor if cursor
        vars
      end

      private

      def parent_filter(issue:, project:, initiative:, projectUpdate:)
        given = {issue:, project:, initiative:, projectUpdate:}.compact
        unless given.length == 1
          raise Error,
            "Provide exactly one of `issue`, `project`, `initiative`, or `projectUpdate`"
        end

        case given.keys.first
        when :issue then {issue: {id: {eq: issue}}}
        when :project then {project: {id: {eq: Resolvers::Project.call(value: project)}}}
        when :initiative then {initiative: {id: {eq: Resolvers::Initiative.call(value: initiative)}}}
        when :projectUpdate then {projectUpdate: {id: {eq: projectUpdate}}}
        end
      end
      # standard:enable Naming/VariableName
    end
  end
end
