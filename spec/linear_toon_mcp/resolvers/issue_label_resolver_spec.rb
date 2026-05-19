# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::IssueLabelResolver do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }
  let(:team_id) { "team-uuid" }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(client, uuid)).to eq(uuid)
  end

  it "uses a plain name filter when no team given" do
    allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => [{"id" => "label-uuid"}]})
    expect(described_class.call(client, "bug")).to eq("label-uuid")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "bug"}}}
    )
  end

  it "scopes the lookup to the team or workspace-wide labels when team_id is given" do
    allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => [{"id" => "label-uuid"}]})
    described_class.call(client, "bug", team_id: team_id)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {
        name: {eqIgnoreCase: "bug"},
        or: [
          {team: {null: true}},
          {team: {id: {eq: team_id}}}
        ]
      }}
    )
  end

  it "raises a team-aware error when label not found on team or workspace" do
    allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => []})
    expect { described_class.call(client, "Missing", team_id: team_id) }
      .to raise_error(LinearToonMcp::Error, /Label not found on target team or workspace: Missing/)
  end

  it "raises a plain error when label not found without team scope" do
    allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => []})
    expect { described_class.call(client, "Missing") }
      .to raise_error(LinearToonMcp::Error, /\ALabel not found: Missing\z/)
  end

  describe ".call_many" do
    it "resolves each label individually" do
      allow(client).to receive(:query).and_return(
        {"issueLabels" => {"nodes" => [{"id" => "l1"}]}},
        {"issueLabels" => {"nodes" => [{"id" => "l2"}]}}
      )
      expect(described_class.call_many(client, ["bug", "feature"])).to eq(["l1", "l2"])
    end

    it "passes through UUIDs without querying" do
      result = described_class.call_many(client, [uuid])
      expect(result).to eq([uuid])
    end

    it "forwards team_id to each per-label lookup" do
      allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => [{"id" => "l1"}]})
      described_class.call_many(client, ["bug"], team_id: team_id)
      expect(client).to have_received(:query).with(
        anything,
        variables: {filter: {
          name: {eqIgnoreCase: "bug"},
          or: [
            {team: {null: true}},
            {team: {id: {eq: team_id}}}
          ]
        }}
      )
    end

    it "mixes UUIDs and names without re-querying the UUIDs" do
      allow(client).to receive(:query).and_return("issueLabels" => {"nodes" => [{"id" => "name-resolved"}]})
      result = described_class.call_many(client, [uuid, "bug"], team_id: team_id)
      expect(result).to eq([uuid, "name-resolved"])
      expect(client).to have_received(:query).once
    end

    it "returns an empty array without querying when given no labels" do
      allow(client).to receive(:query)
      result = described_class.call_many(client, [], team_id: team_id)
      expect(result).to eq([])
      expect(client).not_to have_received(:query)
    end
  end
end
