# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::CreateIssueLabel do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "#variables" do
    before do
      allow(client).to receive(:query)
        .and_return("issueLabelCreate" => {"success" => true, "issueLabel" => {"id" => "l-1", "name" => "bug"}})
    end

    it "creates a workspace-wide label when team is omitted" do
      described_class.call(name: "bug")
      expect(client).to have_received(:query).with(
        a_string_matching(/issueLabelCreate/),
        variables: {input: {name: "bug"}}
      )
    end

    it "resolves team and includes teamId when team is given" do
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).with(value: "VIB").and_return("t-1")
      described_class.call(name: "bug", team: "VIB")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {name: "bug", teamId: "t-1"}}
      )
    end

    it "passes color through" do
      described_class.call(name: "bug", color: "#FF0000")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {name: "bug", color: "#FF0000"}}
      )
    end
  end
end
