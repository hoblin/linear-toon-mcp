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
        "attachments" => {"nodes" => []},
        "parent" => {
          "identifier" => "TEST-0",
          "title" => "Umbrella epic",
          "url" => "https://linear.app/test/issue/TEST-0",
          "state" => {"name" => "In Progress"}
        },
        "children" => {
          "nodes" => [
            {
              "identifier" => "TEST-2",
              "title" => "Sub-task A",
              "url" => "https://linear.app/test/issue/TEST-2",
              "state" => {"name" => "Done"}
            },
            {
              "identifier" => "TEST-3",
              "title" => "Sub-task B",
              "url" => "https://linear.app/test/issue/TEST-3",
              "state" => {"name" => "In Progress"}
            }
          ]
        }
      }
    end

    before do
      LinearToonMcp.client = client
      allow(client).to receive(:query).and_return("issue" => issue_data)
    end

    it "returns a TOON-encoded response" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      expect(response.content.first[:text]).to include("TEST-1")
      expect(response.content.first[:text]).to include("Fix the bug")
    end

    it "includes the parent issue in the response" do
      expect(response.content.first[:text]).to include("TEST-0")
      expect(response.content.first[:text]).to include("Umbrella epic")
    end

    it "includes all child issues in the response" do
      text = response.content.first[:text]
      expect(text).to include("TEST-2")
      expect(text).to include("Sub-task A")
      expect(text).to include("TEST-3")
      expect(text).to include("Sub-task B")
    end

    it "requests parent and capped children fields from Linear" do
      response
      expect(client).to have_received(:query).with(
        a_string_matching(/parent \{ identifier title url state \{ name \} \}/)
          .and(a_string_matching(/children\(first: 50\) \{ nodes \{ identifier title url state \{ name \} \} \}/)),
        variables: {id: "TEST-1"}
      )
    end

    it "queries Linear with the issue ID" do
      response
      expect(client).to have_received(:query).with(
        described_class::QUERY,
        variables: {id: "TEST-1"}
      )
    end

    context "when the issue has no parent and no children" do
      let(:issue_data) do
        super().merge(
          "parent" => nil,
          "children" => {"nodes" => []}
        )
      end

      it "still returns a successful response" do
        expect(response).to be_a(MCP::Tool::Response)
        expect(response).not_to be_error
        expect(response.content.first[:text]).to include("TEST-1")
      end
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
