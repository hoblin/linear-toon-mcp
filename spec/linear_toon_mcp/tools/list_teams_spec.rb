# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListTeams do
  describe ".call" do
    subject(:response) { described_class.call(server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:teams_data) do
      {
        "nodes" => [
          {"id" => "team-1", "name" => "Engineering", "key" => "ENG"},
          {"id" => "team-2", "name" => "Design", "key" => "DES"}
        ]
      }
    end

    before do
      allow(client).to receive(:query).and_return("teams" => teams_data)
    end

    it "queries all teams" do
      response
      expect(client).to have_received(:query).with(described_class::QUERY)
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      text = response.content.first[:text]
      expect(text).to include("Engineering")
      expect(text).to include("ENG")
      expect(text).to include("Design")
    end

    context "when teams list is empty" do
      before do
        allow(client).to receive(:query).and_return("teams" => {"nodes" => []})
      end

      it "returns a TOON-encoded empty response" do
        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:text]).not_to be_empty
      end
    end

    context "when teams field is nil" do
      before do
        allow(client).to receive(:query).and_return("teams" => nil)
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Unexpected response")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(server_context: {}) }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("client missing")
      end
    end

    context "when the API returns an error" do
      before do
        allow(client).to receive(:query).and_raise(LinearToonMcp::Error, "HTTP 400: Bad request")
      end

      it "returns an error response with the message" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("HTTP 400")
      end
    end
  end
end
