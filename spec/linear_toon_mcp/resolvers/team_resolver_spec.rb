# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::TeamResolver do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(client, uuid)).to eq(uuid)
  end

  it "resolves a name via the team filter" do
    allow(client).to receive(:query).and_return("teams" => {"nodes" => [{"id" => uuid}]})
    expect(described_class.call(client, "Engineering")).to eq(uuid)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Engineering"}}}
    )
  end

  it "raises when team not found" do
    allow(client).to receive(:query).and_return("teams" => {"nodes" => []})
    expect { described_class.call(client, "Missing") }
      .to raise_error(LinearToonMcp::Error, /\ATeam not found: Missing\z/)
  end
end
