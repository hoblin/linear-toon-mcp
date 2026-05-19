# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Initiative do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  before { LinearToonMcp.client = client }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(value: uuid)).to eq(uuid)
  end

  it "resolves via the name filter" do
    allow(client).to receive(:query).and_return("initiatives" => {"nodes" => [{"id" => uuid}]})
    expect(described_class.call(value: "Q1 Initiative")).to eq(uuid)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Q1 Initiative"}}}
    )
  end

  it "raises when initiative not found" do
    allow(client).to receive(:query).and_return("initiatives" => {"nodes" => []})
    expect { described_class.call(value: "Missing") }
      .to raise_error(LinearToonMcp::Error, /\AInitiative not found: Missing\z/)
  end
end
