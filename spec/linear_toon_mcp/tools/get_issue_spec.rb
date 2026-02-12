# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetIssue do
  describe ".call" do
    subject(:response) { described_class.call(id:, server_context: {client:}) }

    let(:id) { "TEST-1" }
    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:issue_data) do
      {
        "id" => "uuid-123",
        "identifier" => "TEST-1",
        "title" => "Fix the bug",
        "description" => "Something is broken",
        "priority" => 2,
        "url" => "https://linear.app/test/issue/TEST-1",
        "createdAt" => "2026-01-01T00:00:00.000Z",
        "updatedAt" => "2026-01-02T00:00:00.000Z",
        "state" => {"name" => "In Progress"},
        "assignee" => {"name" => "Alice"},
        "labels" => {"nodes" => [{"name" => "bug"}]}
      }
    end

    before do
      allow(client).to receive(:query).and_return("issue" => issue_data)
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      expect(response.content.first[:text]).to include("TEST-1")
      expect(response.content.first[:text]).to include("Fix the bug")
    end

    it "queries Linear with the issue ID" do
      response
      expect(client).to have_received(:query).with(
        described_class::QUERY,
        variables: {id: "TEST-1"}
      )
    end
  end

  describe "real API call", :live do
    subject(:response) { described_class.call(id: issue_id, server_context: {client:}) }

    let(:client) { LinearToonMcp::Client.new }
    let(:issue_id) { ENV.fetch("LINEAR_TEST_ISSUE_ID") }

    before do
      skip "LINEAR_API_KEY not set" unless ENV["LINEAR_API_KEY"]
      skip "LINEAR_TEST_ISSUE_ID not set" unless ENV["LINEAR_TEST_ISSUE_ID"]
    end

    it "fetches an issue from Linear" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:text]).not_to be_empty
    end
  end
end
