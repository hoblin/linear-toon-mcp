# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module LinearToonMcp
  # Minimal HTTP client for Linear's GraphQL API and authenticated asset
  # downloads (e.g. images hosted on +uploads.linear.app+).
  class Client
    ENDPOINT = URI("https://api.linear.app/graphql").freeze

    # Hosts that receive the Linear API key as an +Authorization+ header.
    # Other hosts are fetched unauthenticated to avoid leaking the key.
    LINEAR_HOST_SUFFIX = ".linear.app"

    # @param api_key [String] Linear API key (defaults to +LINEAR_API_KEY+ env var)
    # @raise [ArgumentError] when API key is nil or empty
    def initialize(api_key: ENV["LINEAR_API_KEY"])
      raise ArgumentError, "LINEAR_API_KEY is required" if api_key.nil? || api_key.empty?

      @api_key = api_key
    end

    # Execute a GraphQL query against Linear API.
    # @param query_string [String] GraphQL query
    # @param variables [Hash] query variables
    # @return [Hash] the +data+ key from the GraphQL response
    # @raise [Error] on HTTP errors, GraphQL errors, or empty responses
    def query(query_string, variables: {})
      response = post(query_string, variables)

      body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end

      unless response.is_a?(Net::HTTPSuccess)
        messages = body&.dig("errors")&.map { |e| e["message"] }&.join("; ")
        raise Error, "HTTP #{response.code}: #{messages || response.body}"
      end

      raise Error, "Empty response from Linear API" unless body

      if body["errors"]&.any?
        messages = body["errors"].map { |e| e["message"] }.join("; ")
        raise Error, "GraphQL error: #{messages}"
      end

      body["data"]
    end

    # Fetch a raw HTTP resource (used for downloading Linear asset URLs such
    # as images embedded in issue descriptions). The Linear API key is only
    # sent to +*.linear.app+ hosts so the credential never leaks to third
    # parties referenced in user-provided markdown.
    #
    # @param url [String] absolute HTTP(S) URL to download
    # @return [Net::HTTPResponse] the raw successful response
    # @raise [Error] on invalid URLs, unsupported schemes, or HTTP failures
    def fetch(url)
      uri = begin
        URI.parse(url)
      rescue URI::InvalidURIError
        raise Error, "Invalid URL: #{url}"
      end

      raise Error, "Unsupported URL scheme: #{uri.scheme.inspect}" unless %w[http https].include?(uri.scheme)
      raise Error, "URL missing host: #{url}" if uri.host.nil? || uri.host.empty?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = @api_key if linear_host?(uri.host)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      raise Error, "HTTP #{response.code}: failed to fetch #{url}" unless response.is_a?(Net::HTTPSuccess)

      response
    end

    private

    def linear_host?(host)
      host == "linear.app" || host.end_with?(LINEAR_HOST_SUFFIX)
    end

    def post(query_string, variables)
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Content-Type"] = "application/json"
      request["Authorization"] = @api_key
      request.body = JSON.generate(query: query_string, variables:)

      Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true) do |http|
        http.request(request)
      end
    end
  end
end
