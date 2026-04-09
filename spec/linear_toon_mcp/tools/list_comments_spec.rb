# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListComments do
  describe ".call" do
    subject(:response) { described_class.call(issueId: issue_id, server_context: {client:}) }

    let(:issue_id) { "TEST-1" }
    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:comments_data) do
      {
        "nodes" => [
          {
            "id" => "comment-1",
            "body" => "First comment",
            "createdAt" => "2026-01-01T10:00:00.000Z",
            "editedAt" => nil,
            "user" => {"id" => "user-1", "name" => "Alice"}
          },
          {
            "id" => "comment-2",
            "body" => "Second comment (edited)",
            "createdAt" => "2026-01-02T11:00:00.000Z",
            "editedAt" => "2026-01-02T12:00:00.000Z",
            "user" => {"id" => "user-2", "name" => "Bob"}
          }
        ],
        "pageInfo" => {"hasNextPage" => false, "endCursor" => nil}
      }
    end

    before do
      allow(client).to receive(:query).and_return("issue" => {"comments" => comments_data})
    end

    it "returns a TOON-encoded response with all comments" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      expect(response.content.first[:text]).to include("First comment")
      expect(response.content.first[:text]).to include("Second comment (edited)")
      expect(response.content.first[:text]).to include("Alice")
      expect(response.content.first[:text]).to include("Bob")
    end

    it "queries Linear with the issue identifier" do
      response
      expect(client).to have_received(:query).with(
        described_class::QUERY,
        variables: {id: "TEST-1"}
      )
    end

    context "when the issue has no comments" do
      let(:comments_data) do
        {"nodes" => [], "pageInfo" => {"hasNextPage" => false, "endCursor" => nil}}
      end

      it "returns a successful TOON-encoded empty connection" do
        expect(response).to be_a(MCP::Tool::Response)
        expect(response).not_to be_error
        expect(response.content.first[:text]).not_to be_empty
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

    context "when server_context has no client" do
      subject(:response) { described_class.call(issueId: issue_id, server_context: {}) }

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
