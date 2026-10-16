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

    it "creates a webhook subscription" do
      webhook = { id: "wh-001", url: "https://example.com/hook", events: ["label.created"] }

      stub_request(:post, "#{ws_path}/webhooks")
        .to_return(status: 200, body: json_body(webhook), headers: { "Content-Type" => "application/json" })

      result = client.webhooks.create({ url: "https://example.com/hook", events: ["label.created"] })

      expect(result["success"]).to be true
      expect(result["data"]["id"]).to eq("wh-001")
    end
  end
end
