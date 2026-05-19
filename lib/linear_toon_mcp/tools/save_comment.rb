# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a comment on an issue, project, initiative, or
    # project status update. +id+ presence determines create vs update.
    # On create, exactly one parent identifies what the comment is
    # attached to. On update, the comment id alone suffices — Linear
    # doesn't allow reparenting comments.
    class SaveComment < Base
      description "Create or update a comment on an issue, project, initiative, or project status update"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          id: {type: "string", description: "Comment ID. If provided, updates the existing comment"},
          issue: {type: "string", description: "Issue UUID or identifier (create only; provide exactly one parent)"},
          project: {type: "string", description: "Project name or UUID (create only; provide exactly one parent)"},
          initiative: {type: "string", description: "Initiative name or UUID (create only; provide exactly one parent)"},
          projectUpdate: {type: "string", description: "Project status update UUID (create only; provide exactly one parent)"},
          body: {type: "string", description: "Comment body as Markdown"},
          parentId: {type: "string", description: "Parent comment ID for threaded replies (create only)"}
        },
        required: ["body"],
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      RETURN_FIELDS = <<~GRAPHQL
        id
        body
        createdAt
        editedAt
        user { id name }
        issue { id identifier }
        project { id name }
        initiative { id name }
        projectUpdate { id }
      GRAPHQL

      CREATE_MUTATION = <<~GRAPHQL
        mutation($input: CommentCreateInput!) {
          commentCreate(input: $input) {
            success
            comment { #{RETURN_FIELDS.strip} }
          }
        }
      GRAPHQL

      UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: CommentUpdateInput!) {
          commentUpdate(id: $id, input: $input) {
            success
            comment { #{RETURN_FIELDS.strip} }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      def perform(body:, id: nil, issue: nil, project: nil, initiative: nil,
        projectUpdate: nil, parentId: nil)
        id ? update(id, body) : create(body:, issue:, project:, initiative:, projectUpdate:, parentId:)
      end

      private

      def update(id, body)
        data = client.query(UPDATE_MUTATION, variables: {id: id, input: {body: body}})
        extract(data, "commentUpdate")
      end

      def create(body:, issue:, project:, initiative:, projectUpdate:, parentId:)
        parent_field = exactly_one_parent_field(issue:, project:, initiative:, projectUpdate:)
        input = {body: body}.merge(parent_field)
        input[:parentId] = parentId if parentId
        data = client.query(CREATE_MUTATION, variables: {input: input})
        extract(data, "commentCreate")
      end

      def exactly_one_parent_field(issue:, project:, initiative:, projectUpdate:)
        given = {issue:, project:, initiative:, projectUpdate:}.compact
        unless given.length == 1
          raise Error,
            "Provide exactly one of `issue`, `project`, `initiative`, or `projectUpdate`"
        end

        case given.keys.first
        when :issue then {issueId: issue}
        when :project then {projectId: Resolvers::Project.call(value: project)}
        when :initiative then {initiativeId: Resolvers::Initiative.call(value: initiative)}
        when :projectUpdate then {projectUpdateId: projectUpdate}
        end
      end

      def extract(data, mutation_key)
        result = data[mutation_key] or raise Error, "Comment save failed: no result returned"
        raise Error, "Comment save failed" unless result["success"]
        result["comment"]
      end
      # standard:enable Naming/VariableName
    end
  end
end
