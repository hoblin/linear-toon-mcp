# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::GetTeam do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:team_data) { {"id" => "t-1", "name" => "Engineering", "key" => "ENG"} }

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Team).to receive(:call).with(value: "ENG").and_return("t-1")
    allow(client).to receive(:query).and_return("team" => team_data)
  end

  it "resolves the team via Resolvers::Team and queries by id" do
    described_class.call(query: "ENG")
    expect(LinearToonMcp::Resolvers::Team).to have_received(:call).with(value: "ENG")
    expect(client).to have_received(:query).with(anything, variables: {id: "t-1"})
  end

  it "returns the team" do
    response = described_class.call(query: "ENG")
    text = response.content.first[:text]
    expect(text).to include("Engineering")
    expect(text).to include("ENG")
  end
end
