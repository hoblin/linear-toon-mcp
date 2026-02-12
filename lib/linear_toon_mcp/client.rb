# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module LinearToonMcp
  class Client
    ENDPOINT = URI("https://api.linear.app/graphql").freeze

    def initialize(api_key: ENV["LINEAR_API_KEY"])
      raise ArgumentError, "LINEAR_API_KEY is required" if api_key.nil? || api_key.empty?

      @api_key = api_key
    end

    def query(query_string, variables: {})
      response = post(query_string, variables)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "HTTP #{response.code}: #{response.message}"
      end

      body = JSON.parse(response.body)

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
