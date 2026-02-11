# frozen_string_literal: true

RSpec.describe LinearToonMcp::Tools::Echo do
  describe ".call" do
    subject(:response) { described_class.call(text:) }

    let(:text) { "hello world" }

    it "returns the input text as-is" do
      expect(response).to be_a(MCP::Tool::Response)
      expect(response.content).to eq([{type: "text", text:}])
    end
  end
end
