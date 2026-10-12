# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-12
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# The HAZMAT declaration is sent only when the caller sets it (0 = NONE is an answer);
# the SDK never defaults it.
RSpec.describe "HAZMAT declaration" do
  let(:client) { create_client }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:label_url) { "#{BASE_URL}/api/shipping/labels" }
  let(:label) { rate_request.merge(carrierCode: "USPS", serviceCode: "PRIORITY") }

  def sent_hazmat(request)
    body = JSON.parse(request.body)
    body.key?("hazmatClassification") ? body["hazmatClassification"] : :absent
  end

  it "exposes the Gateway enum numbers" do
    expect(FlexOps::HazmatClassification::ALL).to eq(
      NONE: 0, LIMITED_QUANTITY: 1, LITHIUM_BATTERY_CONTAINED_IN_EQUIPMENT: 2,
      LITHIUM_BATTERY_PACKED_WITH_EQUIPMENT: 3, LITHIUM_BATTERY_STANDALONE: 4,
      OTHER_RESTRICTED: 5, LITHIUM_BATTERY_USED_DEVICE: 6
    )
    expect(FlexOps::HazmatClassification::NONE).to eq(0)
  end

  it "sends a label's class only when set, to the Gateway label route" do
    sent = []
    stub_request(:post, label_url).with { |req| sent << sent_hazmat(req) }
      .to_return(status: 200, body: '{"status":"Preview"}', headers: json_headers)

    client.shipping.create_label(label)
    client.shipping.create_label(label.merge(hazmatClassification: FlexOps::HazmatClassification::NONE))
    client.shipping.create_label(**label, hazmatClassification: FlexOps::HazmatClassification::LIMITED_QUANTITY)

    expect(sent).to eq([:absent, 0, 1])
  end

  it "sends a rate request's class as the Gateway number" do
    sent = []
    stub_request(:post, "#{BASE_URL}/api/shipping/rates").with { |req| sent << sent_hazmat(req) }
      .to_return(status: 200, body: '{"rates":[]}', headers: json_headers)

    client.shipping.get_rates(rate_request.merge(hazmatClassification: FlexOps::HazmatClassification::NONE))
    client.shipping.get_rates(rate_request)

    expect(sent).to eq([0, :absent])
  end

  it "sends a return label's class only when set" do
    url = "#{BASE_URL}/api/workspaces/ws-test-123/returns/RMA-1/label"
    bodies = []
    stub_request(:post, url).with { |req| bodies << req.body }
      .to_return(status: 200, body: '{"success":true}', headers: json_headers)

    client.returns.generate_label("RMA-1")
    client.returns.generate_label("RMA-1", hazmat_classification: FlexOps::HazmatClassification::NONE)

    # The Gateway binds a required GenerateReturnLabelRequest body; {} takes its defaults.
    expect(bodies[0]).to eq("{}")
    expect(JSON.parse(bodies[1])).to eq("hazmatClassification" => 0)
  end

  # FlexOpsGateway#672: without a default shipping preset the Gateway needs the package on the request.
  it "sends a return label's package weight and size" do
    url = "#{BASE_URL}/api/workspaces/ws-test-123/returns/RMA-1/label"
    bodies = []
    stub_request(:post, url).with { |req| bodies << JSON.parse(req.body) }
      .to_return(status: 200, body: '{"success":true}', headers: json_headers)

    client.returns.generate_label("RMA-1", weight_oz: 16, length_in: 10, width_in: 8, height_in: 4)

    expect(bodies).to eq([{ "weightOz" => 16, "lengthIn" => 10, "widthIn" => 8, "heightIn" => 4 }])
  end

  it "sends address validation as the Gateway AddressValidationRequest" do
    canonical = { "addressLine1" => "123 Main St", "city" => "New York", "stateProvince" => "NY",
                  "postalCode" => "10001", "countryCode" => "US" }
    bodies = []
    stub_request(:post, "#{BASE_URL}/api/shipping/addresses/validate").with { |req| bodies << JSON.parse(req.body) }
      .to_return(status: 200, body: '{"isValid":true}', headers: json_headers)

    client.shipping.validate_address(name: "J", street1: "123 Main St", city: "New York", state: "NY",
                                     zip: "10001", country: "US")
    client.shipping.validate_address(canonical)

    expect(bodies).to eq([{ "address" => { "name" => "J" }.merge(canonical) }, { "address" => canonical }])
  end
end
