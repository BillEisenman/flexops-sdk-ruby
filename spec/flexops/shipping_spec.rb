# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-04-01
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

RSpec.describe FlexOps::Resources::Shipping do
  let(:client) { create_client }
  let(:ws_path) { "#{BASE_URL}/api/workspaces/ws-test-123" }

  describe "#get_rates" do
    it "returns parsed rate data from the API" do
      rates = [
        { carrier: "USPS", service: "Priority Mail", rate: 8.50, estimatedDays: 2 },
        { carrier: "UPS", service: "Ground", rate: 12.30, estimatedDays: 5 }
      ]

      request = {
        origin: { addressLine1: "123 Main St", city: "New York", stateProvince: "NY", postalCode: "10001" },
        destination: { addressLine1: "456 Oak Ave", city: "Los Angeles", stateProvince: "CA", postalCode: "90210" },
        package: { weight: 16, weightUnit: "oz" }
      }
      stub_request(:post, "#{BASE_URL}/api/shipping/rates")
        .with(body: request.to_json)
        .to_return(status: 200, body: { currency: "USD", rates: rates }.to_json, headers: { "Content-Type" => "application/json" })

      result = client.shipping.get_rates(request)

      expect(result["rates"]).to be_an(Array)
      expect(result["rates"].length).to eq(2)
      expect(result["rates"][0]["carrier"]).to eq("USPS")
      expect(result["rates"][1]["rate"]).to eq(12.30)
    end
  end

  describe "#create_label" do
    it "previews without purchasing and preserves approval and key across retries" do
      request = rate_request.merge(carrierCode: "USPS", serviceCode: "GROUND_ADVANTAGE", maximumPostageAmount: 10.25)
      url = "#{ws_path}/shipping/labels"
      preview_stub = stub_request(:post, url).with(body: request.to_json)
        .to_return(status: 200, body: {status: "Preview", confirmationToken: "approval",
          quotedPostageAmount: 8.5, maximumPostageAmount: 10.25, currency: "USD",
          expiresAt: "2026-09-19T00:05:00Z"}.to_json, headers: {"Content-Type" => "application/json"})
      preview = client.shipping.create_label(request)
      expect(preview["status"]).to eq("Preview")
      expect(preview_stub).to have_been_requested.once
      request = request.merge(confirmationToken: preview["confirmationToken"])
      purchase_stub = stub_request(:post, url).with(body: request.to_json, headers: {"Idempotency-Key" => "purchase-001"})
        .to_return(status: 503, body: '{"message":"temporary"}', headers: {"Content-Type" => "application/json"})
        .then.to_return(status: 201, body: '{"labelId":"lbl-001","carrierCode":"USPS"}', headers: {"Content-Type" => "application/json"})
      label = client.shipping.create_label(request, idempotency_key: "purchase-001")
      expect(label["labelId"]).to eq("lbl-001")
      expect(purchase_stub).to have_been_requested.twice
      preview_request = request.reject { |key, _| key == :confirmationToken }
      stub_request(:post, url).with(body: preview_request.to_json) { |r| !r.headers.key?("Idempotency-Key") }
        .to_return(status: 200, body: '{"status":"Preview"}', headers: {"Content-Type" => "application/json"})
      expect(client.shipping.create_label(**preview_request)["status"]).to eq("Preview")
    end

    [[400, "ApprovalRequired"], [409, "ApprovalExpired"]].each do |status, code|
      it "preserves #{code} without retrying" do
        stub = stub_request(:post, "#{ws_path}/shipping/labels")
          .to_return(status: status, body: {errorCode: code, message: code}.to_json, headers: {"Content-Type" => "application/json"})
        expect { client.shipping.create_label({}) }.to raise_error(FlexOps::Error) { |e|
          expect(e.status).to eq(status)
          expect(e.code).to eq(code)
        }
        expect(stub).to have_been_requested.once
      end
    end
  end

  describe "#track" do
    it "returns tracking information for a tracking number" do
      tracking = {
        trackingNumber: "9400111899223456789012",
        carrier: "USPS",
        status: "In Transit",
        events: [
          { timestamp: "2026-03-04T10:00:00Z", status: "Departed", description: "Left facility" }
        ]
      }

      stub_request(:get, "#{ws_path}/shipping/track/9400111899223456789012")
        .to_return(status: 200, body: json_body(tracking), headers: { "Content-Type" => "application/json" })

      result = client.shipping.track("9400111899223456789012")

      expect(result["success"]).to be true
      expect(result["data"]["status"]).to eq("In Transit")
      expect(result["data"]["events"].length).to eq(1)
      expect(result["data"]["events"][0]["description"]).to eq("Left facility")
    end
  end

  describe "#get_recommendations" do
    it "returns AI carrier recommendations" do
      recommendations = {
        lane: "80202-10001",
        sampleSize: 100,
        recommendations: [
          { carrierCode: "ups", score: 0.91, onTimePercent: 97.2 }
        ]
      }

      stub_request(:post, "#{ws_path}/shipping/recommendations")
        .to_return(status: 200, body: json_body(recommendations), headers: { "Content-Type" => "application/json" })

      result = client.shipping.get_recommendations({
        origin_postal_code: "80202",
        destination_postal_code: "10001"
      })

      expect(result["success"]).to be true
      expect(result["data"]["lane"]).to eq("80202-10001")
      expect(result["data"]["recommendations"].length).to eq(1)
    end
  end
end
