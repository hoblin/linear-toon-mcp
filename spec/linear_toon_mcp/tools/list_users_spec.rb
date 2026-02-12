# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListUsers do
  describe ".call" do
    subject(:response) { described_class.call(**params, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:params) { {} }
    let(:users_data) do
      {
        "nodes" => [
          {"id" => "user-1", "name" => "Alice", "email" => "alice@example.com"},
          {"id" => "user-2", "name" => "Bob", "email" => "bob@example.com"}
        ]
      }
    end

    before do
      allow(client).to receive(:query).and_return("users" => users_data)
    end

    it "queries all users" do
      response
      expect(client).to have_received(:query).with(described_class::QUERY)
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      text = response.content.first[:text]
      expect(text).to include("Alice")
      expect(text).to include("alice@example.com")
      expect(text).to include("Bob")
    end

    context "with team filter" do
      let(:params) { {team: "Engineering"} }
      let(:team_id) { "12345678-1234-1234-1234-123456789012" }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, "Engineering").and_return(team_id)
        allow(client).to receive(:query).with(described_class::TEAM_MEMBERS_QUERY, variables: {id: team_id})
          .and_return("team" => {"members" => users_data})
      end

      it "resolves the team and queries team members" do
        response
        expect(LinearToonMcp::Resolvers).to have_received(:resolve_team).with(client, "Engineering")
        expect(client).to have_received(:query).with(
          described_class::TEAM_MEMBERS_QUERY,
          variables: {id: team_id}
        )
      end

      it "returns a TOON-encoded response" do
        text = response.content.first[:text]
        expect(text).to include("Alice")
        expect(text).to include("Bob")
      end
    end

    context "with team UUID" do
      let(:params) { {team: "12345678-1234-1234-1234-123456789012"} }
      let(:team_id) { "12345678-1234-1234-1234-123456789012" }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, team_id).and_return(team_id)
        allow(client).to receive(:query).with(described_class::TEAM_MEMBERS_QUERY, variables: {id: team_id})
          .and_return("team" => {"members" => users_data})
      end

      it "passes UUID through the resolver" do
        response
        expect(LinearToonMcp::Resolvers).to have_received(:resolve_team).with(client, team_id)
      end
    end

    context "when users list is empty" do
      before do
        allow(client).to receive(:query).and_return("users" => {"nodes" => []})
      end

      it "returns a TOON-encoded empty response" do
        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:text]).not_to be_empty
      end
    end

    context "when team not found" do
      let(:params) { {team: "Missing"} }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team)
          .and_raise(LinearToonMcp::Error, "Team not found: Missing")
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Team not found")
      end
    end

    context "when users field is nil" do
      before do
        allow(client).to receive(:query).and_return("users" => nil)
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Unexpected response")
      end
    end

    context "when team members field is nil" do
      let(:params) { {team: "Engineering"} }
      let(:team_id) { "12345678-1234-1234-1234-123456789012" }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).and_return(team_id)
        allow(client).to receive(:query).and_return("team" => {"members" => nil})
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
