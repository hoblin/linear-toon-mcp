# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetInitiative do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:initiative_id) { "init-uuid" }
  let(:initiative_data) do
    {
      "id" => initiative_id,
      "name" => "Q1 Roadmap",
      "projects" => {"nodes" => [{"id" => "p1", "name" => "Migration"}]}
    }
  end

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
      .with(value: "Q1 Roadmap").and_return(initiative_id)
    allow(client).to receive(:query).and_return("initiative" => initiative_data)
  end

  describe ".call" do
    it "resolves the query through Resolvers::Initiative and queries by id" do
      described_class.call(query: "Q1 Roadmap")
      expect(LinearToonMcp::Resolvers::Initiative).to have_received(:call).with(value: "Q1 Roadmap")
      expect(client).to have_received(:query).with(anything, variables: {id: initiative_id})
    end

    it "always exposes linked projects (id + name)" do
      described_class.call(query: "Q1 Roadmap")
      expect(client).to have_received(:query).with(
        a_string_matching(/projects \{ nodes \{ id name \} \}/),
        anything
      )
    end

    it "adds subInitiatives to the query when includeSubInitiatives is true" do
      described_class.call(query: "Q1 Roadmap", includeSubInitiatives: true)
      expect(client).to have_received(:query).with(
        a_string_matching(/subInitiatives \{ nodes \{ id name status \} \}/),
        anything
      )
    end

    it "omits subInitiatives by default" do
      described_class.call(query: "Q1 Roadmap")
      expect(client).to have_received(:query).with(
        satisfy { |q| !q.include?("subInitiatives") },
        anything
      )
    end
  end
end
