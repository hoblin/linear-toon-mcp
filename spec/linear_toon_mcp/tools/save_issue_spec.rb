# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveIssue do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:team_id) { "team-1" }
  let(:issue_data) do
    {"id" => "issue-1", "identifier" => "VIB-1", "title" => "Test", "url" => "https://linear.app/x"}
  end

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Team).to receive(:call).and_return(team_id)
  end

  describe "dispatch" do
    it "calls issueCreate when id is absent" do
      allow(client).to receive(:query)
        .and_return("issueCreate" => {"success" => true, "issue" => issue_data})
      described_class.call(title: "T", team: "X")
      expect(client).to have_received(:query).with(a_string_matching(/issueCreate/), anything)
    end

    it "calls issueUpdate when id is present" do
      allow(client).to receive(:query)
        .and_return("issueUpdate" => {"success" => true, "issue" => issue_data})
      described_class.call(id: "issue-1", title: "Updated")
      expect(client).to have_received(:query).with(a_string_matching(/issueUpdate/), anything)
    end
  end

  describe "mutually exclusive assignee/delegate" do
    it "rejects calls passing both assignee and delegate" do
      response = described_class.call(id: "issue-1", assignee: "a", delegate: "b")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Cannot specify both assignee and delegate")
    end
  end

  describe "create path" do
    before do
      allow(client).to receive(:query)
        .and_return("issueCreate" => {"success" => true, "issue" => issue_data})
    end

    it "requires title" do
      response = described_class.call(team: "X")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("title is required")
    end

    it "requires team" do
      response = described_class.call(title: "T")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("team is required")
    end

    it "resolves and includes team, assignee, state, labels, project, cycle" do
      allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "Alice").and_return("u-1")
      allow(LinearToonMcp::Resolvers::WorkflowState).to receive(:call).and_return("s-1")
      allow(LinearToonMcp::Resolvers::IssueLabel).to receive(:call_many).and_return(["l-1"])
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).and_return("p-1")
      allow(LinearToonMcp::Resolvers::Cycle).to receive(:call).and_return("c-1")

      described_class.call(
        title: "T", team: "X",
        assignee: "Alice", state: "In Progress", labels: ["bug"],
        project: "P", cycle: "Sprint 5"
      )

      expect(client).to have_received(:query).with(
        a_string_matching(/issueCreate/),
        variables: {input: hash_including(
          title: "T", teamId: team_id,
          assigneeId: "u-1", stateId: "s-1", labelIds: ["l-1"],
          projectId: "p-1", cycleId: "c-1"
        )}
      )
    end

    it "rejects milestone without project" do
      response = described_class.call(title: "T", team: "X", milestone: "M")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("milestone requires project")
    end

    it "appends relations after create (does not replace)" do
      allow(client).to receive(:query)
        .with(a_string_matching(/issueRelationCreate/), anything)
        .and_return("issueRelationCreate" => {"success" => true})

      described_class.call(title: "T", team: "X", blocks: ["LIN-9"], relatedTo: ["LIN-10"])

      expect(client).to have_received(:query).with(
        a_string_matching(/issueRelationCreate/),
        variables: {input: hash_including(relatedIssueId: "LIN-9", type: "blocks")}
      )
      expect(client).to have_received(:query).with(
        a_string_matching(/issueRelationCreate/),
        variables: {input: hash_including(relatedIssueId: "LIN-10", type: "related")}
      )
    end

    it "appends link attachments and aggregates failures as warnings" do
      allow(client).to receive(:query)
        .with(a_string_matching(/attachmentLinkURL/), anything)
        .and_return("attachmentLinkURL" => {"success" => false})

      response = described_class.call(
        title: "T", team: "X",
        links: [{url: "https://x", title: "X"}]
      )
      expect(response.content.first[:text]).to include("WARNING (issue was created)")
      expect(response.content.first[:text]).to include("Failed to attach link")
    end
  end

  describe "update path" do
    before do
      allow(client).to receive(:query)
        .with(a_string_matching(/issueUpdate/), anything)
        .and_return("issueUpdate" => {"success" => true, "issue" => issue_data})
    end

    it "does not fetch the issue team when no team-scoped field is being updated" do
      described_class.call(id: "issue-1", title: "Updated")
      expect(client).not_to have_received(:query).with(a_string_matching(/issue\(id:.*team/m), anything)
    end

    it "fetches the issue team lazily when state is being updated" do
      allow(client).to receive(:query)
        .with(a_string_matching(/issue\(id: \$id\) \{ team \{ id \} \}/), anything)
        .and_return("issue" => {"team" => {"id" => "fetched-team-1"}})
      allow(LinearToonMcp::Resolvers::WorkflowState).to receive(:call)
        .with(value: "Done", team_id: "fetched-team-1").and_return("s-1")

      described_class.call(id: "issue-1", state: "Done")
      expect(LinearToonMcp::Resolvers::WorkflowState).to have_received(:call).with(value: "Done", team_id: "fetched-team-1")
    end

    it "treats assignee: nil as 'remove' (sends assigneeId: null)" do
      described_class.call(id: "issue-1", assignee: nil)
      expect(client).to have_received(:query).with(
        a_string_matching(/issueUpdate/),
        variables: {id: "issue-1", input: {assigneeId: nil}}
      )
    end

    it "treats delegate: nil as 'remove' (sends assigneeId: null)" do
      described_class.call(id: "issue-1", delegate: nil)
      expect(client).to have_received(:query).with(
        a_string_matching(/issueUpdate/),
        variables: {id: "issue-1", input: {assigneeId: nil}}
      )
    end

    it "treats parentId: nil as 'remove' (sends parentId: null)" do
      described_class.call(id: "issue-1", parentId: nil)
      expect(client).to have_received(:query).with(
        a_string_matching(/issueUpdate/),
        variables: {id: "issue-1", input: {parentId: nil}}
      )
    end

    it "deletes existing relations then creates new ones (replace semantics)" do
      allow(client).to receive(:query)
        .with(a_string_matching(/issue\(id: \$id\)/), anything)
        .and_return("issue" => {"relations" => {"nodes" => [
          {"id" => "rel-old", "type" => "blocks", "relatedIssue" => {"id" => "old-blocked"}}
        ]}})
      allow(client).to receive(:query)
        .with(a_string_matching(/issueRelationDelete/), anything)
        .and_return("issueRelationDelete" => {"success" => true})
      allow(client).to receive(:query)
        .with(a_string_matching(/issueRelationCreate/), anything)
        .and_return("issueRelationCreate" => {"success" => true})

      described_class.call(id: "issue-1", blocks: ["LIN-9"])

      expect(client).to have_received(:query).with(
        a_string_matching(/issueRelationDelete/),
        variables: {id: "rel-old"}
      )
      expect(client).to have_received(:query).with(
        a_string_matching(/issueRelationCreate/),
        variables: {input: hash_including(relatedIssueId: "LIN-9", type: "blocks")}
      )
    end

    it "aggregates post-update failures as warnings" do
      allow(client).to receive(:query)
        .with(a_string_matching(/issue\(id: \$id\)/), anything)
        .and_return("issue" => {"relations" => {"nodes" => []}})
      allow(client).to receive(:query)
        .with(a_string_matching(/issueRelationCreate/), anything)
        .and_return("issueRelationCreate" => {"success" => false})

      response = described_class.call(id: "issue-1", blocks: ["LIN-9"])
      expect(response.content.first[:text]).to include("WARNING (issue was updated)")
      expect(response.content.first[:text]).to include("Failed to create blocks relation")
    end

    it "rejects milestone update without project" do
      response = described_class.call(id: "issue-1", milestone: "M")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("milestone requires project")
    end
  end

  describe "mutation result handling" do
    it "raises when create reports success: false" do
      allow(client).to receive(:query)
        .and_return("issueCreate" => {"success" => false, "issue" => nil})
      response = described_class.call(title: "T", team: "X")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Issue save failed")
    end

    it "raises when create result key is missing" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(title: "T", team: "X")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("no result returned")
    end
  end
end
