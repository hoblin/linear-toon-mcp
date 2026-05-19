# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveStatusUpdate do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:project_update) { {"id" => "pu-1", "body" => "ok"} }
  let(:initiative_update) { {"id" => "iu-1", "body" => "ok"} }

  before { LinearToonMcp.client = client }

  describe "create — XOR parent validation" do
    it "rejects calls with neither project nor initiative when id is absent" do
      response = described_class.call(body: "hi")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `project` or `initiative`")
    end

    it "rejects calls with both project and initiative when id is absent" do
      response = described_class.call(project: "P", initiative: "I", body: "hi")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("exactly one of `project` or `initiative`")
    end
  end

  describe "create dispatch" do
    it "calls projectUpdateCreate when project is set" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call).with(value: "P").and_return("p-1")
      allow(client).to receive(:query)
        .and_return("projectUpdateCreate" => {"success" => true, "projectUpdate" => project_update})

      described_class.call(project: "P", body: "hi", health: "onTrack")
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdateCreate/),
        variables: {input: {body: "hi", health: "onTrack", projectId: "p-1"}}
      )
    end

    it "calls initiativeUpdateCreate when initiative is set" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call).with(value: "Q1").and_return("i-1")
      allow(client).to receive(:query)
        .and_return("initiativeUpdateCreate" => {"success" => true, "initiativeUpdate" => initiative_update})

      described_class.call(initiative: "Q1", body: "hi")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdateCreate/),
        variables: {input: {body: "hi", initiativeId: "i-1"}}
      )
    end
  end

  describe "update dispatch (parent inferred from id)" do
    it "calls projectUpdateUpdate when the existing record belongs to a project" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => {"id" => "pu-1", "project" => {"id" => "p-1", "name" => "P"}})
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdateUpdate/), anything)
        .and_return("projectUpdateUpdate" => {"success" => true, "projectUpdate" => project_update})

      described_class.call(id: "pu-1", body: "edited")
      expect(client).to have_received(:query).with(
        a_string_matching(/projectUpdateUpdate/),
        variables: {id: "pu-1", input: {body: "edited"}}
      )
    end

    it "calls initiativeUpdateUpdate when the existing record belongs to an initiative" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => {"id" => "iu-1", "initiative" => {"id" => "i-1", "name" => "I"}})
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdateUpdate/), anything)
        .and_return("initiativeUpdateUpdate" => {"success" => true, "initiativeUpdate" => initiative_update})

      described_class.call(id: "iu-1", body: "edited")
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdateUpdate/),
        variables: {id: "iu-1", input: {body: "edited"}}
      )
    end

    it "rejects calls that pass a parent alongside id" do
      response = described_class.call(id: "pu-1", initiative: "wrong", body: "edited")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Cannot pass `initiative` on update")
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

    it "raises when create reports success: false" do
      allow(client).to receive(:query)
        .and_return("projectUpdateCreate" => {"success" => false, "projectUpdate" => nil})
      response = described_class.call(project: "P", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update save failed")
    end

    it "raises when create result key is missing" do
      allow(client).to receive(:query).and_return({})
      response = described_class.call(project: "P", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("no result returned")
    end

    it "raises when the update mutation reports success: false" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => {"id" => "pu-1", "project" => {"id" => "p-1", "name" => "P"}})
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdateUpdate/), anything)
        .and_return("projectUpdateUpdate" => {"success" => false, "projectUpdate" => nil})
      response = described_class.call(id: "pu-1", body: "edit")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update save failed")
    end

    it "raises when the update response is missing the mutation key" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => {"id" => "pu-1", "project" => {"id" => "p-1", "name" => "P"}})
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdateUpdate/), anything)
        .and_return({})
      response = described_class.call(id: "pu-1", body: "edit")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update save failed: no result returned")
    end
  end

  describe "resolver errors" do
    it "surfaces project resolution errors on create" do
      allow(LinearToonMcp::Resolvers::Project).to receive(:call)
        .and_raise(LinearToonMcp::Error, "Project not found: Missing")
      response = described_class.call(project: "Missing", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Project not found")
    end
  end

  describe "update lookup failure" do
    it "surfaces a clear error when the id doesn't match any status update" do
      allow(client).to receive(:query)
        .with(a_string_matching(/projectUpdate\(id:/), anything)
        .and_return("projectUpdate" => nil)
      allow(client).to receive(:query)
        .with(a_string_matching(/initiativeUpdate\(id:/), anything)
        .and_return("initiativeUpdate" => nil)

      response = described_class.call(id: "missing", body: "x")
      expect(response).to be_error
      expect(response.content.first[:text]).to include("Status update not found")
    end
  end
end
