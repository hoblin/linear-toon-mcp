# frozen_string_literal: true

RSpec.describe LinearToonMcp::Client do
  describe "#initialize" do
    it "raises when API key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, /LINEAR_API_KEY is required/)
    end

    it "raises when API key is empty" do
      expect { described_class.new(api_key: "") }.to raise_error(ArgumentError, /LINEAR_API_KEY is required/)
    end

    it "accepts a valid API key" do
      expect { described_class.new(api_key: "lin_api_test") }.not_to raise_error
    end

    it "reads API key from LINEAR_API_KEY env var" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("LINEAR_API_KEY").and_return("lin_env_key")

      expect { described_class.new }.not_to raise_error
    end
  end

  describe "#query" do
    subject(:client) { described_class.new(api_key: "test_key") }

    context "when the API returns a successful JSON response" do
      it "returns the parsed data hash" do
        stub_http(JSON.generate(data: {viewer: {id: "1"}}))

        expect(client.query("{ viewer { id } }")).to eq("viewer" => {"id" => "1"})
      end
    end

    context "when the API returns HTTP error with GraphQL errors in body" do
      it "raises with the GraphQL error messages" do
        stub_http(JSON.generate(errors: [{message: "Cannot query field \"foo\""}]), code: "400")

        expect { client.query("{ foo }") }.to raise_error(LinearToonMcp::Error, /HTTP 400.*Cannot query field/)
      end
    end

    context "when the API returns HTTP error with non-JSON body" do
      it "raises with the raw response body" do
        stub_http("Unauthorized", code: "401")

        expect { client.query("{ viewer { id } }") }.to raise_error(LinearToonMcp::Error, /HTTP 401.*Unauthorized/)
      end
    end

    context "when the API returns 200 with GraphQL errors" do
      it "raises with the error messages" do
        stub_http(JSON.generate(data: nil, errors: [{message: "Not found"}]))

        expect { client.query("{ issue(id: \"x\") { id } }") }.to raise_error(LinearToonMcp::Error, /GraphQL error: Not found/)
      end
    end

    context "when the API returns 200 with empty body" do
      it "raises empty response error" do
        stub_http("")

        expect { client.query("{ viewer { id } }") }.to raise_error(LinearToonMcp::Error, /Empty response/)
      end
    end

    private

    def stub_http(body, code: "200")
      response = Net::HTTPResponse::CODE_TO_OBJ[code].new("1.1", code, "")
      allow(response).to receive(:body).and_return(body)
      allow(Net::HTTP).to receive(:start).and_return(response)
    end
  end

  describe "#fetch" do
    subject(:client) { described_class.new(api_key: "test_key") }

    let(:captured_request) { {} }

    def stub_fetch(body: "BINARY", code: "200")
      response = Net::HTTPResponse::CODE_TO_OBJ[code].new("1.1", code, "")
      allow(response).to receive(:body).and_return(body)
      allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
        http = instance_double(Net::HTTP)
        allow(http).to receive(:request) do |request|
          captured_request[:authorization] = request["Authorization"]
          captured_request[:method] = request.method
          captured_request[:uri] = request.uri
          response
        end
        block.call(http)
      end
      response
    end

    it "returns the HTTP response on success" do
      stub_fetch(body: "IMAGE_BYTES")

      response = client.fetch("https://uploads.linear.app/abc.png")

      expect(response.body).to eq("IMAGE_BYTES")
    end

    it "sends the Linear API key for uploads.linear.app hosts" do
      stub_fetch

      client.fetch("https://uploads.linear.app/abc.png")

      expect(captured_request[:authorization]).to eq("test_key")
    end

    it "sends the Linear API key for the linear.app apex host" do
      stub_fetch

      client.fetch("https://linear.app/foo.png")

      expect(captured_request[:authorization]).to eq("test_key")
    end

    it "does not send the Linear API key to third-party hosts" do
      stub_fetch

      client.fetch("https://example.com/image.png")

      expect(captured_request[:authorization]).to be_nil
    end

    it "does not treat a host ending in linear.app within a larger domain as Linear" do
      stub_fetch

      client.fetch("https://evil-linear.app/image.png")

      expect(captured_request[:authorization]).to be_nil
    end

    it "raises when the response is not successful" do
      stub_fetch(body: "Not Found", code: "404")

      expect { client.fetch("https://uploads.linear.app/missing.png") }
        .to raise_error(LinearToonMcp::Error, /HTTP 404/)
    end

    it "raises on unsupported URL schemes" do
      expect { client.fetch("file:///etc/passwd") }
        .to raise_error(LinearToonMcp::Error, /Unsupported URL scheme/)
    end

    it "raises when the URL is missing a host" do
      expect { client.fetch("https:///no-host") }
        .to raise_error(LinearToonMcp::Error, /URL missing host/)
    end

    it "raises on a malformed URL" do
      expect { client.fetch("http://[::bad uri") }
        .to raise_error(LinearToonMcp::Error, /Invalid URL/)
    end
  end
end
