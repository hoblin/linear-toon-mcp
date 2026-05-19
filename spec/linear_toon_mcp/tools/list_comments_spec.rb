# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::ListComments do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:comments) do
    {"nodes" => [], "pageInfo" => {"hasNextPage" => false, "endCursor" => nil}}
  end

  before do
    LinearToonMcp.client = client
    allow(client).to receive(:query).and_return("comments" => comments)
  end

  describe "XOR parent validation" do
    it "rejects calls with no parent" do
      response = described_class.call
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `issue`, `project`, `initiative`, or `projectUpdate`")
    end

    it "rejects calls with multiple parents" do
      response = described_class.call(issue: "I", project: "P")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `issue`")
    end
  end

  describe "parent dispatch" do
    it "passes issue UUID/identifier straight through to the filter" do
      described_class.call(issue: "VIB-44")
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(filter: {issue: {id: {eq: "VIB-44"}}})
      )
    end

    it "resolves project name via Resolvers::Project" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "P").and_return("p-1")
      described_class.call(project: "P")
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(filter: {project: {id: {eq: "p-1"}}})
      )
    end

    it "resolves initiative name via Resolvers::Initiative" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).with(value: "Q1").and_return("i-1")
      described_class.call(initiative: "Q1")
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(filter: {initiative: {id: {eq: "i-1"}}})
      )
    end

    it "passes projectUpdate UUID straight through to the filter" do
      described_class.call(projectUpdate: "pu-1")
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(filter: {projectUpdate: {id: {eq: "pu-1"}}})
      )
    end
  end

  describe "response handling" do
    it "returns an error when comments field is nil (unexpected response)" do
      allow(client).to receive(:query).and_return("comments" => nil)
      response = described_class.call(issue: "VIB-1")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Unexpected response")
    end

    it "surfaces client errors as MCP error responses" do
      allow(client).to receive(:query)
        .and_raise(LinearToonMcp::Error, "HTTP 500: Server error")
      response = described_class.call(issue: "VIB-1")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("HTTP 500")
    end
  end

  describe "pagination" do
    it "defaults to first: 50, orderBy: createdAt" do
      described_class.call(issue: "VIB-1")
      expect(client).to have_received(:query).with(
        anything,
        variables: hash_including(first: 50, orderBy: "createdAt")
      )
    end

    it "clamps limit to 250 max" do
      described_class.call(issue: "VIB-1", limit: 500)
      expect(client).to have_received(:query).with(anything, variables: hash_including(first: 250))
    end

    it "passes cursor through as after" do
      described_class.call(issue: "VIB-1", cursor: "abc")
      expect(client).to have_received(:query).with(anything, variables: hash_including(after: "abc"))
    end
  end
end
