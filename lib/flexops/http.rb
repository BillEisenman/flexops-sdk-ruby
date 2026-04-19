# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "net/http"
require "uri"
require "json"

module FlexOps
  class HttpClient
    DEFAULT_BASE_URL = "https://gateway.flexops.io"
    DEFAULT_TIMEOUT = 30
    MAX_RETRIES = 3
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

    def initialize(base_url: DEFAULT_BASE_URL, api_key: nil, access_token: nil, timeout: DEFAULT_TIMEOUT)
      @base_url = base_url.chomp("/")
      @api_key = api_key
      @access_token = access_token
      @timeout = timeout
    end

    def set_access_token(token)
      @access_token = token
      @api_key = nil
    end

    def set_api_key(key)
      @api_key = key
      @access_token = nil
    end

    def get(path, query: nil)
      request(:get, path, query: query)
    end

    def post(path, body: nil, query: nil)
      request(:post, path, body: body, query: query)
    end

    def put(path, body: nil)
      request(:put, path, body: body)
    end

    def patch(path, body: nil)
      request(:patch, path, body: body)
    end

    def delete(path)
      request(:delete, path)
    end

    private

    def request(method, path, body: nil, query: nil)
      uri = build_uri(path, query)
      last_error = nil

      (0..MAX_RETRIES).each do |attempt|
        if attempt > 0
          sleep(calculate_backoff(attempt))
        end

        req = build_request(method, uri, body)
        begin
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                     open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.request(req)
          end

          status = response.code.to_i

          if status >= 200 && status < 300
            return parse_response(response)
          end

          if status == 401
            raise AuthError
          end

          if status == 403
            raise Error.new("Access denied. Check your plan tier and feature entitlements.", status: 403, code: "FORBIDDEN")
          end

          if status == 429
            retry_after = (response["retry-after"] || "0").to_i
            last_error = RateLimitError.new(retry_after: retry_after)
            next if RETRYABLE_STATUSES.include?(429)
            raise last_error
          end

          error_body = parse_error_body(response)
          error = Error.new(
            error_body["message"] || "HTTP #{status}: #{response.message}",
            status: status,
            errors: error_body["errors"]
          )

          if RETRYABLE_STATUSES.include?(status)
            last_error = error
            next
          end

          raise error
        rescue Error
          raise
        rescue StandardError => e
          last_error = e
          next if attempt < MAX_RETRIES
        end
      end

      raise last_error || Error.new("Request failed after retries", code: "RETRY_EXHAUSTED")
    end

    def build_uri(path, query)
      url = "#{@base_url}#{path.start_with?("/") ? path : "/#{path}"}"
      uri = URI.parse(url)
      if query
        params = URI.encode_www_form(query.compact)
        uri.query = params unless params.empty?
      end
      uri
    end

    def build_request(method, uri, body)
      klass = case method
              when :get    then Net::HTTP::Get
              when :post   then Net::HTTP::Post
              when :put    then Net::HTTP::Put
              when :patch  then Net::HTTP::Patch
              when :delete then Net::HTTP::Delete
              end

      req = klass.new(uri)
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"

      if @api_key
        req["X-Api-Key"] = @api_key
      elsif @access_token
        req["Authorization"] = "Bearer #{@access_token}"
      end

      req.body = body.to_json if body
      req
    end

    def parse_response(response)
      content_type = response["content-type"] || ""
      if content_type.include?("application/json")
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def parse_error_body(response)
      JSON.parse(response.body)
    rescue StandardError
      {}
    end

    def calculate_backoff(attempt)
      jitter = rand(0.85..1.15)
      [1.0 * (2**(attempt - 1)) * jitter, 30.0].min
    end
  end
end
