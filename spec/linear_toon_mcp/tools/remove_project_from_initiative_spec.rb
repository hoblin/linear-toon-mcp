# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::RemoveProjectFromInitiative do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:initiative_id) { "init-1" }
  let(:project_id) { "proj-1" }
  let(:join_id) { "itp-1" }

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
      .with(value: "Q1").and_return(initiative_id)
    allow(LinearToonMcp::Resolvers::Project).to receive(:call)
      .with(value: "Migration").and_return(project_id)
  end

  describe "DSL overrides" do
    it "targets the join-record delete mutation" do
      expect(described_class.mutation_name).to eq("initiativeToProjectDelete")
      expect(described_class.entity_name).to eq("initiativeToProject")
      expect(described_class.entity_label).to eq("Project-initiative link")
    end
  end

  describe "#variables" do
    it "resolves both names, looks up the join id under the project, and submits delete" do
      allow(client).to receive(:query)
        .with(a_string_matching(/project\(id: \$projectId\)/), variables: {projectId: project_id})
        .and_return(
          "project" => {"initiativeToProjects" => {"nodes" => [
            {"id" => "other-1", "initiative" => {"id" => "other-init"}},
            {"id" => join_id, "initiative" => {"id" => initiative_id}}
          ]}}
        )
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeToProjectDelete/), anything)
        .and_return("initiativeToProjectDelete" => {"success" => true, "entityId" => join_id})

      described_class.call(initiative: "Q1", project: "Migration")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeToProjectDelete/),
        variables: {id: join_id}
      )
    end

    it "raises a clear error when the project is not linked to the initiative" do
      allow(client).to receive(:query)
        .with(a_string_matching(/project\(id: \$projectId\)/), anything)
        .and_return("project" => {"initiativeToProjects" => {"nodes" => []}})

      response = described_class.call(initiative: "Q1", project: "Migration")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("not linked to initiative")
    end
  end
end
