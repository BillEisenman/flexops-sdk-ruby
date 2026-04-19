# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-04-01
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

RSpec.describe "Error handling" do
  let(:client) { create_client }
  let(:ws_path) { "#{BASE_URL}/api/workspaces/ws-test-123" }

  describe "401 Unauthorized" do
    it "raises FlexOps::AuthError" do
      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(status: 401, body: { message: "Invalid token" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect {
        client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })
      }.to raise_error(FlexOps::AuthError) { |e|
        expect(e.status).to eq(401)
        expect(e.code).to eq("UNAUTHORIZED")
      }
    end
  end

  describe "400 Bad Request" do
    it "raises FlexOps::Error with validation details" do
      error_body = { message: "Validation failed", errors: ["weight is required"] }

      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(status: 400, body: error_body.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect {
        client.shipping.get_rates({ from_zip: "", to_zip: "" })
      }.to raise_error(FlexOps::Error) { |e|
        expect(e.status).to eq(400)
        expect(e.message).to eq("Validation failed")
        expect(e.errors).to include("weight is required")
      }
    end
  end

  describe "403 Forbidden" do
    it "raises FlexOps::Error with access denied message" do
      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(status: 403, body: "".to_json,
                   headers: { "Content-Type" => "application/json" })

      expect {
        client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })
      }.to raise_error(FlexOps::Error) { |e|
        expect(e.status).to eq(403)
        expect(e.code).to eq("FORBIDDEN")
      }
    end
  end

  describe "429 Rate Limited" do
    it "retries and eventually raises FlexOps::RateLimitError when all retries exhausted" do
      # Return 429 for all attempts (initial + 3 retries = 4 total)
      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(
          status: 429,
          body: { message: "Rate limited" }.to_json,
          headers: { "Content-Type" => "application/json", "Retry-After" => "0" }
        )

      # Stub sleep to avoid real delays during tests
      allow_any_instance_of(FlexOps::HttpClient).to receive(:sleep)

      expect {
        client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })
      }.to raise_error(FlexOps::RateLimitError) { |e|
        expect(e.status).to eq(429)
        expect(e.code).to eq("RATE_LIMITED")
      }
    end
  end

  describe "retry on 5xx" do
    it "retries on 500 and succeeds on the second attempt" do
      # First call returns 500, second succeeds
      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(
          { status: 500, body: { message: "Internal error" }.to_json,
            headers: { "Content-Type" => "application/json" } },
          { status: 200, body: json_body([{ carrier: "USPS", rate: 5.25 }]),
            headers: { "Content-Type" => "application/json" } }
        )

      allow_any_instance_of(FlexOps::HttpClient).to receive(:sleep)

      result = client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })

      expect(result["success"]).to be true
      expect(result["data"].length).to eq(1)
    end

    it "retries on 429 and succeeds on the third attempt" do
      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(
          { status: 429, body: { message: "Rate limited" }.to_json,
            headers: { "Content-Type" => "application/json", "Retry-After" => "0" } },
          { status: 429, body: { message: "Rate limited" }.to_json,
            headers: { "Content-Type" => "application/json", "Retry-After" => "0" } },
          { status: 200, body: json_body([]),
            headers: { "Content-Type" => "application/json" } }
        )

      allow_any_instance_of(FlexOps::HttpClient).to receive(:sleep)

      result = client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })

      expect(result["success"]).to be true
    end
  end

  describe "error class hierarchy" do
    it "FlexOps::AuthError inherits from FlexOps::Error" do
      expect(FlexOps::AuthError.new).to be_a(FlexOps::Error)
    end

    it "FlexOps::RateLimitError inherits from FlexOps::Error" do
      expect(FlexOps::RateLimitError.new).to be_a(FlexOps::Error)
    end
  end
end
