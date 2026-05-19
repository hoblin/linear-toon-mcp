# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveComment do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:comment_data) { {"id" => "c-1", "body" => "hi"} }

  before { LinearToonMcp.client = client }

  describe "create — XOR parent validation" do
    it "rejects calls with no parent when id is absent" do
      response = described_class.call(body: "hi")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `issue`, `project`, `initiative`, or `projectUpdate`")
    end

    it "rejects calls with multiple parents when id is absent" do
      response = described_class.call(body: "hi", issue: "I", project: "P")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `issue`")
    end
  end

  describe "create parent dispatch" do
    before do
      allow(client).to receive(:query)
        .and_return("commentCreate" => {"success" => true, "comment" => comment_data})
    end

    it "passes issue UUID/identifier straight through as issueId" do
      described_class.call(body: "hi", issue: "VIB-44")
      expect(client).to have_received(:query).with(
        a_string_matching(/commentCreate/),
        variables: {input: {body: "hi", issueId: "VIB-44"}}
      )
    end

    it "resolves project name and sends projectId" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "P").and_return("p-1")
      described_class.call(body: "hi", project: "P")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {body: "hi", projectId: "p-1"}}
      )
    end

    it "resolves initiative name and sends initiativeId" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).with(value: "Q1").and_return("i-1")
      described_class.call(body: "hi", initiative: "Q1")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {body: "hi", initiativeId: "i-1"}}
      )
    end

    it "passes projectUpdate UUID straight through as projectUpdateId" do
      described_class.call(body: "hi", projectUpdate: "pu-1")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {body: "hi", projectUpdateId: "pu-1"}}
      )
    end

    it "supports threaded replies via parentId" do
      described_class.call(body: "hi", issue: "VIB-1", parentId: "parent-c-1")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {body: "hi", issueId: "VIB-1", parentId: "parent-c-1"}}
      )
    end
  end

  describe "update path" do
    before do
      allow(client).to receive(:query)
        .and_return("commentUpdate" => {"success" => true, "comment" => comment_data})
    end

    it "calls commentUpdate with id and new body; ignores any parent args" do
      described_class.call(id: "c-1", body: "edited", issue: "ignored")
      expect(client).to have_received(:query).with(
        a_string_matching(/commentUpdate/),
        variables: {id: "c-1", input: {body: "edited"}}
      )
    end
  end

  describe "mutation result handling" do
    it "raises when create reports success: false" do
      allow(client).to receive(:query)
        .and_return("commentCreate" => {"success" => false, "comment" => nil})
      response = described_class.call(body: "x", issue: "VIB-1")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Comment save failed")
    end

    it "raises when the response is missing the mutation key" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(body: "x", issue: "VIB-1")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("no result returned")
    end

    it "raises when update reports success: false" do
      allow(client).to receive(:query)
        .and_return("commentUpdate" => {"success" => false, "comment" => nil})
      response = described_class.call(id: "c-1", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Comment save failed")
    end
  end
end
