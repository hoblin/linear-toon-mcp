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
        "priorityLabel" => "High",
        "url" => "https://linear.app/test/issue/TEST-1",
        "branchName" => "alice/test-1-fix-the-bug",
        "createdAt" => "2026-01-01T00:00:00.000Z",
        "updatedAt" => "2026-01-02T00:00:00.000Z",
        "archivedAt" => nil,
        "completedAt" => nil,
        "dueDate" => nil,
        "state" => {"name" => "In Progress"},
        "assignee" => {"id" => "user-1", "name" => "Alice"},
        "creator" => {"id" => "user-2", "name" => "Bob"},
        "labels" => {"nodes" => [{"name" => "bug"}]},
        "project" => {"id" => "proj-1", "name" => "My Project"},
        "team" => {"id" => "team-1", "name" => "Engineering"},
        "attachments" => {"nodes" => []}
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

    context "when the issue does not exist" do
      before do
        allow(client).to receive(:query).and_return("issue" => nil)
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Issue not found: TEST-1")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(id:, server_context: {}) }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("client missing")
      end
    end

    context "when the API returns an error" do
      before do
        allow(client).to receive(:query).and_raise(LinearToonMcp::Error, "HTTP 400: Cannot query field")
      end

      it "returns an error response with the error message" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("HTTP 400")
      end
    end
  end
end
