# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::UpdateIssue do
  describe ".call" do
    subject(:response) { described_class.call(**params, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:issue_id) { "issue-uuid" }
    let(:params) { {id: issue_id, title: "Updated title"} }
    let(:issue_data) do
      {
        "id" => issue_id,
        "identifier" => "TEST-1",
        "title" => "Updated title",
        "url" => "https://linear.app/test/issue/TEST-1",
        "state" => {"name" => "In Progress"},
        "assignee" => nil,
        "team" => {"id" => "team-uuid", "name" => "Engineering"},
        "labels" => {"nodes" => []},
        "project" => nil
      }
    end

    before do
      allow(client).to receive(:query).and_return(
        "issueUpdate" => {"success" => true, "issue" => issue_data}
      )
    end

    it "returns a TOON-encoded issue" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:text]).to include("Updated title")
    end

    it "calls the mutation with id and title" do
      response
      expect(client).to have_received(:query).with(
        described_class::MUTATION,
        variables: {id: issue_id, input: {title: "Updated title"}}
      )
    end

    context "with direct fields" do
      let(:params) { {id: issue_id, description: "New desc", priority: 1, estimate: 5, dueDate: "2026-12-01"} }

      it "includes direct fields in input" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {id: issue_id, input: {description: "New desc", priority: 1, estimate: 5, dueDate: "2026-12-01"}}
        )
      end
    end

    context "with null assignee (removal)" do
      let(:params) { {id: issue_id, assignee: nil} }

      it "includes null assigneeId in input" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {id: issue_id, input: {assigneeId: nil}}
        )
      end
    end

    context "with null parentId (removal)" do
      let(:params) { {id: issue_id, parentId: nil} }

      it "includes null parentId in input" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {id: issue_id, input: {parentId: nil}}
        )
      end
    end

    context "with resolved fields" do
      let(:params) { {id: issue_id, team: "Engineering", assignee: "Alice", state: "Done"} }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, "Engineering").and_return("team-uuid")
        allow(LinearToonMcp::Resolvers).to receive(:resolve_user).with(client, "Alice").and_return("user-uuid")
        allow(LinearToonMcp::Resolvers).to receive(:resolve_state).with(client, "team-uuid", "Done").and_return("state-uuid")
      end

      it "resolves names to IDs" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {id: issue_id, input: hash_including(teamId: "team-uuid", assigneeId: "user-uuid", stateId: "state-uuid")}
        )
      end
    end

    context "with state but no team" do
      let(:params) { {id: issue_id, state: "Done"} }

      before do
        allow(client).to receive(:query).with(described_class::ISSUE_TEAM_QUERY, variables: {id: issue_id})
          .and_return("issue" => {"team" => {"id" => "fetched-team-uuid"}})
        allow(LinearToonMcp::Resolvers).to receive(:resolve_state).with(client, "fetched-team-uuid", "Done").and_return("state-uuid")
        allow(client).to receive(:query).with(described_class::MUTATION, anything)
          .and_return("issueUpdate" => {"success" => true, "issue" => issue_data})
      end

      it "fetches issue team and resolves state" do
        response
        expect(client).to have_received(:query).with(described_class::ISSUE_TEAM_QUERY, variables: {id: issue_id})
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {id: issue_id, input: hash_including(stateId: "state-uuid")}
        )
      end
    end

    context "with relation replacement" do
      let(:params) { {id: issue_id, blocks: ["new-blocked"]} }
      let(:existing_relations) do
        {
          "nodes" => [
            {"id" => "rel-1", "type" => "blocks", "relatedIssue" => {"id" => "old-blocked"}},
            {"id" => "rel-2", "type" => "related", "relatedIssue" => {"id" => "other"}}
          ]
        }
      end

      before do
        allow(client).to receive(:query).and_return(
          "issueUpdate" => {"success" => true, "issue" => issue_data},
          "issue" => {"relations" => existing_relations},
          "issueRelationDelete" => {"success" => true},
          "issueRelationCreate" => {"success" => true}
        )
      end

      it "queries existing relations, deletes matching type, creates new" do
        response
        expect(client).to have_received(:query).with(described_class::RELATIONS_QUERY, variables: {id: issue_id})
        expect(client).to have_received(:query).with(described_class::RELATION_DELETE_MUTATION, variables: {id: "rel-1"})
        expect(client).to have_received(:query).with(
          described_class::RELATION_MUTATION,
          variables: {input: {issueId: issue_id, relatedIssueId: "new-blocked", type: "blocks"}}
        )
      end

      it "does not delete relations of non-matching type" do
        response
        expect(client).not_to have_received(:query).with(described_class::RELATION_DELETE_MUTATION, variables: {id: "rel-2"})
      end
    end

    context "with empty relation array (delete all of type)" do
      let(:params) { {id: issue_id, blocks: []} }
      let(:existing_relations) do
        {"nodes" => [{"id" => "rel-1", "type" => "blocks", "relatedIssue" => {"id" => "old"}}]}
      end

      before do
        allow(client).to receive(:query).and_return(
          "issueUpdate" => {"success" => true, "issue" => issue_data},
          "issue" => {"relations" => existing_relations},
          "issueRelationDelete" => {"success" => true}
        )
      end

      it "deletes existing and creates none" do
        response
        expect(client).to have_received(:query).with(described_class::RELATION_DELETE_MUTATION, variables: {id: "rel-1"})
      end
    end

    context "with links" do
      let(:params) { {id: issue_id, links: [{"url" => "https://example.com", "title" => "Example"}]} }

      before do
        allow(client).to receive(:query).and_return(
          "issueUpdate" => {"success" => true, "issue" => issue_data},
          "attachmentLinkURL" => {"success" => true}
        )
      end

      it "creates link attachments" do
        response
        expect(client).to have_received(:query).with(
          described_class::LINK_MUTATION,
          variables: {url: "https://example.com", issueId: issue_id, title: "Example"}
        )
      end
    end

    context "with both assignee and delegate" do
      let(:params) { {id: issue_id, assignee: "Alice", delegate: "Bob"} }

      it "returns an error about conflicting params" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Cannot specify both assignee and delegate")
      end
    end

    context "when relation creation fails during replacement" do
      let(:params) { {id: issue_id, blocks: ["new-blocked"]} }

      before do
        allow(client).to receive(:query).with(described_class::MUTATION, anything)
          .and_return("issueUpdate" => {"success" => true, "issue" => issue_data})
        allow(client).to receive(:query).with(described_class::RELATIONS_QUERY, anything)
          .and_return("issue" => {"relations" => {"nodes" => []}})
        allow(client).to receive(:query).with(described_class::RELATION_MUTATION, anything)
          .and_return("issueRelationCreate" => {"success" => false})
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Failed to create blocks relation")
      end
    end

    context "with milestone but no project" do
      let(:params) { {id: issue_id, milestone: "MVP"} }

      it "returns an error about missing project" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("milestone requires project")
      end
    end

    context "when relation deletion fails" do
      let(:params) { {id: issue_id, blocks: ["new-blocked"]} }

      before do
        allow(client).to receive(:query).with(described_class::MUTATION, anything)
          .and_return("issueUpdate" => {"success" => true, "issue" => issue_data})
        allow(client).to receive(:query).with(described_class::RELATIONS_QUERY, anything)
          .and_return("issue" => {"relations" => {"nodes" => [{"id" => "rel-1", "type" => "blocks", "relatedIssue" => {"id" => "old"}}]}})
        allow(client).to receive(:query).with(described_class::RELATION_DELETE_MUTATION, anything)
          .and_return("issueRelationDelete" => {"success" => false})
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Failed to delete blocks relation")
      end
    end

    context "when link creation fails" do
      let(:params) { {id: issue_id, links: [{"url" => "https://bad.example", "title" => "Bad"}]} }

      before do
        allow(client).to receive(:query).with(described_class::MUTATION, anything)
          .and_return("issueUpdate" => {"success" => true, "issue" => issue_data})
        allow(client).to receive(:query).with(described_class::LINK_MUTATION, anything)
          .and_return("attachmentLinkURL" => {"success" => false})
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Failed to attach link")
      end
    end

    context "when mutation returns success: false" do
      before do
        allow(client).to receive(:query).and_return(
          "issueUpdate" => {"success" => false, "issue" => nil}
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

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("HTTP 400")
      end
    end
  end
end
