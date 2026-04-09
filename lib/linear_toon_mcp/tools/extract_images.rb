# frozen_string_literal: true

require "base64"

module LinearToonMcp
  module Tools
    # Extract and fetch images referenced in markdown content such as Linear
    # issue descriptions or comments. Parses both Markdown image syntax and
    # HTML +<img>+ tags, downloads each unique URL via the Linear client, and
    # returns the images as MCP image content so an LLM can view them inline.
    #
    # A short text summary is prepended to the response listing how many
    # images were fetched successfully and any per-URL failures.
    class ExtractImages < MCP::Tool
      description "Extract and fetch images referenced in markdown content"

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true
      )

      input_schema(
        properties: {
          markdown: {
            type: "string",
            description: "Markdown content containing image references"
          }
        },
        required: ["markdown"],
        additionalProperties: false
      )

      SUPPORTED_MIME_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze

      EXTENSION_MIME_TYPES = {
        ".png" => "image/png",
        ".jpg" => "image/jpeg",
        ".jpeg" => "image/jpeg",
        ".gif" => "image/gif",
        ".webp" => "image/webp"
      }.freeze

      MARKDOWN_IMAGE_REGEX = /!\[[^\]]*\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)/
      HTML_IMAGE_REGEX = /<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']/i

      class << self
        # @param markdown [String] markdown content that may reference images
        # @param server_context [Hash, nil] must contain +:client+ key with a {Client}
        # @return [MCP::Tool::Response] text summary followed by fetched images,
        #   or an error response when the client is missing
        def call(markdown:, server_context: nil)
          client = server_context&.dig(:client) or raise Error, "client missing from server_context"

          urls = extract_urls(markdown)
          return MCP::Tool::Response.new([{type: "text", text: "No images found in markdown"}]) if urls.empty?

          images, failures = fetch_all(client, urls)

          content = [{type: "text", text: build_summary(urls.size, images.size, failures)}]
          content.concat(images)
          MCP::Tool::Response.new(content)
        rescue Error => e
          MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
        end

        private

        # Extract unique image URLs from Markdown and HTML image tags.
        # Preserves the order of first appearance.
        def extract_urls(markdown)
          return [] if markdown.nil? || markdown.empty?

          urls = []
          markdown.scan(MARKDOWN_IMAGE_REGEX) { |match| urls << match[0] }
          markdown.scan(HTML_IMAGE_REGEX) { |match| urls << match[0] }
          urls.uniq
        end

        # Fetch every URL and partition the results into image content items
        # and failure messages keyed by URL.
        def fetch_all(client, urls)
          images = []
          failures = []

          urls.each do |url|
            images << fetch_image(client, url)
          rescue Error => e
            failures << "#{url}: #{e.message}"
          end

          [images, failures]
        end

        # Fetch a single image and build an MCP image content hash.
        # @raise [Error] when the MIME type is not supported by MCP image content
        def fetch_image(client, url)
          response = client.fetch(url)
          mime_type = resolve_mime_type(response, url)
          raise Error, "unsupported content type: #{mime_type || "unknown"}" unless SUPPORTED_MIME_TYPES.include?(mime_type)

          {
            type: "image",
            data: Base64.strict_encode64(response.body.to_s),
            mimeType: mime_type
          }
        end

        # Resolve a MIME type from the response Content-Type header, falling
        # back to the URL's file extension when the header is missing or
        # uninformative.
        def resolve_mime_type(response, url)
          header = response["Content-Type"]&.split(";")&.first&.strip&.downcase
          return header if header && SUPPORTED_MIME_TYPES.include?(header)

          ext = File.extname(URI.parse(url).path).downcase
          EXTENSION_MIME_TYPES[ext] || header
        rescue URI::InvalidURIError
          header
        end

        def build_summary(total, fetched, failures)
          summary = "Fetched #{fetched} of #{total} images"
          summary += "\nFailures:\n- #{failures.join("\n- ")}" if failures.any?
          summary
        end
      end
    end
  end
end
