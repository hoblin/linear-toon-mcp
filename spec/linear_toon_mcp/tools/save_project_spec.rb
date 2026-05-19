# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveProject do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:project_data) { {"id" => "p-1", "name" => "Migration"} }

  before { LinearToonMcp.client = client }

  describe "dispatch" do
    it "calls projectCreate when id is absent" do
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).and_return("t-1")
      allow(client).to receive(:query)
        .and_return("projectCreate" => {"success" => true, "project" => project_data})
      described_class.call(name: "Migration", teams: ["VIB"])
      expect(client).to have_received(:query).with(a_string_matching(/projectCreate/), anything)
    end

    it "calls projectUpdate when id is present" do
      allow(client).to receive(:query)
        .and_return("projectUpdate" => {"success" => true, "project" => project_data})
      described_class.call(id: "p-1", description: "edited")
      expect(client).to have_received(:query).with(a_string_matching(/projectUpdate/), anything)
    end
  end

  describe "create path" do
    before do
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).and_return("t-1")
      allow(client).to receive(:query)
        .and_return("projectCreate" => {"success" => true, "project" => project_data})
    end

    it "requires name" do
      response = described_class.call(teams: ["VIB"])
      expect(response).to be_error
      expect(response.content.first[:text]).to include("name is required")
    end

    it "requires teams" do
      response = described_class.call(name: "M")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("teams is required")
    end

    it "rejects empty teams array" do
      response = described_class.call(name: "M", teams: [])
      expect(response).to be_error
      expect(response.content.first[:text]).to include("at least one team")
    end

    it "resolves multiple teams to teamIds array" do
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).with(value: "VIB").and_return("t-1")
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).with(value: "BRI").and_return("t-2")
      described_class.call(name: "M", teams: ["VIB", "BRI"])
      expect(client).to have_received(:query).with(
        a_string_matching(/projectCreate/),
        variables: {input: hash_including(name: "M", teamIds: ["t-1", "t-2"])}
      )
    end

    it "resolves status, lead, members, and labels to their *Id forms" do
      allow(LinearToonMcp::Resolvers::ProjectStatus).to receive(:call).with(value: "Planned").and_return("s-1")
      allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "Alice").and_return("u-1")
      allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "Bob").and_return("u-2")
      allow(LinearToonMcp::Resolvers::IssueLabel).to receive(:call_many).with(values: ["bug"]).and_return(["l-1"])

      described_class.call(
        name: "M", teams: ["VIB"],
        status: "Planned", lead: "Alice", members: ["Bob"], labels: ["bug"]
      )

      expect(client).to have_received(:query).with(
        anything,
        variables: {input: hash_including(
          statusId: "s-1", leadId: "u-1", memberIds: ["u-2"], labelIds: ["l-1"]
        )}
      )
    end

    it "links to an initiative as a post-create step" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).with(value: "Q3").and_return("i-1")
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeToProjectCreate/), anything)
        .and_return("initiativeToProjectCreate" => {"success" => true})

      described_class.call(name: "M", teams: ["VIB"], initiative: "Q3")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeToProjectCreate/),
        variables: {input: {projectId: "p-1", initiativeId: "i-1"}}
      )
    end

    it "aggregates initiative link failure as a warning" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).and_return("i-1")
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeToProjectCreate/), anything)
        .and_return("initiativeToProjectCreate" => {"success" => false})

      response = described_class.call(name: "M", teams: ["VIB"], initiative: "Q3")
      expect(response.content.first[:text]).to include("WARNING (project was created)")
      expect(response.content.first[:text]).to include("Failed to link project to initiative")
    end
  end

  describe "update path" do
    before do
      allow(client).to receive(:query)
        .and_return("projectUpdate" => {"success" => true, "project" => project_data})
    end

    it "treats lead: nil as 'remove' (sends leadId: null)" do
      described_class.call(id: "p-1", lead: nil)
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdate/),
        variables: {id: "p-1", input: {leadId: nil}}
      )
    end

    it "rejects initiative arg on update" do
      response = described_class.call(id: "p-1", initiative: "Q3")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Cannot pass `initiative` on update")
      expect(response.content.first[:text]).to include("add_project_to_initiative")
    end
  end

  describe "mutation result handling" do
    it "raises when create reports success: false" do
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).and_return("t-1")
      allow(client).to receive(:query)
        .and_return("projectCreate" => {"success" => false, "project" => nil})
      response = described_class.call(name: "M", teams: ["VIB"])
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Project save failed")
    end

    it "raises when result key is missing" do
      allow(LinearToonMcp::Resolvers::Team).to receive(:call).and_return("t-1")
      allow(client).to receive(:query).and_return({})
      response = described_class.call(name: "M", teams: ["VIB"])
      expect(response).to be_error
      expect(response.content.first[:text]).to include("no result returned")
    end
  end
end
