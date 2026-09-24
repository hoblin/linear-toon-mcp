# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Base do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  describe "conventions derived from class name" do
    it "camelCase-pluralizes the connection name" do
      expect(LinearToonMcp::Resolvers::WorkflowState.connection_name).to eq("workflowStates")
      expect(LinearToonMcp::Resolvers::IssueLabel.connection_name).to eq("issueLabels")
      expect(LinearToonMcp::Resolvers::Team.connection_name).to eq("teams")
    end

    it "derives the filter type name from the entity name" do
      expect(LinearToonMcp::Resolvers::WorkflowState.filter_type_name).to eq("WorkflowStateFilter")
      expect(LinearToonMcp::Resolvers::ProjectMilestone.filter_type_name).to eq("ProjectMilestoneFilter")
      expect(LinearToonMcp::Resolvers::Team.filter_type_name).to eq("TeamFilter")
    end

    it "uses the trailing CamelCase word for the not-found label" do
      expect(LinearToonMcp::Resolvers::WorkflowState.entity_label).to eq("State")
      expect(LinearToonMcp::Resolvers::IssueLabel.entity_label).to eq("Label")
      expect(LinearToonMcp::Resolvers::ProjectMilestone.entity_label).to eq("Milestone")
      expect(LinearToonMcp::Resolvers::Team.entity_label).to eq("Team")
    end
  end

  describe "blank values" do
    before { LinearToonMcp.client = client }

    it "rejects a blank value before querying" do
      allow(client).to receive(:query)
      expect { LinearToonMcp::Resolvers::Project.call(value: "") }
        .to raise_error(LinearToonMcp::Error, /\AProject must not be blank\z/)
      expect(client).not_to have_received(:query)
    end

    it "guards resolvers that override resolve" do
      allow(client).to receive(:query)
      expect { LinearToonMcp::Resolvers::ProjectStatus.call(value: " ") }
        .to raise_error(LinearToonMcp::Error, /\AStatus must not be blank\z/)
      expect(client).not_to have_received(:query)
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
      LinearToonMcp.client = client
      allow(client).to receive(:query).and_return("things" => {"nodes" => []})
      expect { resolver.call(value: "Missing") }
        .to raise_error(LinearToonMcp::Error, /\AThing not found: Missing\z/)
    end
  end
end
