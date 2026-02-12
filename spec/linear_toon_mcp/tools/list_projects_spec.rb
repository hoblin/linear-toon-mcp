# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListProjects do
  describe ".call" do
    subject(:response) { described_class.call(**params, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:params) { {} }
    let(:projects_data) do
      {
        "nodes" => [
          {"id" => "proj-1", "name" => "Project Alpha", "state" => "started"},
          {"id" => "proj-2", "name" => "Project Beta", "state" => "planned"}
        ]
      }
    end

    before do
      allow(client).to receive(:query).and_return("projects" => projects_data)
    end

    it "queries all projects without filter" do
      response
      expect(client).to have_received(:query).with(described_class::QUERY, variables: {})
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      text = response.content.first[:text]
      expect(text).to include("Project Alpha")
      expect(text).to include("started")
      expect(text).to include("Project Beta")
    end

    context "with team filter" do
      let(:params) { {team: "Engineering"} }
      let(:team_id) { "12345678-1234-1234-1234-123456789012" }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, "Engineering").and_return(team_id)
        allow(client).to receive(:query).and_return("projects" => projects_data)
      end

      it "resolves the team and queries with team filter" do
        response
        expect(LinearToonMcp::Resolvers).to have_received(:resolve_team).with(client, "Engineering")
        expect(client).to have_received(:query).with(
          described_class::QUERY,
          variables: {filter: {accessibleTeams: {id: {eq: team_id}}}}
        )
      end

      it "returns a TOON-encoded response" do
        text = response.content.first[:text]
        expect(text).to include("Project Alpha")
        expect(text).to include("Project Beta")
      end
    end

    context "with team UUID" do
      let(:params) { {team: "12345678-1234-1234-1234-123456789012"} }
      let(:team_id) { "12345678-1234-1234-1234-123456789012" }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, team_id).and_return(team_id)
        allow(client).to receive(:query).and_return("projects" => projects_data)
      end

      it "passes UUID through the resolver" do
        response
        expect(LinearToonMcp::Resolvers).to have_received(:resolve_team).with(client, team_id)
      end
    end

    context "when projects list is empty" do
      before do
        allow(client).to receive(:query).and_return("projects" => {"nodes" => []})
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

    context "when projects field is nil" do
      before do
        allow(client).to receive(:query).and_return("projects" => nil)
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
