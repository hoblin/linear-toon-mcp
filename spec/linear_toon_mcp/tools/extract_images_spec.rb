# frozen_string_literal: true

require "base64"

RSpec.describe LinearToonMcp::Tools::ExtractImages do
  describe ".call" do
    subject(:response) { described_class.call(markdown:, server_context: {client:}) }

    let(:client) { instance_double(LinearToonMcp::Client) }
    let(:markdown) { "no images here" }

    def mock_http_response(body:, content_type: "image/png")
      response = instance_double(Net::HTTPOK, body: body.b)
      allow(response).to receive(:[]).with("Content-Type").and_return(content_type)
      response
    end

    context "when the markdown contains no images" do
      it "returns a single text block explaining no images were found" do
        expect(response).to be_a(MCP::Tool::Response)
        expect(response).not_to be_error
        expect(response.content.length).to eq(1)
        expect(response.content.first).to include(type: "text")
        expect(response.content.first[:text]).to include("No images")
      end

      it "does not call the client" do
        response
        expect(client).not_to have_received(:fetch) if client.respond_to?(:fetch)
      end
    end

    context "when the markdown contains a single markdown image" do
      let(:markdown) { "some text ![screenshot](https://uploads.linear.app/abc/screenshot.png) more text" }
      let(:png_bytes) { "\x89PNG\r\n\x1a\nFAKE" }

      before do
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/abc/screenshot.png")
          .and_return(mock_http_response(body: png_bytes))
      end

      it "returns a summary followed by an image content block" do
        expect(response).not_to be_error
        expect(response.content.length).to eq(2)
        expect(response.content.first[:text]).to include("Fetched 1 of 1")
        expect(response.content.last).to eq(
          type: "image",
          data: Base64.strict_encode64(png_bytes.b),
          mimeType: "image/png"
        )
      end
    end

    context "when the markdown contains an HTML <img> tag" do
      let(:markdown) { %(<img src="https://uploads.linear.app/x.jpg" alt="x" />) }
      let(:jpg_bytes) { "JPGBINARY" }

      before do
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/x.jpg")
          .and_return(mock_http_response(body: jpg_bytes, content_type: "image/jpeg"))
      end

      it "fetches the image and returns it as jpeg content" do
        expect(response.content.last).to include(type: "image", mimeType: "image/jpeg")
        expect(response.content.last[:data]).to eq(Base64.strict_encode64(jpg_bytes.b))
      end
    end

    context "when the markdown contains a markdown image with a title" do
      let(:markdown) { %(![alt](https://uploads.linear.app/t.png "title text")) }

      before do
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/t.png")
          .and_return(mock_http_response(body: "PNGDATA"))
      end

      it "parses the URL without the trailing title" do
        response
        expect(client).to have_received(:fetch).with("https://uploads.linear.app/t.png")
      end
    end

    context "when the same image URL appears multiple times" do
      let(:markdown) do
        <<~MD
          ![one](https://uploads.linear.app/dup.png)
          <img src="https://uploads.linear.app/dup.png" />
          ![two](https://uploads.linear.app/dup.png)
        MD
      end

      before do
        allow(client).to receive(:fetch).and_return(mock_http_response(body: "DUP"))
      end

      it "fetches each unique URL exactly once" do
        response
        expect(client).to have_received(:fetch).with("https://uploads.linear.app/dup.png").once
      end

      it "returns a single image content block" do
        expect(response.content.count { |c| c[:type] == "image" }).to eq(1)
      end
    end

    context "when the markdown contains both markdown and HTML images" do
      let(:markdown) do
        <<~MD
          ![a](https://uploads.linear.app/a.png)
          <img src="https://uploads.linear.app/b.gif" />
        MD
      end

      before do
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/a.png")
          .and_return(mock_http_response(body: "APNG", content_type: "image/png"))
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/b.gif")
          .and_return(mock_http_response(body: "BGIF", content_type: "image/gif"))
      end

      it "returns both images and a summary counting both" do
        expect(response.content.first[:text]).to include("Fetched 2 of 2")
        mime_types = response.content.select { |c| c[:type] == "image" }.map { |c| c[:mimeType] }
        expect(mime_types).to contain_exactly("image/png", "image/gif")
      end
    end

    context "when fetching an image raises a client error" do
      let(:markdown) { "![bad](https://uploads.linear.app/bad.png)" }

      before do
        allow(client).to receive(:fetch).and_raise(LinearToonMcp::Error, "HTTP 404: failed to fetch")
      end

      it "reports the failure in the summary and does not raise" do
        expect(response).not_to be_error
        expect(response.content.first[:text]).to include("Fetched 0 of 1")
        expect(response.content.first[:text]).to include("HTTP 404")
      end

      it "does not include a broken image content block" do
        expect(response.content.any? { |c| c[:type] == "image" }).to be(false)
      end
    end

    context "when one image succeeds and another fails" do
      let(:markdown) do
        <<~MD
          ![good](https://uploads.linear.app/good.png)
          ![bad](https://uploads.linear.app/bad.png)
        MD
      end

      before do
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/good.png")
          .and_return(mock_http_response(body: "GOOD"))
        allow(client).to receive(:fetch)
          .with("https://uploads.linear.app/bad.png")
          .and_raise(LinearToonMcp::Error, "HTTP 500: failed to fetch")
      end

      it "includes the successful image and reports the failed URL" do
        expect(response).not_to be_error
        expect(response.content.first[:text]).to include("Fetched 1 of 2")
        expect(response.content.first[:text]).to include("https://uploads.linear.app/bad.png")
        expect(response.content.count { |c| c[:type] == "image" }).to eq(1)
      end
    end

    context "when the image has an unsupported MIME type" do
      let(:markdown) { "![svg](https://uploads.linear.app/vector.svg)" }

      before do
        allow(client).to receive(:fetch)
          .and_return(mock_http_response(body: "<svg></svg>", content_type: "image/svg+xml"))
      end

      it "reports the unsupported content type in the summary" do
        expect(response.content.first[:text]).to include("unsupported")
      end
    end

    context "when Content-Type is missing but the URL has a known extension" do
      let(:markdown) { "![](https://uploads.linear.app/photo.webp)" }

      before do
        allow(client).to receive(:fetch)
          .and_return(mock_http_response(body: "WEBPDATA", content_type: nil))
      end

      it "falls back to the extension for MIME type detection" do
        expect(response.content.last).to include(type: "image", mimeType: "image/webp")
      end
    end

    context "when fetching an image raises a network-level exception" do
      let(:markdown) { "![dns](https://uploads.linear.app/dns-fail.png)" }

      before do
        allow(client).to receive(:fetch).and_raise(SocketError, "getaddrinfo: Name or service not known")
      end

      it "collects the error as a per-image failure instead of crashing" do
        expect(response).not_to be_error
        expect(response.content.first[:text]).to include("Fetched 0 of 1")
        expect(response.content.first[:text]).to include("SocketError")
      end
    end

    context "when fetching an image raises a timeout" do
      let(:markdown) { "![slow](https://uploads.linear.app/slow.png)" }

      before do
        allow(client).to receive(:fetch).and_raise(Net::OpenTimeout, "execution expired")
      end

      it "collects the timeout as a per-image failure instead of crashing" do
        expect(response).not_to be_error
        expect(response.content.first[:text]).to include("Fetched 0 of 1")
        expect(response.content.first[:text]).to include("Net::OpenTimeout")
      end
    end

    context "when server_context has no client" do
      subject(:response) { described_class.call(markdown: "![](x.png)", server_context: {}) }

      it "returns an error response" do
        expect(response).to be_a(MCP::Tool::Response).and be_error
        expect(response.content.first[:text]).to include("client missing")
      end
    end

    context "when markdown is an empty string" do
      let(:markdown) { "" }

      it "returns the no-images message" do
        expect(response).not_to be_error
        expect(response.content.first[:text]).to include("No images")
      end
    end
  end
end
