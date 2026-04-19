# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-04-01
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "openssl"

RSpec.describe FlexOps::Resources::Webhooks do
  describe ".verify_signature" do
    let(:secret) { "whsec_test_secret" }
    let(:payload) { '{"event":"label.created","labelId":"lbl_123"}' }

    it "returns true for a valid HMAC-SHA256 signature" do
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)

      result = FlexOps::Resources::Webhooks.verify_signature(payload, signature, secret)
      expect(result).to be true
    end

    it "returns false for an invalid signature" do
      result = FlexOps::Resources::Webhooks.verify_signature(payload, "deadbeef" * 8, secret)
      expect(result).to be false
    end

    it "returns false when the secret is wrong" do
      signature = OpenSSL::HMAC.hexdigest("SHA256", "correct_secret", payload)

      result = FlexOps::Resources::Webhooks.verify_signature(payload, signature, "wrong_secret")
      expect(result).to be false
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
