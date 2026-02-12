# frozen_string_literal: true

RSpec.describe LinearToonMcp::Client do
  describe "#initialize" do
    it "raises when API key is missing" do
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, /LINEAR_API_KEY is required/)
    end

    it "raises when API key is empty" do
      expect { described_class.new(api_key: "") }.to raise_error(ArgumentError, /LINEAR_API_KEY is required/)
    end
  end

  describe "#query" do
    subject(:client) { described_class.new(api_key: "test_key") }

    let(:success_body) { JSON.generate(data: {viewer: {id: "1", name: "Test"}}) }
    let(:graphql_error_body) { JSON.generate(data: nil, errors: [{message: "Not found"}]) }

    it "returns parsed data on success" do
      stub_request(success_body)

      result = client.query("{ viewer { id name } }")
      expect(result).to eq("viewer" => {"id" => "1", "name" => "Test"})
    end

    it "raises on HTTP error" do
      stub_request("Unauthorized", code: "401", message: "Unauthorized")

      expect { client.query("{ viewer { id } }") }.to raise_error(LinearToonMcp::Error, /HTTP 401/)
    end

    it "raises on GraphQL error" do
      stub_request(graphql_error_body)

      expect { client.query("{ issue(id: \"bad\") { id } }") }.to raise_error(LinearToonMcp::Error, /GraphQL error: Not found/)
    end

    private

    def stub_request(body, code: "200", message: "OK")
      http_response = Net::HTTPResponse::CODE_TO_OBJ[code].new("1.1", code, message)
      allow(http_response).to receive(:body).and_return(body)
      allow(Net::HTTP).to receive(:start).and_return(http_response)
    end
  end
end
