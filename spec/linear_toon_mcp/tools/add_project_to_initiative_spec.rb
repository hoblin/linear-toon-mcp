# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::AddProjectToInitiative do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "DSL overrides" do
    it "renames the mutation and entity to the join record" do
      expect(described_class.mutation_name).to eq("initiativeToProjectCreate")
      expect(described_class.entity_name).to eq("initiativeToProject")
      expect(described_class.entity_label).to eq("Project-initiative link")
    end
  end

  describe "#variables" do
    it "resolves both names and packages them as initiativeId/projectId input" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
        .with(value: "Q1").and_return("init-1")
      allow(LinearToonMcp::Resolvers::Project).to receive(:call)
        .with(value: "Migration").and_return("proj-1")

      allow(client).to receive(:query).and_return(
        "initiativeToProjectCreate" => {
          "success" => true,
          "initiativeToProject" => {"id" => "itp-1"}
        }
      )

      described_class.call(initiative: "Q1", project: "Migration")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {initiativeId: "init-1", projectId: "proj-1"}}
      )
    end
  end
end
