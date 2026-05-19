# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetStatusUpdate do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:project_update) { {"id" => "pu-1", "body" => "p update", "project" => {"id" => "p-1", "name" => "P"}} }
  let(:initiative_update) { {"id" => "iu-1", "body" => "i update", "initiative" => {"id" => "i-1", "name" => "I"}} }

  before { LinearToonMcp.client = client }

  describe "try-both lookup" do
    it "returns a project update when projectUpdate query succeeds" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => project_update)

      response = described_class.call(id: "pu-1")
      text = response.content.first[:text]
      expect(text).to include("p update")
      expect(text).to include("project:")
    end

    it "falls back to initiativeUpdate when projectUpdate returns nil" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => initiative_update)

      response = described_class.call(id: "iu-1")
      text = response.content.first[:text]
      expect(text).to include("i update")
      expect(text).to include("initiative:")
    end

    it "falls back to initiativeUpdate when projectUpdate raises Entity not found" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_raise(LinearToonMcp::Error, "GraphQL error: Entity not found: ProjectUpdate")
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => initiative_update)

      response = described_class.call(id: "iu-1")
      expect(response).not_to be_error
    end

    it "re-raises non-not-found errors from initiativeUpdate" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_raise(LinearToonMcp::Error, "HTTP 502: Bad gateway")

      response = described_class.call(id: "anything")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("HTTP 502")
    end

    it "re-raises non-not-found errors from projectUpdate" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_raise(LinearToonMcp::Error, "HTTP 500: Internal server error")

      response = described_class.call(id: "anything")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("HTTP 500")
    end

    it "raises a clear error when neither lookup succeeds" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => nil)

      response = described_class.call(id: "missing")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update not found: missing")
    end
  end
end
