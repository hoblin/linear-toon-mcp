# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::List do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "conventions derived from class name" do
    it "camelCases the leading word, dropping the List prefix" do
      expect(LinearToonMcp::Tools::ListTeams.connection_name).to eq("teams")
      expect(LinearToonMcp::Tools::ListIssueLabels.connection_name).to eq("issueLabels")
      expect(LinearToonMcp::Tools::ListUsers.connection_name).to eq("users")
    end
  end

  describe "DSL overrides" do
    it "honors an explicit connection name" do
      expect(LinearToonMcp::Tools::ListIssueStatuses.connection_name).to eq("workflowStates")
    end
  end

  describe "#perform" do
    let(:tool) do
      Class.new(described_class) do
        const_set(:QUERY, "query { things { nodes { id } } }")
        connection :things
      end
    end

    it "queries and extracts the connection field" do
      allow(client).to receive(:query).and_return("things" => {"nodes" => [{"id" => "1"}]})
      expect(tool.new.perform).to eq("nodes" => [{"id" => "1"}])
    end

    it "raises when the connection field is missing" do
      allow(client).to receive(:query).and_return({})
      expect { tool.new.perform }.to raise_error(LinearToonMcp::Error, /missing things field/)
    end
  end
end
