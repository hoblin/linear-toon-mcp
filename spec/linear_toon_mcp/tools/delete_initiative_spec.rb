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

    it "raises when the mutation reports success: false" do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeDelete/), anything)
        .and_return("initiativeDelete" => {"success" => false, "entityId" => nil})

      response = described_class.call(query: "Q1")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Initiative deletion failed")
    end

    it "raises when the response is missing the initiativeDelete key" do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeDelete/), anything)
        .and_return({})

      response = described_class.call(query: "Q1")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Initiative deletion failed: no result returned")
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

    it "raises when the mutation reports success: false" do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeArchive/), anything)
        .and_return("initiativeArchive" => {"success" => false, "entity" => nil})

      response = described_class.call(query: "Q1", archive: true)
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Initiative archive failed")
    end

    it "raises when the response is missing the initiativeArchive key" do
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeArchive/), anything)
        .and_return({})

      response = described_class.call(query: "Q1", archive: true)
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Initiative archive failed: no result returned")
    end
  end
end
