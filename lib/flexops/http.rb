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
require "securerandom"

module FlexOps
  class HttpClient
    DEFAULT_BASE_URL = "https://gateway.flexops.io"
    DEFAULT_TIMEOUT = 30
    MAX_RETRIES = 3
    # Statuses a GET is retried on.
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze
    # Statuses where a keyed write either never ran or is replayed by the Gateway. Never 500:
    # the Gateway does not cache a 5xx response, so a retry would run the write again.
    WRITE_RETRYABLE_STATUSES = [429, 502, 503, 504].freeze
    WRITE_METHODS = %i[post put patch].freeze
    IDEMPOTENCY_KEY_HEADER = "Idempotency-Key"
    # The Gateway's 409 while the first request with the same Idempotency-Key is still running.
    IDEMPOTENCY_CONFLICT = "IDEMPOTENCY_CONFLICT"

    attr_reader :access_token

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

    def get(path, query: nil, headers: {})
      request(:get, path, query: query, headers: headers)
    end

    def post(path, body: nil, query: nil, headers: {})
      request(:post, path, body: body, query: query, headers: headers)
    end

    def put(path, body: nil, headers: {})
      request(:put, path, body: body, headers: headers)
    end

    def patch(path, body: nil, headers: {})
      request(:patch, path, body: body, headers: headers)
    end

    def delete(path, query: nil, headers: {})
      request(:delete, path, query: query, headers: headers)
    end

    private

    def request(method, path, body: nil, query: nil, headers: {})
      uri = build_uri(path, query)
      # Every write carries one key for all of its attempts, so the Gateway replays a write it
      # already finished instead of running it (and charging the wallet) again.
      headers = with_idempotency_key(method, headers)
      last_error = nil

      (0..MAX_RETRIES).each do |attempt|
        if attempt > 0
          sleep(calculate_backoff(attempt))
        end

        req = build_request(method, uri, body)
        headers.each { |name, value| req[name] = value }
        begin
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                     open_timeout: @timeout, read_timeout: @timeout) do |http|
            http.request(req)
          end
        rescue StandardError => e
          # The Gateway may have run a timed-out or dropped request. GETs and keyed writes are
          # safe to send again; a DELETE is not covered by the idempotency middleware.
          raise if method == :delete

          last_error = e
          next
        end

        status = response.code.to_i

        if status >= 200 && status < 300
          return parse_response(response)
        end

        if status == 401
          raise AuthError
        end

        # Rate limited: the request was refused before it ran, so every method retries.
        if status == 429
          retry_after = (response["retry-after"] || "0").to_i
          last_error = RateLimitError.new(retry_after: retry_after)
          next
        end

        error_body = parse_error_body(response)
        error = Error.new(
          error_body["message"] || "HTTP #{status}: #{response.message}",
          status: status,
          code: error_body["errorCode"] || error_body["code"] || (status == 403 ? "FORBIDDEN" : nil),
          errors: error_body["errors"],
          data: error_body["data"]
        )

        raise error unless retryable?(method, status, error.code)

        last_error = error
      end

      raise last_error || Error.new("Request failed after retries", code: "RETRY_EXHAUSTED")
    end

    # GETs retry on every RETRYABLE_STATUSES status. A write retries only where the Gateway either
    # did not run it or will replay it for the same Idempotency-Key. A DELETE retries only on 429.
    def retryable?(method, status, code)
      case method
      when :get then RETRYABLE_STATUSES.include?(status)
      when :delete then false
      else status == 409 ? code == IDEMPOTENCY_CONFLICT : WRITE_RETRYABLE_STATUSES.include?(status)
      end
    end

    def with_idempotency_key(method, headers)
      return headers unless WRITE_METHODS.include?(method)

      given = headers.any? { |name, value| name.to_s.casecmp?(IDEMPOTENCY_KEY_HEADER) && !value.to_s.empty? }
      given ? headers : headers.merge(IDEMPOTENCY_KEY_HEADER => SecureRandom.uuid)
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

    # A 2xx with no body (204, or Content-Length 0) returns nil; JSON is parsed; anything else,
    # such as a label file, is returned as the raw body string.
    def parse_response(response)
      return nil if response.code.to_i == 204 || response["content-length"] == "0" || response.body.nil? || response.body.empty?

      content_type = response["content-type"] || ""
      if content_type.include?("application/json")
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def parse_error_body(response)
      parsed = JSON.parse(response.body)
      parsed.is_a?(Hash) ? parsed : {}
    rescue StandardError
      {}
    end

    def calculate_backoff(attempt)
      jitter = rand(0.85..1.15)
      [1.0 * (2**(attempt - 1)) * jitter, 30.0].min
    end
  end
end
