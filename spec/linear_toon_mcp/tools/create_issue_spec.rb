# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::CreateIssue do
  describe ".call" do
    subject(:response) { described_class.call(**params, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:team_id) { "team-uuid" }
    let(:params) { {title: "New issue", team: team_id} }
    let(:issue_data) do
      {
        "id" => "issue-uuid",
        "identifier" => "TEST-1",
        "title" => "New issue",
        "url" => "https://linear.app/test/issue/TEST-1",
        "state" => {"name" => "Backlog"},
        "assignee" => nil,
        "team" => {"id" => team_id, "name" => "Engineering"},
        "labels" => {"nodes" => []},
        "project" => nil
      }
    end

    before do
      allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, team_id).and_return(team_id)
      allow(client).to receive(:query).and_return(
        "issueCreate" => {"success" => true, "issue" => issue_data}
      )
    end

    it "returns a TOON-encoded issue" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:text]).to include("TEST-1")
      expect(response.content.first[:text]).to include("New issue")
    end

    it "calls the mutation with title and teamId" do
      response
      expect(client).to have_received(:query).with(
        described_class::MUTATION,
        variables: {input: {title: "New issue", teamId: team_id}}
      )
    end

    context "with direct fields" do
      let(:params) { {title: "New issue", team: team_id, description: "Details", priority: 2, estimate: 3, dueDate: "2026-06-01", parentId: "parent-uuid"} }

      it "passes direct fields through to mutation input" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {input: hash_including(
            title: "New issue", teamId: team_id, description: "Details",
            priority: 2, estimate: 3, dueDate: "2026-06-01", parentId: "parent-uuid"
          )}
        )
      end
    end

    context "with resolved fields" do
      let(:params) { {title: "New issue", team: "Engineering", assignee: "Alice", state: "In Progress", labels: ["bug", "urgent"], project: "My Project", cycle: "Sprint 5"} }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).with(client, "Engineering").and_return(team_id)
        allow(LinearToonMcp::Resolvers).to receive(:resolve_user).with(client, "Alice").and_return("user-uuid")
        allow(LinearToonMcp::Resolvers).to receive(:resolve_state).with(client, team_id, "In Progress").and_return("state-uuid")
        allow(LinearToonMcp::Resolvers).to receive(:resolve_labels).with(client, ["bug", "urgent"]).and_return(["l1", "l2"])
        allow(LinearToonMcp::Resolvers).to receive(:resolve_project).with(client, "My Project").and_return("proj-uuid")
        allow(LinearToonMcp::Resolvers).to receive(:resolve_cycle).with(client, team_id, "Sprint 5").and_return("cycle-uuid")
      end

      it "resolves names and passes IDs to mutation" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {input: hash_including(
            teamId: team_id, assigneeId: "user-uuid", stateId: "state-uuid",
            labelIds: ["l1", "l2"], projectId: "proj-uuid", cycleId: "cycle-uuid"
          )}
        )
      end
    end

    context "with milestone" do
      let(:params) { {title: "New issue", team: team_id, project: "My Project", milestone: "MVP"} }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_project).with(client, "My Project").and_return("proj-uuid")
        allow(LinearToonMcp::Resolvers).to receive(:resolve_milestone).with(client, "proj-uuid", "MVP").and_return("ms-uuid")
      end

      it "resolves milestone using project_id" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {input: hash_including(projectId: "proj-uuid", projectMilestoneId: "ms-uuid")}
        )
      end
    end

    context "with delegate" do
      let(:params) { {title: "New issue", team: team_id, delegate: "Alice"} }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_user).with(client, "Alice").and_return("user-uuid")
      end

      it "resolves delegate as user" do
        response
        expect(client).to have_received(:query).with(
          described_class::MUTATION,
          variables: {input: hash_including(assigneeId: "user-uuid")}
        )
      end
    end

    context "with blockedBy and blocks relations" do
      let(:params) { {title: "New issue", team: team_id, blockedBy: ["blocker-1"], blocks: ["blocked-1"], relatedTo: ["related-1"], duplicateOf: "dup-1"} }

      before do
        allow(client).to receive(:query).and_return(
          "issueCreate" => {"success" => true, "issue" => issue_data},
          "issueRelationCreate" => {"success" => true}
        )
      end

      it "creates relations after issue creation" do
        response
        expect(client).to have_received(:query).with(described_class::RELATION_MUTATION, variables: {input: {issueId: "issue-uuid", relatedIssueId: "blocker-1", type: "isBlockedBy"}})
        expect(client).to have_received(:query).with(described_class::RELATION_MUTATION, variables: {input: {issueId: "issue-uuid", relatedIssueId: "blocked-1", type: "blocks"}})
        expect(client).to have_received(:query).with(described_class::RELATION_MUTATION, variables: {input: {issueId: "issue-uuid", relatedIssueId: "related-1", type: "related"}})
        expect(client).to have_received(:query).with(described_class::RELATION_MUTATION, variables: {input: {issueId: "issue-uuid", relatedIssueId: "dup-1", type: "duplicate"}})
      end
    end

    context "with links" do
      let(:params) { {title: "New issue", team: team_id, links: [{"url" => "https://example.com", "title" => "Example"}]} }

      before do
        allow(client).to receive(:query).and_return(
          "issueCreate" => {"success" => true, "issue" => issue_data},
          "attachmentLinkURL" => {"success" => true}
        )
      end

      it "creates link attachments after issue creation" do
        response
        expect(client).to have_received(:query).with(described_class::LINK_MUTATION, variables: {url: "https://example.com", issueId: "issue-uuid", title: "Example"})
      end
    end

    context "when mutation returns success: false" do
      before do
        allow(client).to receive(:query).and_return(
          "issueCreate" => {"success" => false, "issue" => nil}
        )
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("failed")
      end
    end

    context "when resolver fails" do
      let(:params) { {title: "New issue", team: "Missing"} }

      before do
        allow(LinearToonMcp::Resolvers).to receive(:resolve_team).and_raise(LinearToonMcp::Error, "Team not found: Missing")
      end

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("Team not found")
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
