# frozen_string_literal: true

RSpec.describe LinearToonMcp::Resolvers::ProjectMilestone do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:uuid) { "12345678-1234-1234-1234-123456789012" }
  let(:project_id) { uuid }

  it "passes through UUIDs unchanged" do
    expect(described_class.call(client, value: uuid, project_id: project_id)).to eq(uuid)
  end

  it "scopes the filter by project" do
    allow(client).to receive(:query).and_return("projectMilestones" => {"nodes" => [{"id" => "ms-uuid"}]})
    expect(described_class.call(client, value: "MVP", project_id: project_id)).to eq("ms-uuid")
    expect(client).to have_received(:query).with(
      anything,
      variables: {filter: {name: {eqIgnoreCase: "MVP"}, project: {id: {eq: project_id}}}}
    )
  end

  it "raises when milestone not found" do
    allow(client).to receive(:query).and_return("projectMilestones" => {"nodes" => []})
    expect { described_class.call(client, value: "Missing", project_id: project_id) }
      .to raise_error(LinearToonMcp::Error, /\AMilestone not found: Missing\z/)
  end

  it "raises when project_id is missing" do
    expect { described_class.call(client, value: "MVP") }
      .to raise_error(LinearToonMcp::Error, /Missing required scope: project_id/)
  end
end
