# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::ProjectStatus do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  before { LinearToonMcp.client = client }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(value: uuid)).to eq(uuid)
  end

  it "resolves a project status by name" do
    allow(client).to receive(:query).and_return("projectStatuses" => {"nodes" => [{"id" => uuid}]})
    expect(described_class.call(value: "Planned")).to eq(uuid)
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "Planned"}}}
    )
  end

  it "raises when status not found" do
    allow(client).to receive(:query).and_return("projectStatuses" => {"nodes" => []})
    expect { described_class.call(value: "Missing") }
      .to raise_error(LinearToonMcp::Error, /\AStatus not found: Missing\z/)
  end
end
