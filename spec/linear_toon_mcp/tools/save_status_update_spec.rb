# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveStatusUpdate do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:project_update) { {"id" => "pu-1", "body" => "ok"} }
  let(:initiative_update) { {"id" => "iu-1", "body" => "ok"} }

  before { LinearToonMcp.client = client }

  describe "XOR parent validation" do
    it "rejects calls with neither project: nor initiative:" do
      response = described_class.call(body: "hi")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `project` or `initiative`")
    end

    it "rejects calls with both project: and initiative:" do
      response = described_class.call(project: "P", initiative: "I", body: "hi")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `project` or `initiative`")
    end
  end

  describe "dispatch" do
    it "calls projectUpdateCreate when project is set and id is absent" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "P").and_return("p-1")
      allow(client).to receive(:query)
        .and_return("projectUpdateCreate" => {"success" => true, "projectUpdate" => project_update})

      described_class.call(project: "P", body: "hi", health: "onTrack")
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdateCreate/),
        variables: {input: {body: "hi", health: "onTrack", projectId: "p-1"}}
      )
    end

    it "calls initiativeUpdateCreate when initiative is set and id is absent" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).with(value: "Q1").and_return("i-1")
      allow(client).to receive(:query)
        .and_return("initiativeUpdateCreate" => {"success" => true, "initiativeUpdate" => initiative_update})

      described_class.call(initiative: "Q1", body: "hi")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdateCreate/),
        variables: {input: {body: "hi", initiativeId: "i-1"}}
      )
    end

    it "calls projectUpdateUpdate when id and project are present" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).and_return("p-1")
      allow(client).to receive(:query)
        .and_return("projectUpdateUpdate" => {"success" => true, "projectUpdate" => project_update})

      described_class.call(id: "pu-1", project: "P", body: "edited")
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdateUpdate/),
        variables: {id: "pu-1", input: {body: "edited"}}
      )
    end

    it "calls initiativeUpdateUpdate when id and initiative are present" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).and_return("i-1")
      allow(client).to receive(:query)
        .and_return("initiativeUpdateUpdate" => {"success" => true, "initiativeUpdate" => initiative_update})

      described_class.call(id: "iu-1", initiative: "Q1", body: "edited")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdateUpdate/),
        variables: {id: "iu-1", input: {body: "edited"}}
      )
    end
  end

  describe "input building" do
    before do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).and_return("p-1")
      allow(client).to receive(:query)
        .and_return("projectUpdateCreate" => {"success" => true, "projectUpdate" => project_update})
    end

    it "passes body, health, and isDiffHidden through to the input" do
      described_class.call(project: "P", body: "b", health: "atRisk", isDiffHidden: true)
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {body: "b", health: "atRisk", isDiffHidden: true, projectId: "p-1"}}
      )
    end

    it "omits fields the caller didn't pass" do
      described_class.call(project: "P", body: "only body")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {body: "only body", projectId: "p-1"}}
      )
    end
  end

  describe "mutation result handling" do
    before do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).and_return("p-1")
    end

    it "raises when success: false" do
      allow(client).to receive(:query)
        .and_return("projectUpdateCreate" => {"success" => false, "projectUpdate" => nil})
      response = described_class.call(project: "P", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update creation failed")
    end

    it "raises when result key is missing" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(project: "P", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("no result returned")
    end

    it "raises when the update mutation reports success: false" do
      allow(client).to receive(:query)
        .and_return("projectUpdateUpdate" => {"success" => false, "projectUpdate" => nil})
      response = described_class.call(id: "pu-1", project: "P", body: "edit")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update update failed")
    end

    it "raises when the update response is missing the mutation key" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(id: "pu-1", project: "P", body: "edit")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update update failed: no result returned")
    end
  end

  describe "resolver errors" do
    it "surfaces project resolution errors" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call)
        .and_raise(LinearToonMcp::Error, "Project not found: Missing")
      response = described_class.call(project: "Missing", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Project not found")
    end
  end
end
