# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::DeleteInitiative do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:initiative_id) { "init-1" }

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
      .with(value: "Q1").and_return(initiative_id)
  end

  describe "hard delete (default)" do
    before do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiative\(id: \$id\) \{\s+projects/), anything)
        .and_return("initiative" => {"projects" => {"nodes" => []}})
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeDelete/), anything)
        .and_return("initiativeDelete" => {"success" => true, "entityId" => initiative_id})
    end

    it "submits initiativeDelete after the link guard passes" do
      described_class.call(query: "Q1")
      expect(client).to have_received(:query).with(a_string_matching(/initiativeDelete/), variables: {id: initiative_id})
    end

    it "refuses to delete when projects are still linked" do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiative\(id: \$id\) \{\s+projects/), anything)
        .and_return("initiative" => {"projects" => {"nodes" => [{"id" => "p1"}]}})

      response = described_class.call(query: "Q1")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("still has linked projects")
      expect(response.content.first[:text]).to include("archive: true")
    end
  end

  describe "archive: true" do
    let(:archived_payload) do
      {"id" => initiative_id, "name" => "Q1", "archivedAt" => "2026-05-19T17:00:00.000Z"}
    end

    before do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeArchive/), anything)
        .and_return("initiativeArchive" => {"success" => true, "entity" => archived_payload})
    end

    it "submits initiativeArchive instead of initiativeDelete" do
      described_class.call(query: "Q1", archive: true)
      expect(client).to have_received(:query).with(a_string_matching(/initiativeArchive/), variables: {id: initiative_id})
    end

    it "bypasses the linked-projects guard" do
      described_class.call(query: "Q1", archive: true)
      expect(client).not_to have_received(:query).with(a_string_matching(/initiative\(id: \$id\) \{\s+projects/), anything)
    end

    it "returns the archived entity" do
      response = described_class.call(query: "Q1", archive: true)
      text = response.content.first[:text]
      expect(text).to include("archivedAt")
    end
  end
end
