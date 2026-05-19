# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetIssueStatus do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:state_data) { {"id" => "s-1", "name" => "In Progress", "type" => "started"} }

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Team).to receive(:call).with(value: "VIB").and_return("t-1")
    allow(LinearToonMcp::Resolvers::WorkflowState).to receive(:call)
      .with(value: "In Progress", team_id: "t-1").and_return("s-1")
    allow(client).to receive(:query).and_return("workflowState" => state_data)
  end

  it "resolves team then state (team-scoped) and queries by state id" do
    described_class.call(query: "In Progress", team: "VIB")
    expect(LinearToonMcp::Resolvers::Team).to have_received(:call).with(value: "VIB")
    expect(LinearToonMcp::Resolvers::WorkflowState).to have_received(:call)
      .with(value: "In Progress", team_id: "t-1")
    expect(client).to have_received(:query).with(
      a_string_matching(/workflowState\(id:/),
      variables: {id: "s-1"}
    )
  end

  it "returns the state" do
    response = described_class.call(query: "In Progress", team: "VIB")
    expect(response.content.first[:text]).to include("In Progress")
  end
end
