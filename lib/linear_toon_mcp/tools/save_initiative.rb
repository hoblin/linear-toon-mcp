# frozen_string_literal: true

module LinearToonMcp
  module Tools
    # Create or update a Linear initiative. When +id+ is present, updates
    # the existing initiative; otherwise creates a new one. Resolves
    # +owner+ via {Resolvers::User} and parent initiative names via
    # {Resolvers::Initiative}.
    class SaveInitiative < Base
      description "Create or update a Linear initiative (id presence determines)"

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false
      )

      # standard:disable Layout/LineLength
      input_schema(
        properties: {
          id: {type: "string", description: "Initiative ID. If provided, updates the existing initiative; otherwise creates"},
          name: {type: "string", description: "Initiative name (required when creating)"},
          description: {type: "string", description: "Short summary (max ~255 chars)"},
          content: {type: "string", description: "Long-form content as Markdown"},
          status: {type: "string", description: "Status: Planned, Active, or Completed", enum: ["Planned", "Active", "Completed"]},
          color: {type: "string", description: "Hex color (e.g., #5E6AD2)"},
          targetDate: {type: "string", description: "Target date (ISO format, YYYY-MM-DD)"},
          owner: {type: ["string", "null"], description: 'User ID, name, email, or "me". Null to remove'},
          parentInitiative: {type: ["string", "null"], description: "Parent initiative name or ID. Null to remove"}
        },
        additionalProperties: false
      )
      # standard:enable Layout/LineLength

      RETURN_FIELDS = <<~GRAPHQL
        id
        name
        description
        status
        color
        targetDate
        url
        owner { id name }
        parentInitiative { id name }
      GRAPHQL

      CREATE_MUTATION = <<~GRAPHQL
        mutation($input: InitiativeCreateInput!) {
          initiativeCreate(input: $input) {
            success
            initiative { #{RETURN_FIELDS.strip} }
          }
        }
      GRAPHQL

      UPDATE_MUTATION = <<~GRAPHQL
        mutation($id: String!, $input: InitiativeUpdateInput!) {
          initiativeUpdate(id: $id, input: $input) {
            success
            initiative { #{RETURN_FIELDS.strip} }
          }
        }
      GRAPHQL

      # standard:disable Naming/VariableName
      def perform(id: nil, **kwargs)
        id ? update(id, kwargs) : create(kwargs)
      end

      private

      def create(kwargs)
        raise Error, "name is required when creating an initiative" unless kwargs[:name]
        input = build_input(kwargs)
        data = client.query(CREATE_MUTATION, variables: {input:})
        result = data["initiativeCreate"] or raise Error, "Initiative creation failed: no result returned"
        raise Error, "Initiative creation failed" unless result["success"]
        result["initiative"]
      end

      def update(id, kwargs)
        input = build_input(kwargs)
        data = client.query(UPDATE_MUTATION, variables: {id:, input:})
        result = data["initiativeUpdate"] or raise Error, "Initiative update failed: no result returned"
        raise Error, "Initiative update failed" unless result["success"]
        result["initiative"]
      end

      def build_input(kwargs)
        input = {}
        {name: :name, description: :description, content: :content,
         color: :color, status: :status, targetDate: :targetDate}.each do |key, field|
          input[field] = kwargs[key] if kwargs.key?(key)
        end
        add_owner(input, kwargs)
        add_parent(input, kwargs)
        input
      end

      def add_owner(input, kwargs)
        return unless kwargs.key?(:owner)
        input[:ownerId] = kwargs[:owner] ? Resolvers::User.call(value: kwargs[:owner]) : nil
      end

      def add_parent(input, kwargs)
        return unless kwargs.key?(:parentInitiative)
        input[:parentInitiativeId] =
          kwargs[:parentInitiative] ? Resolvers::Initiative.call(value: kwargs[:parentInitiative]) : nil
      end
      # standard:enable Naming/VariableName
    end
  end
end
