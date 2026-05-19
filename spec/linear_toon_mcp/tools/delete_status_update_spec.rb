# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::DeleteStatusUpdate do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "parent dispatch" do
    it "calls projectUpdateArchive when the status update belongs to a project" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => {"id" => "pu-1", "project" => {"id" => "p-1", "name" => "P"}})
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdateArchive/), anything)
        .and_return("projectUpdateArchive" => {"success" => true, "entity" => {"id" => "pu-1", "archivedAt" => "2026-05-19T00:00:00Z"}})

      described_class.call(id: "pu-1")
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdateArchive/),
        variables: {id: "pu-1"}
      )
    end

    it "calls initiativeUpdateArchive when the status update belongs to an initiative" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => {"id" => "iu-1", "initiative" => {"id" => "i-1", "name" => "I"}})
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdateArchive/), anything)
        .and_return("initiativeUpdateArchive" => {"success" => true, "entity" => {"id" => "iu-1", "archivedAt" => "2026-05-19T00:00:00Z"}})

      described_class.call(id: "iu-1")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdateArchive/),
        variables: {id: "iu-1"}
      )
    end
  end

  describe "archive result handling" do
    before do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => {"id" => "pu-1", "project" => {"id" => "p-1", "name" => "P"}})
    end

    it "raises when archive reports success: false" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdateArchive/), anything)
        .and_return("projectUpdateArchive" => {"success" => false, "entity" => nil})
      response = described_class.call(id: "pu-1")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update archive failed")
    end

    it "raises when the archive result key is missing" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdateArchive/), anything)
        .and_return({})
      response = described_class.call(id: "pu-1")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("no result returned")
    end
  end

  describe "lookup failure" do
    it "raises a not-found error when the id matches neither project nor initiative" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => nil)

      response = described_class.call(id: "missing")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update not found")
    end
  end
end
