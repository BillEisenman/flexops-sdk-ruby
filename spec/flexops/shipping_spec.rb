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

      stub_request(:post, "#{ws_path}/shipping/rates")
        .to_return(status: 200, body: json_body(rates), headers: { "Content-Type" => "application/json" })

      result = client.shipping.get_rates({ from_zip: "10001", to_zip: "90210", weight: 16 })

      expect(result["success"]).to be true
      expect(result["data"]).to be_an(Array)
      expect(result["data"].length).to eq(2)
      expect(result["data"][0]["carrier"]).to eq("USPS")
      expect(result["data"][1]["rate"]).to eq(12.30)
    end
  end

  describe "#create_label" do
    it "posts label creation request and returns label data" do
      label = {
        labelId: "lbl_abc123",
        trackingNumber: "9400111899223456789012",
        carrier: "USPS",
        rate: 8.50
      }

      stub_request(:post, "#{ws_path}/shipping/labels")
        .to_return(status: 200, body: json_body(label), headers: { "Content-Type" => "application/json" })

      result = client.shipping.create_label({
        carrier: "USPS",
        service: "Priority Mail",
        from_address: { name: "Sender", street1: "123 Main St", city: "Denver", state: "CO", zip: "80202", country: "US" },
        to_address: { name: "Recipient", street1: "456 Park Ave", city: "New York", state: "NY", zip: "10001", country: "US" },
        parcel: { weight: 16 }
      })

      expect(result["success"]).to be true
      expect(result["data"]["labelId"]).to eq("lbl_abc123")
      expect(result["data"]["trackingNumber"]).to eq("9400111899223456789012")
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
