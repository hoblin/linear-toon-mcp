# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::Base do
  let(:client) { instance_double(LinearToonMcp::Client) }

  before { LinearToonMcp.client = client }

  let(:tool) do
    Class.new(described_class) do
      def perform(value: "ok")
        {"value" => value}
      end
    end
  end

  describe ".call" do
    it "instantiates the tool, runs perform, and TOON-encodes the result" do
      response = tool.call(value: "hello")
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content.first[:type]).to eq("text")
      expect(response.content.first[:text]).to include("hello")
    end

    it "ignores server_context (the client comes from LinearToonMcp.client)" do
      response = tool.call(server_context: {other: :thing}, value: "ok")
      expect(response).to be_a(MCP::Tool::Response)
    end

    it "returns an error response when perform raises Error" do
      failing = Class.new(described_class) do
        def perform(**)
          raise LinearToonMcp::Error, "boom"
        end
      end
      response = failing.call
      expect(response).to be_a(MCP::Tool::Response).and be_error
      expect(response.content.first[:text]).to eq("boom")
    end
  end

  describe "#perform" do
    it "raises NotImplementedError by default" do
      expect { described_class.new.perform }.to raise_error(NotImplementedError)
    end
  end

  describe "#client" do
    it "returns the active LinearToonMcp client" do
      expect(tool.new.send(:client)).to eq(client)
    end
  end
end
