# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::WorkflowStateResolver do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }
  let(:team_id) { uuid }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(client, uuid, team_id: team_id)).to eq(uuid)
  end

  it "scopes the filter by team" do
    allow(client).to receive(:query).and_return("workflowStates" => {"nodes" => [{"id" => "state-uuid"}]})
    expect(described_class.call(client, "In Progress", team_id: team_id)).to eq("state-uuid")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "In Progress"}, team: {id: {eq: team_id}}}}
    )
  end

  it "resolves a lowercase enum value via the type filter" do
    allow(client).to receive(:query).and_return("workflowStates" => {"nodes" => [{"id" => "state-uuid"}]})
    expect(described_class.call(client, "started", team_id: team_id)).to eq("state-uuid")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {type: {eq: "started"}, team: {id: {eq: team_id}}}}
    )
  end

  it "treats capitalized enum tokens as names (no type collision)" do
    allow(client).to receive(:query).and_return("workflowStates" => {"nodes" => [{"id" => "state-uuid"}]})
    described_class.call(client, "Started", team_id: team_id)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Started"}, team: {id: {eq: team_id}}}}
    )
  end

  it "raises when state not found" do
    allow(client).to receive(:query).and_return("workflowStates" => {"nodes" => []})
    expect { described_class.call(client, "Missing", team_id: team_id) }
      .to raise_error(LinearToonMcp::Error, /\AState not found: Missing\z/)
  end

  it "raises when team_id is missing" do
    expect { described_class.call(client, "In Progress") }
      .to raise_error(ArgumentError, /Missing required scope: team_id/)
  end
end
