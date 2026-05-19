# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ArchiveProject do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:archived) { {"id" => "p-1", "name" => "M", "archivedAt" => "2026-05-19T00:00:00Z"} }

  before do
    LinearToonMcp.client = client
    allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "M").and_return("p-1")
  end

  it "resolves the project name and submits projectArchive" do
    allow(client).to receive(:query)
      .and_return("projectArchive" => {"success" => true, "entity" => archived})
    described_class.call(project: "M")
    expect(LinearToonMcp::Resolvers::Project).to have_received(:call).with(value: "M")
    expect(client).to have_received(:query).with(
      a_string_matching(/projectArchive/),
      variables: {id: "p-1"}
    )
  end

  it "returns the archived entity" do
    allow(client).to receive(:query)
      .and_return("projectArchive" => {"success" => true, "entity" => archived})
    response = described_class.call(project: "M")
    text = response.content.first[:text]
    expect(text).to include("archivedAt")
  end

  it "raises when archive reports success: false" do
    allow(client).to receive(:query)
      .and_return("projectArchive" => {"success" => false, "entity" => nil})
    response = described_class.call(project: "M")
    expect(response).to be_error
    expect(response.content.first[:text]).to include("Project archive failed")
  end

  it "raises when result key is missing" do
    allow(client).to receive(:query).and_return({})
    response = described_class.call(project: "M")
    expect(response).to be_error
    expect(response.content.first[:text]).to include("no result returned")
  end
end
