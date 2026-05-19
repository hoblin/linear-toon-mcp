# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Cycle do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }
  let(:team_id) { uuid }

  before { LinearToonMcp.client = client }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(value: uuid, team_id: team_id)).to eq(uuid)
  end

  it "uses the number filter for digit-only values" do
    allow(client).to receive(:query).and_return("cycles" => {"nodes" => [{"id" => "cycle-uuid"}]})
    described_class.call(value: "42", team_id: team_id)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {number: {eq: 42}, team: {id: {eq: team_id}}}}
    )
  end

  it "uses the name filter otherwise" do
    allow(client).to receive(:query).and_return("cycles" => {"nodes" => [{"id" => "cycle-uuid"}]})
    described_class.call(value: "Sprint 5", team_id: team_id)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Sprint 5"}, team: {id: {eq: team_id}}}}
    )
  end

  it "raises when cycle not found" do
    allow(client).to receive(:query).and_return("cycles" => {"nodes" => []})
    expect { described_class.call(value: "Missing", team_id: team_id) }
      .to raise_error(LinearToonMcp::Error, /\ACycle not found: Missing\z/)
  end

  it "raises when team_id is missing" do
    expect { described_class.call(value: "Sprint 5") }
      .to raise_error(LinearToonMcp::Error, /Missing required scope: team_id/)
  end
end
