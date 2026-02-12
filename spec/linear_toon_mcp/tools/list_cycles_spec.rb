# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListCycles do
  describe ".call" do
    subject(:response) { described_class.call(team:, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:team) { "Engineering" }
    let(:team_id) { "12345678-1234-1234-1234-123456789012" }
    let(:cycles_data) do
      {
        "nodes" => [
          {"id" => "cycle-1", "name" => "Sprint 1", "number" => 1, "startsAt" => "2025-01-01", "endsAt" => "2025-01-14"},
          {"id" => "cycle-2", "name" => "Sprint 2", "number" => 2, "startsAt" => "2025-01-15", "endsAt" => "2025-01-28"}
        ]
      }
    end

    before do
      allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, team).and_return(team_id)
      allow(client).to receive(:query).and_return("cycles" => cycles_data)
    end

    it "resolves the team and queries cycles" do
      response
      expect(LinearToonMcp::Resolvers).to have_received(:resolve_team).with(client, team)
      expect(client).to have_received(:query).with(
        described_class::QUERY,
        variables: {filter: {team: {id: {eq: team_id}}}}
      )
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      text = response.content.first[:text]
      expect(text).to include("Sprint 1")
      expect(text).to include("Sprint 2")
      expect(text).to include("2025-01-01")
    end

    context "with team UUID" do
      let(:team) { "12345678-1234-1234-1234-123456789012" }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, team).and_return(team)
      end

      it "passes UUID through the resolver" do
        response
        expect(LinearToonMcp::Resolvers).to have_received(:resolve_team).with(client, team)
      end
    end

    context "when cycles list is empty" do
      before do
        allow(client).to receive(:query).and_return("cycles" => {"nodes" => []})
      end

      it "returns a TOON-encoded empty response" do
        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:text]).not_to be_empty
      end
    end

    context "when team not found" do
      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team)
          .and_raise(LinearToonMcp::Error, "Team not found: Missing")
      end

      let(:team) { "Missing" }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Team not found")
      end
    end

    context "when cycles field is nil" do
      before do
        allow(client).to receive(:query).and_return("cycles" => nil)
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Unexpected response")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(team: "Engineering", server_context: {}) }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("client missing")
      end
    end

    context "when the API returns an error" do
      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).and_return(team_id)
        allow(client).to receive(:query).and_raise(LinearToonMcp::Error, "HTTP 400: Bad request")
      end

      it "returns an error response with the message" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("HTTP 400")
      end
    end
  end
end
