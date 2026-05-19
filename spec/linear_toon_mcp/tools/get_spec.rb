# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::Get do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  describe "conventions derived from class name" do
    it "camelCases the leading word, dropping the Get prefix" do
      expect(LinearToonMcp::Tools::GetIssue.entity_name).to eq("issue")
      expect(LinearToonMcp::Tools::GetProject.entity_name).to eq("project")
    end

    it "uses the stripped class name as the not-found label" do
      expect(LinearToonMcp::Tools::GetIssue.entity_label).to eq("Issue")
      expect(LinearToonMcp::Tools::GetProject.entity_label).to eq("Project")
    end
  end

  describe "#perform" do
    let(:tool) do
      Class.new(described_class) do
        const_set(:QUERY, "query($id: String!) { thing(id: $id) { id } }")

        class << self
          def entity_name
            "thing"
          end

          def entity_label
            "Thing"
          end
        end
      end
    end

    it "queries with id and returns the entity" do
      allow(client).to receive(:query).and_return("thing" => {"id" => "1"})
      expect(tool.new.perform(id: "1")).to eq("id" => "1")
    end

    it "raises a labeled not-found error when the entity is nil" do
      allow(client).to receive(:query).and_return("thing" => nil)
      expect { tool.new.perform(id: "missing") }
        .to raise_error(LinearToonMcp::Error, /\AThing not found: missing\z/)
    end
  end
end
