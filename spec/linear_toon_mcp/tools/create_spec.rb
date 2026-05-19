# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::Create do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "conventions derived from class name" do
    it "camelCases the entity from the class name, dropping the Create prefix" do
      tool = Class.new(described_class) do
        def self.name
          "LinearToonMcp::Tools::CreateThing"
        end
      end
      expect(tool.entity_name).to eq("thing")
    end

    it "appends Create to the entity for the mutation field" do
      tool = Class.new(described_class) do
        def self.name
          "LinearToonMcp::Tools::CreateThing"
        end
      end
      expect(tool.mutation_name).to eq("thingCreate")
    end

    it "uses the stripped class name as the entity label" do
      tool = Class.new(described_class) do
        def self.name
          "LinearToonMcp::Tools::CreateThing"
        end
      end
      expect(tool.entity_label).to eq("Thing")
    end
  end

  describe "#perform" do
    let(:tool) do
      Class.new(described_class) do
        const_set(:MUTATION, "mutation { thingCreate { success thing { id } } }")

        class << self
          def entity_name
            "thing"
          end

          def mutation_name
            "thingCreate"
          end

          def entity_label
            "Thing"
          end
        end

        def variables(**)
          {}
        end
      end
    end

    it "submits the mutation and returns the created entity" do
      allow(client).to receive(:query)
        .and_return("thingCreate" => {"success" => true, "thing" => {"id" => "1"}})
      expect(tool.new.perform).to eq("id" => "1")
    end

    it "raises when the mutation payload is missing" do
      allow(client).to receive(:query).and_return({})
      expect { tool.new.perform }
        .to raise_error(LinearToonMcp::Error, /Thing creation failed: no result returned/)
    end

    it "raises when success is false" do
      allow(client).to receive(:query)
        .and_return("thingCreate" => {"success" => false, "thing" => nil})
      expect { tool.new.perform }
        .to raise_error(LinearToonMcp::Error, /\AThing creation failed\z/)
    end
  end
end
