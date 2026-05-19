# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::Update do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "conventions derived from class name" do
    it "camelCases the entity from the class name, dropping the Update prefix" do
      expect(LinearToonMcp::Tools::UpdateIssue.entity_name).to eq("issue")
    end

    it "appends Update to the entity for the mutation field" do
      expect(LinearToonMcp::Tools::UpdateIssue.mutation_name).to eq("issueUpdate")
    end

    it "uses the stripped class name as the entity label" do
      expect(LinearToonMcp::Tools::UpdateIssue.entity_label).to eq("Issue")
    end
  end

  describe "#perform" do
    let(:tool) do
      Class.new(described_class) do
        const_set(:MUTATION, "mutation { thingUpdate { success thing { id } } }")

        class << self
          def entity_name
            "thing"
          end

          def mutation_name
            "thingUpdate"
          end

          def entity_label
            "Thing"
          end
        end

        def variables(id:, **)
          {id:, input: {}}
        end
      end
    end

    it "submits the mutation and returns the updated entity" do
      allow(client).to receive(:query)
        .and_return("thingUpdate" => {"success" => true, "thing" => {"id" => "1"}})
      expect(tool.new.perform(id: "1")).to eq("id" => "1")
    end

    it "raises when the mutation payload is missing" do
      allow(client).to receive(:query).and_return({})
      expect { tool.new.perform(id: "1") }
        .to raise_error(LinearToonMcp::Error, /Thing update failed: no result returned/)
    end

    it "raises when success is false" do
      allow(client).to receive(:query)
        .and_return("thingUpdate" => {"success" => false, "thing" => nil})
      expect { tool.new.perform(id: "1") }
        .to raise_error(LinearToonMcp::Error, /\AThing update failed\z/)
    end
  end
end
