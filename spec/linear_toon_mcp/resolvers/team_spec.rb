# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Team do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  before { LinearToonMcp.client = client }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(value: uuid)).to eq(uuid)
  end

  it "resolves a name via the name filter" do
    allow(client).to receive(:query).and_return("teams" => {"nodes" => [{"id" => uuid}]})
    expect(described_class.call(value: "Engineering")).to eq(uuid)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Engineering"}}}
    )
  end

  it "resolves an uppercase team key via the key filter" do
    allow(client).to receive(:query).and_return("teams" => {"nodes" => [{"id" => uuid}]})
    expect(described_class.call(value: "ENG")).to eq(uuid)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {key: {eq: "ENG"}}}
    )
  end

  it "falls back to the name filter when the key lookup misses" do
    allow(client).to receive(:query)
      .and_return({"teams" => {"nodes" => []}}, {"teams" => {"nodes" => [{"id" => uuid}]}})
    expect(described_class.call(value: "ENG")).to eq(uuid)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "ENG"}}}
    )
  end

  it "raises when team not found" do
    allow(client).to receive(:query).and_return("teams" => {"nodes" => []})
    expect { described_class.call(value: "Missing") }
      .to raise_error(LinearToonMcp::Error, /\ATeam not found: Missing\z/)
  end
end
