# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::Project do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }

  before { LinearToonMcp.client = client }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(value: uuid)).to eq(uuid)
  end

  it "resolves via the name filter" do
    allow(client).to receive(:query).and_return("projects" => {"nodes" => [{"id" => "proj-uuid"}]})
    expect(described_class.call(value: "My Project")).to eq("proj-uuid")
  end

  it "falls back to slugId when name yields no result" do
    allow(client).to receive(:query)
      .and_return({"projects" => {"nodes" => []}}, {"projects" => {"nodes" => [{"id" => "proj-uuid"}]}})
    expect(described_class.call(value: "my-project")).to eq("proj-uuid")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {slugId: {eqIgnoreCase: "my-project"}}}
    )
  end

  it "raises when project not found by name or slug" do
    allow(client).to receive(:query).and_return("projects" => {"nodes" => []})
    expect { described_class.call(value: "Missing") }
      .to raise_error(LinearToonMcp::Error, /\AProject not found: Missing\z/)
  end
end
