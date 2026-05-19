# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListStatusUpdates do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:updates) do
    {"nodes" => [], "pageInfo" => {"hasNextPage" => false, "endCursor" => nil}}
  end

  before { LinearToonMcp.client = client }

  describe "XOR parent validation" do
    it "rejects calls with neither project: nor initiative:" do
      response = described_class.call
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `project` or `initiative`")
    end

    it "rejects calls with both project: and initiative:" do
      response = described_class.call(project: "P", initiative: "I")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `project` or `initiative`")
    end
  end

  describe "with project: filter" do
    before do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call)
        .with(value: "My Project").and_return("p-1")
      allow(client).to receive(:query).and_return("projectUpdates" => updates)
    end

    it "resolves the project and queries projectUpdates with project filter" do
      described_class.call(project: "My Project")
      expect(LinearToonMcp::Resolvers::Project).to have_received(:call).with(value: "My Project")
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdates\(filter:/),
        variables: hash_including(filter: {project: {id: {eq: "p-1"}}})
      )
    end

    it "applies default pagination (first: 50, orderBy: updatedAt, includeArchived: false)" do
      described_class.call(project: "My Project")
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(first: 50, orderBy: "updatedAt", includeArchived: false)
      )
    end

    it "respects cursor and limit clamping" do
      described_class.call(project: "My Project", cursor: "abc", limit: 500)
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(first: 250, after: "abc")
      )
    end
  end

  describe "resolver errors" do
    it "surfaces project resolution errors" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call)
        .and_raise(LinearToonMcp::Error, "Project not found: Missing")
      response = described_class.call(project: "Missing")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Project not found")
    end

    it "surfaces initiative resolution errors" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
        .and_raise(LinearToonMcp::Error, "Initiative not found: Missing")
      response = described_class.call(initiative: "Missing")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Initiative not found")
    end
  end

  describe "with initiative: filter" do
    before do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
        .with(value: "Q1").and_return("i-1")
      allow(client).to receive(:query).and_return("initiativeUpdates" => updates)
    end

    it "resolves the initiative and queries initiativeUpdates with initiative filter" do
      described_class.call(initiative: "Q1")
      expect(LinearToonMcp::Resolvers::Initiative).to have_received(:call).with(value: "Q1")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdates\(filter:/),
        variables: hash_including(filter: {initiative: {id: {eq: "i-1"}}})
      )
    end
  end
end
