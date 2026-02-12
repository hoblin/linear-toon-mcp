# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module LinearToonMcp
  # Minimal HTTP client for Linear's GraphQL API.
  class Client
    ENDPOINT = URI("https://api.linear.app/graphql").freeze

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

    private

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
