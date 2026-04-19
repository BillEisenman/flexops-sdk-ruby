# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-04-01
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

RSpec.describe FlexOps::Client do
  describe "initialization" do
    it "creates a client with all 20 resource accessors" do
      client = create_client
      expect(client.auth).to be_a(FlexOps::Resources::Auth)
      expect(client.shipping).to be_a(FlexOps::Resources::Shipping)
      expect(client.webhooks).to be_a(FlexOps::Resources::Webhooks)
      expect(client.carriers).to be_a(FlexOps::Resources::Carriers)
      expect(client.wallet).to be_a(FlexOps::Resources::Wallet)
      expect(client.returns).to be_a(FlexOps::Resources::Returns)
      expect(client.offsets).to be_a(FlexOps::Resources::Offsets)
      expect(client.hs_codes).to be_a(FlexOps::Resources::HsCodes)
      expect(client.recurring_shipments).to be_a(FlexOps::Resources::RecurringShipments)
      expect(client.email_templates).to be_a(FlexOps::Resources::EmailTemplates)
      expect(client.reports).to be_a(FlexOps::Resources::Reports)
    end
  end

  describe "API key authentication" do
    it "sends X-Api-Key header on requests" do
      stub_request(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .with(headers: { "X-Api-Key" => "sk_test_key" })
        .to_return(status: 200, body: json_body([]), headers: { "Content-Type" => "application/json" })

      client = create_client(api_key: "sk_test_key")
      client.shipping.get_rates({ from_zip: "10001", to_zip: "90210", weight: 16 })

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .with(headers: { "X-Api-Key" => "sk_test_key" })
    end
  end

  describe "Bearer token authentication" do
    it "sends Authorization Bearer header on requests" do
      stub_request(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .with(headers: { "Authorization" => "Bearer jwt_test_token" })
        .to_return(status: 200, body: json_body([]), headers: { "Content-Type" => "application/json" })

      client = create_client(api_key: nil, access_token: "jwt_test_token")
      client.shipping.get_rates({ from_zip: "10001", to_zip: "90210", weight: 16 })

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .with(headers: { "Authorization" => "Bearer jwt_test_token" })
    end
  end

  describe "auth mode switching" do
    it "switches from API key to Bearer token via set_access_token" do
      stub_request(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .to_return(status: 200, body: json_body([]), headers: { "Content-Type" => "application/json" })

      client = create_client(api_key: "sk_test_key")
      client.set_access_token("new_jwt_token")
      client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .with(headers: { "Authorization" => "Bearer new_jwt_token" })
    end

    it "switches from Bearer token to API key via set_api_key" do
      stub_request(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .to_return(status: 200, body: json_body([]), headers: { "Content-Type" => "application/json" })

      client = create_client(api_key: nil, access_token: "jwt_token")
      client.set_api_key("sk_new_key")
      client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/workspaces/ws-test-123/shipping/rates")
        .with(headers: { "X-Api-Key" => "sk_new_key" })
    end
  end

  describe "workspace_id" do
    it "allows changing workspace_id after initialization" do
      stub_request(:post, "#{BASE_URL}/api/workspaces/ws-new-456/shipping/rates")
        .to_return(status: 200, body: json_body([]), headers: { "Content-Type" => "application/json" })

      client = create_client
      client.workspace_id = "ws-new-456"
      client.shipping.get_rates({ from_zip: "10001", to_zip: "90210" })

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/workspaces/ws-new-456/shipping/rates")
    end
  end
end
