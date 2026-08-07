# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveProjectMilestone do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:milestone_data) { {"id" => "ms-1", "name" => "Discovery"} }

  before { LinearToonMcp.client = client }

  describe "dispatch" do
    it "submits projectMilestoneCreate when id is absent" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "Permissions").and_return("p1")
      allow(client).to receive(:query)
        .and_return("projectMilestoneCreate" => {"success" => true, "projectMilestone" => milestone_data})
      described_class.call(project: "Permissions", name: "Discovery")
      expect(client).to have_received(:query).with(a_string_matching(/projectMilestoneCreate/), anything)
    end

    it "submits projectMilestoneUpdate when id is present" do
      allow(client).to receive(:query)
        .and_return("projectMilestoneUpdate" => {"success" => true, "projectMilestone" => milestone_data})
      described_class.call(id: "ms-1", name: "Discovery & definition")
      expect(client).to have_received(:query).with(a_string_matching(/projectMilestoneUpdate/), anything)
    end
  end

  describe "create" do
    before do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "Permissions").and_return("p1")
      allow(client).to receive(:query)
        .and_return("projectMilestoneCreate" => {"success" => true, "projectMilestone" => milestone_data})
    end

    it "resolves the project name and passes it as projectId" do
      described_class.call(project: "Permissions", name: "Discovery")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {name: "Discovery", projectId: "p1"}}
      )
    end

    it "rejects create without name" do
      response = described_class.call(project: "Permissions")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("name is required")
    end

    it "rejects create without project" do
      response = described_class.call(name: "Discovery")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("project is required")
    end

    it "surfaces an unresolvable project" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call)
        .with(value: "Nope").and_raise(LinearToonMcp::Error, "Project not found: Nope")
      response = described_class.call(project: "Nope", name: "Discovery")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Project not found: Nope")
    end

    it "raises when the mutation reports success: false" do
      allow(client).to receive(:query)
        .and_return("projectMilestoneCreate" => {"success" => false, "projectMilestone" => nil})
      response = described_class.call(project: "Permissions", name: "Discovery")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Milestone save failed")
    end

    it "raises when the response is missing the projectMilestoneCreate key" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(project: "Permissions", name: "Discovery")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Milestone save failed: no result returned")
    end
  end

  describe "update" do
    before do
      allow(client).to receive(:query)
        .and_return("projectMilestoneUpdate" => {"success" => true, "projectMilestone" => milestone_data})
    end

    it "passes id and partial input to the mutation" do
      described_class.call(id: "ms-1", description: "Scope the permission model")
      expect(client).to have_received(:query).with(
        anything,
        variables: {id: "ms-1", input: {description: "Scope the permission model"}}
      )
    end

    it "rejects project on update" do
      response = described_class.call(id: "ms-1", project: "Permissions")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Cannot pass `project` on update")
    end

    it "raises when the mutation reports success: false" do
      allow(client).to receive(:query)
        .and_return("projectMilestoneUpdate" => {"success" => false, "projectMilestone" => nil})
      response = described_class.call(id: "ms-1", name: "Discovery")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Milestone save failed")
    end

    it "raises when the response is missing the projectMilestoneUpdate key" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(id: "ms-1", name: "Discovery")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Milestone save failed: no result returned")
    end
  end

  describe "input building" do
    before do
      allow(client).to receive(:query)
        .and_return("projectMilestoneUpdate" => {"success" => true, "projectMilestone" => milestone_data})
    end

    it "passes plain fields straight through" do
      described_class.call(
        id: "ms-1", name: "Discovery", description: "## Scope",
        targetDate: "2026-06-15", sortOrder: 2
      )
      expect(client).to have_received(:query).with(
        anything,
        variables: {id: "ms-1", input: {
          name: "Discovery", description: "## Scope",
          targetDate: "2026-06-15", sortOrder: 2
        }}
      )
    end

    it "omits fields that were not passed" do
      described_class.call(id: "ms-1", sortOrder: 0)
      expect(client).to have_received(:query).with(anything, variables: {id: "ms-1", input: {sortOrder: 0}})
    end
  end

  describe "response" do
    it "returns the TOON-encoded milestone" do
      allow(client).to receive(:query)
        .and_return("projectMilestoneUpdate" => {"success" => true, "projectMilestone" => milestone_data})
      response = described_class.call(id: "ms-1", name: "Discovery")
      expect(response).not_to be_error
      expect(response.content.first[:text]).to include("ms-1").and include("Discovery")
    end
  end
end
