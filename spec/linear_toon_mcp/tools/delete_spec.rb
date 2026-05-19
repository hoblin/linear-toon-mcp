# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::Delete do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "conventions derived from class name" do
    it "camelCases the entity from the class name, dropping the Delete prefix" do
      tool = Class.new(described_class) do
        def self.name
          "LinearToonMcp::Tools::DeleteInitiative"
        end
      end
      expect(tool.entity_name).to eq("initiative")
      expect(tool.mutation_name).to eq("initiativeDelete")
      expect(tool.entity_label).to eq("Initiative")
    end
  end

  describe "DSL overrides" do
    it "honors explicit mutation and entity setters" do
      tool = Class.new(described_class) do
        mutation :initiativeToProjectDelete
        entity :initiativeToProject

        def self.name
          "LinearToonMcp::Tools::RemoveProjectFromInitiative"
        end
      end
      expect(tool.mutation_name).to eq("initiativeToProjectDelete")
      expect(tool.entity_name).to eq("initiativeToProject")
    end

    it "honors an explicit label setter" do
      tool = Class.new(described_class) do
        label "Custom Label"

        def self.name
          "LinearToonMcp::Tools::DeleteExample"
        end
      end
      expect(tool.entity_label).to eq("Custom Label")
    end
  end

  describe "#perform" do
    let(:tool) do
      Class.new(described_class) do
        const_set(:MUTATION, "mutation($id: String!) { thingDelete(id: $id) { success entityId } }")

        class << self
          def entity_name
            "thing"
          end

          def mutation_name
            "thingDelete"
          end

          def entity_label
            "Thing"
          end
        end

        def variables(id:)
          {id: id}
        end
      end
    end

    it "submits the mutation and returns success + entityId" do
      allow(client).to receive(:query)
        .and_return("thingDelete" => {"success" => true, "entityId" => "1"})
      expect(tool.new.perform(id: "1")).to eq("success" => true, "entityId" => "1")
    end

    it "raises when the mutation payload is missing" do
      allow(client).to receive(:query).and_return({})
      expect { tool.new.perform(id: "1") }
        .to raise_error(LinearToonMcp::Error, /Thing deletion failed: no result returned/)
    end

    it "raises when success is false" do
      allow(client).to receive(:query)
        .and_return("thingDelete" => {"success" => false, "entityId" => nil})
      expect { tool.new.perform(id: "1") }
        .to raise_error(LinearToonMcp::Error, /\AThing deletion failed\z/)
    end
  end
end
