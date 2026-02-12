# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  describe ".resolve_team" do
    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_team(client, uuid)).to eq(uuid)
    end

    it "resolves a name to an ID" do
      allow(client).to receive(:query).and_return("teams" => {"nodes" => [{"id" => uuid}]})
      expect(described_class.resolve_team(client, "Engineering")).to eq(uuid)
    end

    it "raises when team not found" do
      allow(client).to receive(:query).and_return("teams" => {"nodes" => []})
      expect { described_class.resolve_team(client, "Missing") }.to raise_error(LinearToonMcp::Error, /Team not found/)
    end
  end

  describe ".resolve_user" do
    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_user(client, uuid)).to eq(uuid)
    end

    it "resolves 'me' via viewer query" do
      allow(client).to receive(:query).and_return("viewer" => {"id" => uuid})
      expect(described_class.resolve_user(client, "me")).to eq(uuid)
    end

    it "resolves email via email filter" do
      allow(client).to receive(:query).and_return("users" => {"nodes" => [{"id" => uuid}]})
      described_class.resolve_user(client, "alice@example.com")
      expect(client).to have_received(:query).with(anything, variables: {filter: {email: {eq: "alice@example.com"}}})
    end

    it "resolves name via name filter" do
      allow(client).to receive(:query).and_return("users" => {"nodes" => [{"id" => uuid}]})
      described_class.resolve_user(client, "Alice")
      expect(client).to have_received(:query).with(anything, variables: {filter: {name: {eqIgnoreCase: "Alice"}}})
    end

    it "raises when user not found" do
      allow(client).to receive(:query).and_return("users" => {"nodes" => []})
      expect { described_class.resolve_user(client, "Nobody") }.to raise_error(LinearToonMcp::Error, /User not found/)
    end
  end

  describe ".resolve_state" do
    let(:team_id) { uuid }

    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_state(client, team_id, uuid)).to eq(uuid)
    end

    it "resolves a name to an ID" do
      allow(client).to receive(:query).and_return("workflowStates" => {"nodes" => [{"id" => "state-uuid"}]})
      expect(described_class.resolve_state(client, team_id, "In Progress")).to eq("state-uuid")
    end

    it "raises when state not found" do
      allow(client).to receive(:query).and_return("workflowStates" => {"nodes" => []})
      expect { described_class.resolve_state(client, team_id, "Missing") }.to raise_error(LinearToonMcp::Error, /State not found/)
    end
  end

  describe ".resolve_label" do
    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_label(client, uuid)).to eq(uuid)
    end

    it "resolves a name to an ID" do
      allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => [{"id" => "label-uuid"}]})
      expect(described_class.resolve_label(client, "bug")).to eq("label-uuid")
    end

    it "raises when label not found" do
      allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => []})
      expect { described_class.resolve_label(client, "Missing") }.to raise_error(LinearToonMcp::Error, /Label not found/)
    end
  end

  describe ".resolve_labels" do
    it "resolves each label individually" do
      allow(client).to receive(:query)
        .and_return({"issueLabels" => {"nodes" => [{"id" => "l1"}]}}, {"issueLabels" => {"nodes" => [{"id" => "l2"}]}})
      expect(described_class.resolve_labels(client, ["bug", "feature"])).to eq(["l1", "l2"])
    end

    it "passes through UUIDs without querying" do
      result = described_class.resolve_labels(client, [uuid])
      expect(result).to eq([uuid])
    end
  end

  describe ".resolve_project" do
    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_project(client, uuid)).to eq(uuid)
    end

    it "resolves a name to an ID" do
      allow(client).to receive(:query).and_return("projects" => {"nodes" => [{"id" => "proj-uuid"}]})
      expect(described_class.resolve_project(client, "My Project")).to eq("proj-uuid")
    end

    it "raises when project not found" do
      allow(client).to receive(:query).and_return("projects" => {"nodes" => []})
      expect { described_class.resolve_project(client, "Missing") }.to raise_error(LinearToonMcp::Error, /Project not found/)
    end
  end

  describe ".resolve_cycle" do
    let(:team_id) { uuid }

    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_cycle(client, team_id, uuid)).to eq(uuid)
    end

    it "resolves numeric string via number filter" do
      allow(client).to receive(:query).and_return("cycles" => {"nodes" => [{"id" => "cycle-uuid"}]})
      described_class.resolve_cycle(client, team_id, "42")
      expect(client).to have_received(:query).with(
        anything,
        variables: {filter: {number: {eq: 42}, team: {id: {eq: team_id}}}}
      )
    end

    it "resolves name via name filter" do
      allow(client).to receive(:query).and_return("cycles" => {"nodes" => [{"id" => "cycle-uuid"}]})
      described_class.resolve_cycle(client, team_id, "Sprint 5")
      expect(client).to have_received(:query).with(
        anything,
        variables: {filter: {name: {eqIgnoreCase: "Sprint 5"}, team: {id: {eq: team_id}}}}
      )
    end

    it "raises when cycle not found" do
      allow(client).to receive(:query).and_return("cycles" => {"nodes" => []})
      expect { described_class.resolve_cycle(client, team_id, "Missing") }.to raise_error(LinearToonMcp::Error, /Cycle not found/)
    end
  end

  describe ".resolve_milestone" do
    let(:project_id) { uuid }

    it "passes through UUIDs unchanged" do
      expect(described_class.resolve_milestone(client, project_id, uuid)).to eq(uuid)
    end

    it "resolves a name to an ID" do
      allow(client).to receive(:query).and_return("projectMilestones" => {"nodes" => [{"id" => "ms-uuid"}]})
      expect(described_class.resolve_milestone(client, project_id, "MVP")).to eq("ms-uuid")
    end

    it "raises when milestone not found" do
      allow(client).to receive(:query).and_return("projectMilestones" => {"nodes" => []})
      expect { described_class.resolve_milestone(client, project_id, "Missing") }.to raise_error(LinearToonMcp::Error, /Milestone not found/)
    end
  end
end
