# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# The Gateway replays a POST/PUT/PATCH it already finished when it carries the same
# Idempotency-Key, but never caches a 5xx and does not cover DELETE. A retry must not run a
# purchase twice.
RSpec.describe FlexOps::HttpClient do
  let(:client) { create_client }
  let(:http) { FlexOps::HttpClient.new(base_url: BASE_URL, api_key: "sk_test_key") }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:hooks_url) { "#{BASE_URL}/api/workspaces/ws-test-123/webhooks" }
  let(:webhook) { { url: "https://example.com/hook" } }
  let(:uuid) { /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ }

  before { allow_any_instance_of(FlexOps::HttpClient).to receive(:sleep) }

  def record_keys(method, url, *responses)
    keys = []
    stub_request(method, url).with { |req| keys << req.headers["Idempotency-Key"] }.to_return(*responses)
    keys
  end

  def json(status, body)
    { status: status, body: body.to_json, headers: json_headers }
  end

  describe "Idempotency-Key" do
    it "sends one generated key on every attempt of a write" do
      keys = record_keys(:post, hooks_url, json(503, message: "Unavailable"), json(201, id: "wh-1"))

      expect(client.webhooks.create(webhook)["id"]).to eq("wh-1")
      expect(keys.length).to eq(2)
      expect(keys[0]).to match(uuid)
      expect(keys[1]).to eq(keys[0])
    end

    it "sends the caller's purchase key on every attempt, so the app's own retry is safe too" do
      ws = "#{BASE_URL}/api/workspaces/ws-test-123"
      policy_keys = record_keys(:post, "#{ws}/insurance/policies", json(503, message: "Unavailable"), json(201, id: "pol-1"))
      offset_keys = record_keys(:post, "#{ws}/carbon-offsets/purchase", json(201, id: "off-1"))

      client.insurance.purchase(tracking_number: "9400", carrier_code: "USPS", declared_value: 100,
                                idempotency_key: "order-42-insurance")
      2.times do
        client.carbon_offsets.purchase(tracking_number: "9400", weight_lbs: 2, distance_miles: 300,
                                       idempotency_key: "order-42-offset")
      end

      expect(policy_keys).to eq(%w[order-42-insurance order-42-insurance])
      expect(offset_keys).to eq(%w[order-42-offset order-42-offset])
    end

    it "generates a new key for each separate write" do
      keys = record_keys(:post, hooks_url, json(201, id: "wh-1"))

      client.webhooks.create(webhook)
      client.webhooks.create(webhook)

      expect(keys.uniq.length).to eq(2)
    end

    it "keeps the caller's key, whatever its header casing" do
      keys = []
      stub_request(:post, "#{BASE_URL}/x").with { |req| keys << req.headers["Idempotency-Key"] }
        .to_return(json(200, ok: true))

      http.post("/x", headers: { "idempotency-key" => "caller-1" })

      expect(keys).to eq(["caller-1"])
    end

    it "keys PUT and PATCH but not GET or DELETE" do
      sent = {}
      %i[get put patch delete].each do |verb|
        stub_request(verb, "#{BASE_URL}/x").with { |req| sent[verb] = req.headers["Idempotency-Key"]; true }
          .to_return(json(200, ok: true))
        http.send(verb, "/x")
      end

      expect(sent[:put]).to match(uuid)
      expect(sent[:patch]).to match(uuid)
      expect(sent[:get]).to be_nil
      expect(sent[:delete]).to be_nil
    end
  end

  describe "write retries" do
    it "does not retry a write after a 500, which the Gateway does not replay" do
      stub = stub_request(:post, hooks_url).to_return(json(500, message: "Internal error"))

      expect { client.webhooks.create(webhook) }.to raise_error(FlexOps::Error) { |e| expect(e.status).to eq(500) }
      expect(stub).to have_been_requested.once
    end

    it "retries a dropped write with the same key" do
      keys = []
      stub_request(:post, hooks_url).with { |req| keys << req.headers["Idempotency-Key"] }
        .to_raise(Errno::ECONNRESET).then.to_return(json(201, id: "wh-1"))

      expect(client.webhooks.create(webhook)["id"]).to eq("wh-1")
      expect(keys.length).to eq(2)
      expect(keys.uniq.length).to eq(1)
    end

    it "retries a timed-out write with the same key" do
      keys = []
      stub_request(:post, hooks_url).with { |req| keys << req.headers["Idempotency-Key"] }
        .to_timeout.then.to_return(json(201, id: "wh-1"))

      expect(client.webhooks.create(webhook)["id"]).to eq("wh-1")
      expect(keys.uniq.length).to eq(1)
    end

    [429, 502, 503, 504].each do |status|
      it "retries a write on #{status}" do
        stub = stub_request(:post, hooks_url).to_return(json(status, message: "busy"), json(201, id: "wh-1"))

        expect(client.webhooks.create(webhook)["id"]).to eq("wh-1")
        expect(stub).to have_been_requested.twice
      end
    end

    it "waits out an in-flight duplicate (409 IDEMPOTENCY_CONFLICT) and gets the replay" do
      stub = stub_request(:post, hooks_url)
        .to_return(json(409, success: false, errorCode: "IDEMPOTENCY_CONFLICT"), json(201, id: "wh-1"))

      expect(client.webhooks.create(webhook)["id"]).to eq("wh-1")
      expect(stub).to have_been_requested.twice
    end

    it "does not retry any other 409" do
      stub = stub_request(:post, hooks_url).to_return(json(409, success: false, errorCode: "CONFLICT"))

      expect { client.webhooks.create(webhook) }.to raise_error(FlexOps::Error) { |e| expect(e.code).to eq("CONFLICT") }
      expect(stub).to have_been_requested.once
    end

    # Label purchase and managed returns answer altered inputs under a used key with their own
    # PascalCase 409. Codes match exactly, so it is not taken for the in-flight duplicate.
    it "does not retry the label purchase 409 IdempotencyConflict" do
      stub = stub_request(:post, hooks_url).to_return(json(409, success: false, errorCode: "IdempotencyConflict"))

      expect { client.webhooks.create(webhook) }.to raise_error(FlexOps::Error) { |e| expect(e.code).to eq("IdempotencyConflict") }
      expect(stub).to have_been_requested.once
    end

    it "sends a write answered 422 IDEMPOTENCY_KEY_REUSED once and raises it" do
      stub = stub_request(:post, hooks_url).to_return(
        json(422, success: false, errorCode: "IDEMPOTENCY_KEY_REUSED", message: "Idempotency-Key reused with a different request")
      )

      expect { client.webhooks.create(webhook) }.to raise_error(FlexOps::Error) do |error|
        expect(error.status).to eq(422)
        expect(error.code).to eq("IDEMPOTENCY_KEY_REUSED")
      end
      expect(stub).to have_been_requested.once
    end
  end

  describe "DELETE retries" do
    let(:hook_url) { "#{hooks_url}/wh-1" }

    it "does not resend a DELETE after a dropped connection" do
      stub = stub_request(:delete, hook_url).to_raise(Errno::ECONNRESET)

      expect { client.webhooks.delete("wh-1") }.to raise_error(Errno::ECONNRESET)
      expect(stub).to have_been_requested.once
    end

    it "does not resend a DELETE after a 503" do
      stub = stub_request(:delete, hook_url).to_return(json(503, message: "Unavailable"))

      expect { client.webhooks.delete("wh-1") }.to raise_error(FlexOps::Error) { |e| expect(e.status).to eq(503) }
      expect(stub).to have_been_requested.once
    end

    it "retries a DELETE refused with 429" do
      stub = stub_request(:delete, hook_url)
        .to_return({ status: 429, headers: { "Retry-After" => "0" } }, { status: 204 })

      expect(client.webhooks.delete("wh-1")).to be_nil
      expect(stub).to have_been_requested.twice
    end
  end

  describe "GET retries" do
    it "retries a GET after a dropped connection and on 500" do
      stub = stub_request(:get, hooks_url).to_raise(Errno::ECONNRESET)
        .then.to_return(json(500, message: "oops")).then.to_return(json(200, []))

      expect(client.webhooks.list).to eq([])
      expect(stub).to have_been_requested.times(3)
    end
  end

  describe "responses" do
    it "returns nil for a 204" do
      stub_request(:delete, "#{BASE_URL}/x").to_return(status: 204)

      expect(http.delete("/x")).to be_nil
    end

    it "returns nil for a 2xx with Content-Length 0" do
      stub_request(:post, "#{BASE_URL}/x").to_return(status: 200, body: "", headers: json_headers.merge("Content-Length" => "0"))

      expect(http.post("/x")).to be_nil
    end

    it "passes a non-JSON body through" do
      stub_request(:get, "#{BASE_URL}/x").to_return(status: 200, body: "%PDF-1.7", headers: { "Content-Type" => "application/pdf" })

      expect(http.get("/x")).to eq("%PDF-1.7")
    end
  end
end
