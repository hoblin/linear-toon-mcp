# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Base do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  describe "conventions derived from class name" do
    it "splits CamelCase, strips Resolver, and pluralizes for the connection name" do
      expect(LinearToonMcp::Resolvers::WorkflowStateResolver.connection_name).to eq("workflowStates")
      expect(LinearToonMcp::Resolvers::IssueLabelResolver.connection_name).to eq("issueLabels")
      expect(LinearToonMcp::Resolvers::TeamResolver.connection_name).to eq("teams")
    end

    it "derives the filter type name from the entity name" do
      expect(LinearToonMcp::Resolvers::WorkflowStateResolver.filter_type_name).to eq("WorkflowStateFilter")
      expect(LinearToonMcp::Resolvers::ProjectMilestoneResolver.filter_type_name).to eq("ProjectMilestoneFilter")
      expect(LinearToonMcp::Resolvers::TeamResolver.filter_type_name).to eq("TeamFilter")
    end

    it "uses the trailing CamelCase word for the not-found label" do
      expect(LinearToonMcp::Resolvers::WorkflowStateResolver.entity_label).to eq("State")
      expect(LinearToonMcp::Resolvers::IssueLabelResolver.entity_label).to eq("Label")
      expect(LinearToonMcp::Resolvers::ProjectMilestoneResolver.entity_label).to eq("Milestone")
      expect(LinearToonMcp::Resolvers::TeamResolver.entity_label).to eq("Team")
    end
  end

  describe "DSL overrides" do
    it "honors an explicit label override in not-found messages" do
      resolver = Class.new(described_class) do
        connection "things"
        filter_type "ThingFilter"
        label "Thing"
        lookup_by :name
      end
      allow(client).to receive(:query).and_return("things" => {"nodes" => []})
      expect { resolver.call(client, "Missing") }
        .to raise_error(LinearToonMcp::Error, /\AThing not found: Missing\z/)
    end

    it "honors a custom Proc shortcut handler" do
      resolver = Class.new(described_class) do
        connection "things"
        filter_type "ThingFilter"
        label "Thing"
        shortcut "self", via: ->(_c) { "shortcut-uuid" }
        lookup_by :name
      end
      expect(resolver.call(client, "self")).to eq("shortcut-uuid")
    end
  end
end
