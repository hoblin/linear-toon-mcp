# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::DeleteProjectMilestone do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  it "submits projectMilestoneDelete with the milestone id" do
    allow(client).to receive(:query)
      .and_return("projectMilestoneDelete" => {"success" => true, "entityId" => "ms-1"})
    response = described_class.call(id: "ms-1")
    expect(client).to have_received(:query).with(
      a_string_matching(/projectMilestoneDelete/),
      variables: {id: "ms-1"}
    )
    expect(response).not_to be_error
    expect(response.content.first[:text]).to include("ms-1")
  end

  it "raises when the mutation reports success: false" do
    allow(client).to receive(:query)
      .and_return("projectMilestoneDelete" => {"success" => false, "entityId" => nil})
    response = described_class.call(id: "ms-1")
    expect(response).to be_a(MCP::Tool::Response).and be_error
    expect(response.content.first[:text]).to include("Milestone deletion failed")
  end

  it "raises when the response is missing the projectMilestoneDelete key" do
    allow(client).to receive(:query).and_return({})
    response = described_class.call(id: "ms-1")
    expect(response).to be_a(MCP::Tool::Response).and be_error
    expect(response.content.first[:text]).to include("Milestone deletion failed: no result returned")
  end
end
