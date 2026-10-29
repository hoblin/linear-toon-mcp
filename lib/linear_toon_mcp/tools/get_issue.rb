# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Fetch a single Linear issue by ID or identifier and return it as TOON.
    # Includes metadata, state, assignee, labels, project, team, attachments,
    # parent issue, direct child issues, and relations in both directions.
    class GetIssue < Get
      description "Retrieve a Linear issue by ID, including its parent, direct child issues and relations: what it blocks, relates to or duplicates (relations) and what blocks, relates to or duplicates it (inverseRelations)"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          id: {type: "string", description: "Issue ID or identifier (e.g., LIN-123)"}
        },
        required: ["id"],
        additionalProperties: false
      )

      QUERY = <<~GRAPHQL
        query($id: String!) {
          issue(id: $id) {
            id
            identifier
            title
            description
            priority
            priorityLabel
            url
            branchName
            createdAt
            updatedAt
            archivedAt
            completedAt
            dueDate
            state { name }
            assignee { id name }
            creator { id name }
            labels { nodes { name } }
            project { id name }
            team { id name }
            attachments { nodes { id title url } }
            parent { identifier title url state { name } }
            children(first: 50) { nodes { identifier title url state { name } } }
            relations(first: 50) { nodes { type relatedIssue { identifier title url state { name } } } }
            inverseRelations(first: 50) { nodes { type issue { identifier title url state { name } } } }
          }
        }
      GRAPHQL
    end
  end
end
