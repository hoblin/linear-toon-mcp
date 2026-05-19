# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # List initiatives in the Linear workspace with filtering and pagination.
    # Returns TOON-encoded connection with id, name, status, owner, parent
    # initiative, target date, and (optionally) linked projects.
    class ListInitiatives < List
      description "List initiatives with optional filters and pagination"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          cursor: {type: "string", description: "Next page cursor"},
          limit: {type: "integer", description: "Max results (default 50, max 250)"},
          orderBy: {type: "string", description: "createdAt or updatedAt (default updatedAt)", enum: ["createdAt", "updatedAt"]},
          query: {type: "string", description: "Search initiative name (substring, case-insensitive)"},
          status: {type: "string", description: "Status filter: Planned, Active, or Completed"},
          owner: {type: "string", description: 'User ID, name, email, or "me"'},
          parentInitiative: {type: "string", description: "Parent initiative name or ID"},
          createdAt: {type: "string", description: "Created after: ISO-8601 date/duration (e.g., -P1D)"},
          updatedAt: {type: "string", description: "Updated after: ISO-8601 date/duration (e.g., -P1D)"},
          includeArchived: {type: "boolean", description: "Include archived initiatives (default false)"},
          includeProjects: {type: "boolean", description: "Include linked projects (default false)"}
        },
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      BASE_FIELDS = <<~GRAPHQL
        id
        name
        status
        targetDate
        createdAt
        updatedAt
        owner { id name }
        parentInitiative { id name }
      GRAPHQL

      PROJECTS_FIELDS = "initiativeToProjects { nodes { id project { id name } } }"

      UUID_RE = Resolvers::UUID_RE

      # standard:disable Naming/VariableName
      def perform(cursor: nil, limit: nil, orderBy: nil, query: nil, status: nil,
        owner: nil, parentInitiative: nil, createdAt: nil, updatedAt: nil,
        includeArchived: false, includeProjects: false)
        variables = {
          first: (limit || 50).clamp(1, 250),
          orderBy: orderBy || "updatedAt",
          includeArchived: includeArchived == true
        }
        variables[:after] = cursor if cursor

        filter = build_filter(
          query:, status:, owner:, parentInitiative:,
          createdAt:, updatedAt:
        )
        variables[:filter] = filter unless filter.empty?

        graphql = build_query(includeProjects: includeProjects)
        data = client.query(graphql, variables: variables)
        data["initiatives"] or raise Error, "Unexpected response: missing initiatives field"
      end

      private

      def build_query(includeProjects:)
        fields = [BASE_FIELDS.strip]
        fields << PROJECTS_FIELDS if includeProjects

        <<~GRAPHQL
          query($filter: InitiativeFilter, $first: Int, $after: String, $orderBy: PaginationOrderBy, $includeArchived: Boolean) {
            initiatives(filter: $filter, first: $first, after: $after, orderBy: $orderBy, includeArchived: $includeArchived) {
              nodes {
                #{fields.join("\n          ")}
              }
              pageInfo { hasNextPage endCursor }
            }
          }
        GRAPHQL
      end

      def build_filter(query:, status:, owner:, parentInitiative:, createdAt:, updatedAt:)
        filter = {}
        filter[:name] = {containsIgnoreCase: query} if query
        filter[:status] = {eq: status} if status
        filter[:owner] = owner_filter(owner) if owner
        filter[:parentInitiative] = parent_filter(parentInitiative) if parentInitiative
        filter[:createdAt] = {gte: resolve_date(createdAt)} if createdAt
        filter[:updatedAt] = {gte: resolve_date(updatedAt)} if updatedAt
        filter
      end
      # standard:enable Naming/VariableName

      def owner_filter(value)
        return {isMe: {eq: true}} if value == "me"
        owner_id = Resolvers::User.call(value: value)
        {id: {eq: owner_id}}
      end

      def parent_filter(value)
        return {id: {eq: value}} if value.match?(UUID_RE)
        parent_id = Resolvers::Initiative.call(value: value)
        {id: {eq: parent_id}}
      end

      def resolve_date(value)
        return value unless value.start_with?("-P")
        match = value.match(/\A-P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?\z/)
        raise Error, "Invalid duration: #{value}" unless match
        days = match.captures.zip([365, 30, 7, 1]).sum { |c, m| (c&.to_i || 0) * m }
        (Time.now.utc - (days * 86_400)).iso8601
      end
    end
  end
end
