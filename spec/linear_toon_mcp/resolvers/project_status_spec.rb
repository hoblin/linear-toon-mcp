# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::ProjectStatus do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }
  let(:statuses) do
    {"projectStatuses" => {"nodes" => [
      {"id" => "backlog-id", "name" => "Backlog"},
      {"id" => uuid, "name" => "Planned"}
    ]}}
  end

  before { LinearToonMcp.client = client }

  it "passes through UUIDs without querying" do
    allow(client).to receive(:query)
    expect(described_class.call(value: uuid)).to eq(uuid)
    expect(client).not_to have_received(:query)
  end

  it "resolves a project status by name from the unfiltered list" do
    allow(client).to receive(:query).and_return(statuses)
    expect(described_class.call(value: "Planned")).to eq(uuid)
    expect(client).to have_received(:query).with(described_class::QUERY)
  end

  it "matches status names case-insensitively" do
    allow(client).to receive(:query).and_return(statuses)
    expect(described_class.call(value: "planned")).to eq(uuid)
  end

  it "raises when status not found" do
    allow(client).to receive(:query).and_return(statuses)
    expect { described_class.call(value: "Missing") }
      .to raise_error(LinearToonMcp::Error, /\AStatus not found: Missing\z/)
  end

  it "raises when the workspace has no statuses" do
    allow(client).to receive(:query).and_return("projectStatuses" => nil)
    expect { described_class.call(value: "Planned") }
      .to raise_error(LinearToonMcp::Error, /\AStatus not found: Planned\z/)
  end
end
