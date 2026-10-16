# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-04-01
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "openssl"

# Fixed vector computed outside this SDK with the Gateway algorithm
# (WebhookDeliveryService): lowercase hex HMAC-SHA256 of the UTF-8 string
# "{timestamp}.{raw body}", keyed with the UTF-8 bytes of the whole secret
# string ("whsec_" prefix included, nothing base64-decoded).
# Cross-checked with Python hmac and .NET HMACSHA256.
module WebhookVector
  SECRET = "whsec_AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="
  TIMESTAMP = "1760600000"
  BODY = "{\"trackingNumber\":\"9400111899223456789012\",\"carrierCode\":\"USPS\"," \
         "\"status\":\"Delivered\",\"note\":\"café\"}"
  SIGNATURE = "sha256=47e071c489ace7e261e373daa4a358801f8d9b1d4c7d075d29e11c4fd1cd80f7"
  NOW = Time.at(1_760_600_000)
end

RSpec.describe FlexOps::Resources::Webhooks do
  def verify(payload: WebhookVector::BODY, signature: WebhookVector::SIGNATURE,
             timestamp: WebhookVector::TIMESTAMP, secret: WebhookVector::SECRET,
             now: WebhookVector::NOW, **options)
    described_class.verify_signature(payload: payload, signature: signature, timestamp: timestamp,
                                     secret: secret, now: now, **options)
  end

  def verify!(payload: WebhookVector::BODY, signature: WebhookVector::SIGNATURE,
              timestamp: WebhookVector::TIMESTAMP, secret: WebhookVector::SECRET,
              now: WebhookVector::NOW, **options)
    described_class.verify_signature!(payload: payload, signature: signature, timestamp: timestamp,
                                      secret: secret, now: now, **options)
  end

  describe ".verify_signature" do
    it "accepts the server vector" do
      expect(verify).to be true
    end

    it "accepts the raw body as binary (ASCII-8BIT), as Rack reads it" do
      expect(verify(payload: WebhookVector::BODY.b)).to be true
    end

    it "accepts the signature with or without the sha256= prefix, in either case" do
      bare_hex = WebhookVector::SIGNATURE.delete_prefix("sha256=")
      expect(verify(signature: bare_hex)).to be true
      expect(verify(signature: bare_hex.upcase)).to be true
      expect(verify(signature: "sha1=#{bare_hex}")).to be false
    end

    it "rejects a wrong secret" do
      expect(verify(secret: "whsec_wrong")).to be false
    end

    it "rejects a tampered body" do
      expect(verify(payload: WebhookVector::BODY.sub("Delivered", "Returned"))).to be false
    end

    it "rejects a changed timestamp" do
      expect(verify(timestamp: "1760600001")).to be false
    end

    it "rejects a body-only signature (the old algorithm)" do
      old = "sha256=4511bbc1123d6aaf6d2125b2043b8202385d5b35fdd4d180356499df7f18956d"
      expect(verify(signature: old)).to be false
    end

    it "rejects signatures of the wrong length" do
      expect(verify(signature: WebhookVector::SIGNATURE[0..-3])).to be false
      expect(verify(signature: "#{WebhookVector::SIGNATURE}00")).to be false
      expect(verify(signature: "sha256=")).to be false
    end

    it "rejects a missing signature or secret" do
      expect(verify(signature: nil)).to be false
      expect(verify(signature: "")).to be false
      expect(verify(secret: "")).to be false
    end

    it "rejects missing or non-numeric timestamps" do
      expect(verify(timestamp: nil)).to be false
      expect(verify(timestamp: "")).to be false
      expect(verify(timestamp: "17606OOOOO")).to be false
      expect(verify(timestamp: "+1760600000")).to be false
    end

    it "rejects stale and future timestamps beyond 300 seconds" do
      expect(verify(now: WebhookVector::NOW + 300)).to be true
      expect(verify(now: WebhookVector::NOW - 300)).to be true
      expect(verify(now: WebhookVector::NOW + 301)).to be false
      expect(verify(now: WebhookVector::NOW - 301)).to be false
    end

    it "honours a custom tolerance and ignores a non-positive one" do
      expect(verify(now: WebhookVector::NOW + 600, tolerance: 900)).to be true
      expect(verify(now: WebhookVector::NOW + 600, tolerance: 0)).to be false
    end

    it "uses the real clock by default" do
      expect(described_class.verify_signature(payload: WebhookVector::BODY, signature: WebhookVector::SIGNATURE,
                                              timestamp: WebhookVector::TIMESTAMP,
                                              secret: WebhookVector::SECRET)).to be false

      timestamp = Time.now.to_i.to_s
      signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", WebhookVector::SECRET,
                                                      "#{timestamp}.#{WebhookVector::BODY}")
      expect(described_class.verify_signature(payload: WebhookVector::BODY, signature: signature,
                                              timestamp: timestamp, secret: WebhookVector::SECRET)).to be true
    end
  end

  describe ".verify_signature!" do
    it "returns true for the server vector" do
      expect(verify!).to be true
    end

    it "raises WebhookSignatureError with a code saying why" do
      expect { verify!(secret: "whsec_wrong") }
        .to raise_error(FlexOps::WebhookSignatureError) { |e| expect(e.code).to eq("WEBHOOK_SIGNATURE_MISMATCH") }
      expect { verify!(now: WebhookVector::NOW + 301) }
        .to raise_error(FlexOps::WebhookSignatureError) { |e| expect(e.code).to eq("WEBHOOK_TIMESTAMP_OUTSIDE_TOLERANCE") }
      expect { verify!(timestamp: "abc") }
        .to raise_error(FlexOps::WebhookSignatureError) { |e| expect(e.code).to eq("WEBHOOK_INVALID_TIMESTAMP") }
      expect { verify!(signature: nil) }
        .to raise_error(FlexOps::WebhookSignatureError) { |e| expect(e.code).to eq("WEBHOOK_MISSING_SIGNATURE") }
      expect { verify!(secret: nil) }
        .to raise_error(FlexOps::WebhookSignatureError) { |e| expect(e.code).to eq("WEBHOOK_MISSING_SECRET") }
    end

    it "is a FlexOps::Error" do
      expect(FlexOps::WebhookSignatureError.ancestors).to include(FlexOps::Error)
    end
  end

  describe "CRUD operations" do
    let(:client) { create_client }
    let(:ws_path) { "#{BASE_URL}/api/workspaces/ws-test-123" }
    let(:json_headers) { { "Content-Type" => "application/json" } }

    # The Gateway answers a create with 201 and the bare WebhookSubscriptionCreatedDto,
    # not the success/data envelope its other webhook routes use.
    let(:created) do
      { id: "3f2c1a9e-0000-4000-8000-000000000001", url: "https://example.com/hook", description: nil,
        eventTypes: "LabelCreated,BatchCompleted", status: "Active", secret: "whsec_test",
        createdAt: "2026-10-16T12:00:00Z" }
    end

    def stub_create(body: created.to_json)
      stub_request(:post, "#{ws_path}/webhooks").to_return(status: 201, body: body, headers: json_headers)
    end

    def stub_update
      stub_request(:put, "#{ws_path}/webhooks/wh-001")
        .to_return(status: 200, body: json_body({ id: "wh-001" }), headers: json_headers)
    end

    def sent_body
      body = nil
      expect(WebMock).to(have_requested(:any, %r{/webhooks}).with { |req| body = JSON.parse(req.body) })
      body
    end

    it "creates a webhook subscription, sending events as the Gateway's comma-separated eventTypes" do
      stub_create

      result = client.webhooks.create({ url: "https://example.com/hook",
                                        events: [FlexOps::WebhookEventType::LABEL_CREATED, "BatchCompleted"] })

      expect(result["id"]).to eq("3f2c1a9e-0000-4000-8000-000000000001")
      # The Gateway reads a comma-separated eventTypes (no spaces) and ignores an events field.
      expect(sent_body).to eq("url" => "https://example.com/hook", "eventTypes" => "LabelCreated,BatchCompleted")
    end

    it "returns the subscription with its signing secret from the Gateway's bare 201 body" do
      stub_create

      result = client.webhooks.create({ url: "https://example.com/hook" })

      expect(result).to eq(JSON.parse(created.to_json))
      expect(result["secret"]).to eq("whsec_test")
    end

    it "unwraps an enveloped create response, so the secret stays at the top level" do
      stub_create(body: json_body(created))

      result = client.webhooks.create({ url: "https://example.com/hook" })

      expect(result).to eq(JSON.parse(created.to_json))
      expect(result["secret"]).to eq("whsec_test")
    end

    it "keeps the envelope on other webhook routes" do
      stub_update

      expect(client.webhooks.update("wh-001", { status: "Paused" })).to eq("success" => true, "data" => { "id" => "wh-001" })
    end

    it "accepts string keys, symbol names and duplicates" do
      stub_create

      client.webhooks.create({ "url" => "https://example.com/hook", "description" => "labels",
                               "events" => [:LabelCreated, "LabelCanceled", "LabelCreated"] })

      expect(sent_body).to eq("url" => "https://example.com/hook", "description" => "labels",
                              "eventTypes" => "LabelCreated,LabelCanceled")
    end

    it "omits eventTypes when no events are given, so the subscription receives every event" do
      stub_create

      client.webhooks.create({ url: "https://example.com/hook" })
      client.webhooks.create({ url: "https://example.com/hook", events: nil })

      expect(WebMock).to have_requested(:post, "#{ws_path}/webhooks")
        .with(body: { "url" => "https://example.com/hook" }).twice
    end

    it "passes an explicit eventTypes string through unchanged" do
      stub_create

      client.webhooks.create({ url: "https://example.com/hook", eventTypes: "*" })

      expect(sent_body).to eq("url" => "https://example.com/hook", "eventTypes" => "*")
    end

    it "sends updated events as eventTypes" do
      stub_update

      client.webhooks.update("wh-001", { events: [FlexOps::WebhookEventType::LABEL_CANCELED], status: "Active" })

      expect(sent_body).to eq("eventTypes" => "LabelCanceled", "status" => "Active")
    end

    it "does not modify the caller's hash" do
      stub_update
      data = { events: ["LabelCreated"] }

      client.webhooks.update("wh-001", data)

      expect(data).to eq(events: ["LabelCreated"])
    end

    [
      ["a dotted name", ["label.created"]],
      ["a name FlexOps never sends", %w[LabelCreated ShipmentCreated]],
      ["a name with spaces", [" LabelCreated"]],
      ["an empty list", []],
      ["a single string", "LabelCreated"],
      ["a nil name", [nil]]
    ].each do |label, events|
      it "refuses #{label} on create and update without calling the API" do
        expect { client.webhooks.create({ url: "https://example.com/hook", events: events }) }
          .to raise_error(ArgumentError)
        expect { client.webhooks.update("wh-001", { events: events }) }.to raise_error(ArgumentError)

        expect(WebMock).not_to have_requested(:any, //)
      end
    end

    it "names the unknown event and the events FlexOps sends" do
      expect { client.webhooks.create({ url: "https://example.com/hook", events: ["label.created"] }) }
        .to raise_error(ArgumentError, /label\.created.*LabelCreated, LabelCanceled, BatchCompleted/)
    end

    it "refuses events together with eventTypes" do
      expect { client.webhooks.create({ url: "https://example.com/hook", events: ["LabelCreated"], eventTypes: "*" }) }
        .to raise_error(ArgumentError, /not both/)
      expect(WebMock).not_to have_requested(:any, //)
    end
  end

  describe "FlexOps::WebhookEventType" do
    it "lists the event names the Gateway sends" do
      expect(FlexOps::WebhookEventType::ALL).to eq(
        %w[LabelCreated LabelCanceled BatchCompleted TrackingUpdated TrackingDelivered]
      )
      expect(FlexOps::WebhookEventType::ALL).to be_frozen
    end
  end
end
