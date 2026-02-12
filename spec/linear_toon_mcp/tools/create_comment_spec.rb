# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::CreateComment do
  describe ".call" do
    subject(:response) { described_class.call(**params, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:params) { {issueId: "issue-uuid", body: "Looks good!"} }
    let(:comment_data) do
      {
        "id" => "comment-uuid",
        "body" => "Looks good!",
        "createdAt" => "2026-01-01T00:00:00.000Z",
        "user" => {"id" => "user-1", "name" => "Alice"},
        "issue" => {"id" => "issue-uuid", "identifier" => "TEST-1"}
      }
    end

    before do
      allow(client).to receive(:query).and_return(
        "commentCreate" => {"success" => true, "comment" => comment_data}
      )
    end

    it "returns a TOON-encoded comment" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:text]).to include("comment-uuid")
      expect(response.content.first[:text]).to include("Looks good!")
    end

    it "calls the mutation with correct input" do
      response
      expect(client).to have_received(:query).with(
        described_class::MUTATION,
        variables: {input: {issueId: "issue-uuid", body: "Looks good!"}}
      )
    end

    context "with parentId" do
      let(:params) { {issueId: "issue-uuid", body: "Reply", parentId: "parent-uuid"} }

      it "includes parentId in mutation input" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {input: {issueId: "issue-uuid", body: "Reply", parentId: "parent-uuid"}}
        )
      end
    end

    context "when mutation returns success: false" do
      before do
        allow(client).to receive(:query).and_return(
          "commentCreate" => {"success" => false, "comment" => nil}
        )
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("failed")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(**params, server_context: {}) }

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
