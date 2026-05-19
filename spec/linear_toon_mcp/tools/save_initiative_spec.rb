# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::SaveInitiative do
  let(:client) { instance_double(LinearToonMcp::Client) }
  let(:initiative_data) { {"id" => "init-1", "name" => "Q1 Roadmap"} }

  before { LinearToonMcp.client = client }

  describe "dispatch" do
    it "submits initiativeCreate when id is absent" do
      allow(client).to receive(:query)
        .and_return("initiativeCreate" => {"success" => true, "initiative" => initiative_data})
      described_class.call(name: "Q1 Roadmap")
      expect(client).to have_received(:query).with(a_string_matching(/initiativeCreate/), anything)
    end

    it "submits initiativeUpdate when id is present" do
      allow(client).to receive(:query)
        .and_return("initiativeUpdate" => {"success" => true, "initiative" => initiative_data})
      described_class.call(id: "init-1", description: "Updated")
      expect(client).to have_received(:query).with(a_string_matching(/initiativeUpdate/), anything)
    end
  end

  describe "create" do
    before do
      allow(client).to receive(:query)
        .and_return("initiativeCreate" => {"success" => true, "initiative" => initiative_data})
    end

    it "rejects create without name" do
      response = described_class.call(description: "no name")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("name is required")
    end

    it "raises when the mutation reports success: false" do
      allow(client).to receive(:query)
        .and_return("initiativeCreate" => {"success" => false, "initiative" => nil})
      response = described_class.call(name: "Q1")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Initiative creation failed")
    end
  end

  describe "update" do
    before do
      allow(client).to receive(:query)
        .and_return("initiativeUpdate" => {"success" => true, "initiative" => initiative_data})
    end

    it "passes id and partial input to the mutation" do
      described_class.call(id: "init-1", description: "Updated")
      expect(client).to have_received(:query).with(
        anything,
        variables: {id: "init-1", input: {description: "Updated"}}
      )
    end

    it "raises when the mutation reports success: false" do
      allow(client).to receive(:query)
        .and_return("initiativeUpdate" => {"success" => false, "initiative" => nil})
      response = described_class.call(id: "init-1", description: "Updated")
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to include("Initiative update failed")
    end
  end

  describe "input building" do
    before do
      allow(client).to receive(:query)
        .and_return("initiativeCreate" => {"success" => true, "initiative" => initiative_data})
    end

    it "passes plain fields straight through" do
      described_class.call(
        name: "Q1", description: "short", content: "## md",
        color: "#5E6AD2", status: "Active", targetDate: "2026-03-31"
      )
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {
          name: "Q1", description: "short", content: "## md",
          color: "#5E6AD2", status: "Active", targetDate: "2026-03-31"
        }}
      )
    end

    it "resolves owner names via Resolvers::User and renames to ownerId" do
      allow(LinearToonMcp::Resolvers::User).to receive(:call).with(value: "Alice").and_return("u1")
      described_class.call(name: "Q1", owner: "Alice")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {name: "Q1", ownerId: "u1"}}
      )
    end

    it "passes ownerId: nil to remove the owner" do
      described_class.call(id: "init-1", owner: nil)
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdate/),
        variables: {id: "init-1", input: {ownerId: nil}}
      )
    end

    it "resolves parentInitiative names via Resolvers::Initiative" do
      allow(LinearToonMcp::Resolvers::Initiative).to receive(:call)
        .with(value: "Yearly").and_return("p1")
      described_class.call(name: "Q1", parentInitiative: "Yearly")
      expect(client).to have_received(:query).with(
        anything,
        variables: {input: {name: "Q1", parentInitiativeId: "p1"}}
      )
    end

    it "passes parentInitiativeId: nil to detach the parent" do
      described_class.call(id: "init-1", parentInitiative: nil)
      expect(client).to have_received(:query).with(
        a_string_matching(/initiativeUpdate/),
        variables: {id: "init-1", input: {parentInitiativeId: nil}}
      )
    end
  end
end
