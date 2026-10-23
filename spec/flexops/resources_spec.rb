# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# Routes, bodies and headers checked against the Gateway controllers and DTOs.
RSpec.describe "Gateway resource contracts" do
  let(:client) { create_client }
  let(:ws_path) { "#{BASE_URL}/api/workspaces/ws-test-123" }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  # Stubs one route and returns the parsed JSON bodies sent to it.
  def capture(method, url, response = { success: true })
    bodies = []
    stub_request(method, url).with { |req| bodies << (req.body.to_s.empty? ? nil : JSON.parse(req.body)) }
      .to_return(status: 200, body: response.to_json, headers: json_headers)
    bodies
  end

  describe "wallet" do
    it "reads my-balance with the configured workspace in X-Workspace-Id" do
      stub = stub_request(:get, "#{BASE_URL}/api/wallet/my-balance")
        .with(headers: { "X-Workspace-Id" => "ws-test-123" })
        .to_return(status: 200, body: { hasWallet: true, balanceCents: 1250, balance: 12.5 }.to_json, headers: json_headers)

      expect(client.wallet.get_balance["balanceCents"]).to eq(1250)
      expect(stub).to have_been_requested.once
    end

    it "no longer offers funding or history" do
      %i[add_funds list_transactions configure_auto_reload].each { |name| expect(client.wallet).not_to respond_to(name) }
    end
  end

  describe "hs_codes" do
    it "uses the Gateway shipping routes without a workspace" do
      stub_request(:get, "#{BASE_URL}/api/shipping/hs-codes/search?query=mug&destinationCountry=CA&maxResults=5")
        .to_return(status: 200, body: '[{"code":"6912.00"}]', headers: json_headers)
      stub_request(:get, "#{BASE_URL}/api/shipping/hs-codes/6912.00")
        .to_return(status: 200, body: '{"code":"6912.00"}', headers: json_headers)
      request = { destinationCountry: "CA", shippingCost: 12.5,
                  items: [{ description: "Mug", quantity: 2, value: 10, weightOz: 12, originCountry: "US" }] }
      bodies = capture(:post, "#{BASE_URL}/api/shipping/landed-cost", { totalLandedCost: 30 })

      expect(client.hs_codes.search("mug", destination_country: "CA", max_results: 5)[0]["code"]).to eq("6912.00")
      expect(client.hs_codes.lookup("6912.00")["code"]).to eq("6912.00")
      expect(client.hs_codes.estimate_landed_cost(request)["totalLandedCost"]).to eq(30)
      expect(bodies).to eq([JSON.parse(request.to_json)])
    end
  end

  describe "insurance" do
    it "sends the Gateway quote, policy and claim requests" do
      quote = capture(:post, "#{ws_path}/insurance/quote")
      policy = capture(:post, "#{ws_path}/insurance/policies")
      claim = capture(:post, "#{ws_path}/insurance/claims")
      void = stub_request(:delete, "#{ws_path}/insurance/policies/pol-1").to_return(status: 200, body: "{}", headers: json_headers)
      providers = stub_request(:get, "#{ws_path}/insurance/providers").to_return(status: 200, body: "{}", headers: json_headers)

      client.insurance.get_quote(declared_value: 100, carrier_code: "USPS", tracking_number: "9400")
      client.insurance.purchase(tracking_number: "9400", carrier_code: "USPS", declared_value: 100, coverage_tier: "Basic")
      client.insurance.file_claim(policy_id: "pol-1", claim_reason: "Damaged", claim_amount: 50)
      client.insurance.void("pol-1")
      client.insurance.get_providers

      expect(quote).to eq([{ "declaredValue" => 100, "carrierCode" => "USPS", "trackingNumber" => "9400" }])
      expect(policy).to eq([{ "trackingNumber" => "9400", "carrierCode" => "USPS", "declaredValue" => 100,
                              "coverageTier" => "Basic" }])
      expect(claim).to eq([{ "policyId" => "pol-1", "claimReason" => "Damaged", "claimAmount" => 50 }])
      expect(void).to have_been_requested.once
      expect(providers).to have_been_requested.once
    end
  end

  describe "returns" do
    it "creates an RMA on returns/rma" do
      request = { orderId: 1001, reason: "Damaged", items: [{ sku: "SKU-1", quantity: 1 }] }
      bodies = capture(:post, "#{ws_path}/returns/rma", { success: true, data: { rmaNumber: "RMA-1" } })

      expect(client.returns.create(request)["data"]["rmaNumber"]).to eq("RMA-1")
      expect(bodies).to eq([JSON.parse(request.to_json)])
    end

    it "sends carrierCode only when set and the rate indicator" do
      bodies = capture(:post, "#{ws_path}/returns/RMA-1/label")

      client.returns.generate_label("RMA-1", carrier_code: "usps", rate_indicator: "SP")

      expect(bodies).to eq([{ "carrierCode" => "usps", "rateIndicator" => "SP" }])
    end

    it "receives an RMA with its inspected items" do
      items = [{ partNumber: "SKU-1", quantity: 1, disposition: 0 }]
      bodies = capture(:post, "#{ws_path}/returns/42/receive")

      client.returns.mark_received(42, rma_number: "RMA-1", inspected_items: items, warehouse_id: 3)

      expect(bodies).to eq([{ "rmaNumber" => "RMA-1", "warehouseId" => 3, "inspectedItems" => JSON.parse(items.to_json) }])
    end

    it "lists with the Gateway's date filters" do
      stub = stub_request(:get, "#{ws_path}/returns?page=2&startDate=2026-10-01")
        .to_return(status: 200, body: "{}", headers: json_headers)

      client.returns.list(page: 2, start_date: "2026-10-01")

      expect(stub).to have_been_requested.once
    end

    it "no longer offers the portal actions" do
      %i[approve reject cancel process_refund].each { |name| expect(client.returns).not_to respond_to(name) }
    end

    it "reads RMAs on the RMA routes and a received return by numeric id" do
      by_number = stub_request(:get, "#{ws_path}/returns/rma/RMA-1001").to_return(status: 200, body: "{}", headers: json_headers)
      paged = stub_request(:get, "#{ws_path}/returns/rma?page=2&pageSize=50").to_return(status: 200, body: "{}", headers: json_headers)
      all = stub_request(:get, "#{ws_path}/returns/rma").to_return(status: 200, body: "{}", headers: json_headers)
      received = stub_request(:get, "#{ws_path}/returns/42").to_return(status: 200, body: "{}", headers: json_headers)

      client.returns.get_rma("RMA-1001")
      client.returns.list_rmas(page: 2, page_size: 50)
      client.returns.list_rmas
      client.returns.get(42)

      [by_number, paged, all, received].each { |stub| expect(stub).to have_been_requested.once }
    end
  end

  describe "multi-package labels" do
    let(:request) do
      { orderId: 15563627, carrierCode: "USPS", serviceCode: "PRIORITY",
        hazmatClassification: FlexOps::HazmatClassification::NONE,
        maximumPostageAmount: 25.0,
        packages: [{ weightInOunces: 16, lengthInInches: 10, widthInInches: 8, heightInInches: 4, packageReference: "Box 1 of 2" },
                   { weightInOunces: 8, lengthInInches: 6, widthInInches: 6, heightInInches: 6 }] }
    end

    it "posts the order and boxes to the multi-package route with the caller's key" do
      bodies = []
      stub = stub_request(:post, "#{BASE_URL}/api/shipping/multi-package")
        .with(headers: { "Idempotency-Key" => "order-15563627" }) { |req| bodies << JSON.parse(req.body) }
        .to_return(status: 200, body: { success: true, data: { successfulPackages: 2, labels: [] } }.to_json, headers: json_headers)

      result = client.shipping.create_multi_package(request, idempotency_key: "order-15563627")

      # The body checks come first: WebMock runs the with-block again when it verifies the stub.
      expect(bodies).to eq([JSON.parse(request.to_json)])
      expect(bodies.first["hazmatClassification"]).to eq(0)
      expect(bodies.first["maximumPostageAmount"]).to eq(25.0)
      expect(stub).to have_been_requested.once
      expect(result["data"]["successfulPackages"]).to eq(2)
    end

    it "raises with the Gateway code when the ceiling is refused and does not retry it" do
      stub = stub_request(:post, "#{BASE_URL}/api/shipping/multi-package")
        .to_return(status: 400, body: { success: false, errorCode: "ApprovalRequired",
                                        message: "Supply maximumPostageAmount in USD, positive and with at most two decimal places." }.to_json,
                   headers: json_headers)

      expect { client.shipping.create_multi_package(request.merge(maximumPostageAmount: 0)) }.to raise_error(FlexOps::Error) { |error|
        expect(error.status).to eq(400)
        expect(error.code).to eq("ApprovalRequired")
      }
      expect(stub).to have_been_requested.once
    end

    # The request is a hash, so the required ceiling is part of the documented contract.
    it "documents the required ceiling on the request" do
      source = File.read(File.expand_path("../../lib/flexops/resources/shipping.rb", __dir__))

      expect(source).to include("maximumPostageAmount: 25.00")
      expect(source).to include("maximumPostageAmount is required")
      expect(source).to include("refuses to buy a box that would take the total above it")
    end

    it "keeps the per-box results on an unknown outcome and does not retry it" do
      data = { "orderId" => 1, "failedPackages" => 1, "labels" => [{ "packageIndex" => 0, "success" => false, "errorCode" => "OutcomeUnknown" }] }
      stub = stub_request(:post, "#{BASE_URL}/api/shipping/multi-package")
        .to_return(status: 409, body: { success: false, message: "No label was confirmed", errorCode: "OutcomeUnknown", data: data }.to_json,
                   headers: json_headers)

      expect { client.shipping.create_multi_package(request) }.to raise_error(FlexOps::Error) { |error|
        expect(error.status).to eq(409)
        expect(error.code).to eq("OutcomeUnknown")
        expect(error.data).to eq(data)
      }
      expect(stub).to have_been_requested.once
    end
  end

  describe "rules" do
    it "reorders with POST and { rules: [{ ruleId, priority }] }" do
      bodies = capture(:post, "#{ws_path}/shipping-rules/reorder")

      client.rules.reorder(%w[r-a r-b])
      client.rules.reorder([{ ruleId: "r-b", priority: 5 }])

      expect(bodies).to eq([
        { "rules" => [{ "ruleId" => "r-a", "priority" => 0 }, { "ruleId" => "r-b", "priority" => 1 }] },
        { "rules" => [{ "ruleId" => "r-b", "priority" => 5 }] }
      ])
    end

    it "creates a rule and tests the rules" do
      rule = { name: "Heavy", priority: 1, isEnabled: true,
               conditions: [{ field: "WeightOz", operator: "GreaterThan", value: "160" }],
               actions: [{ type: "SetCarrier", value: "UPS" }] }
      created = capture(:post, "#{ws_path}/shipping-rules")
      tested = capture(:post, "#{ws_path}/shipping-rules/test")

      client.rules.create(rule)
      client.rules.test(weightOz: 200, declaredValue: 50, destinationCountry: "US")

      expect(created).to eq([JSON.parse(rule.to_json)])
      expect(tested).to eq([{ "weightOz" => 200, "declaredValue" => 50, "destinationCountry" => "US" }])
    end
  end

  describe "pickups" do
    it "lists scheduled pickups and passes the carrier code" do
      list = stub_request(:get, "#{ws_path}/pickups/scheduled").to_return(status: 200, body: "{}", headers: json_headers)
      get = stub_request(:get, "#{ws_path}/pickups/PU-1?carrierCode=ups").to_return(status: 200, body: "{}", headers: json_headers)
      cancel = stub_request(:delete, "#{ws_path}/pickups/PU-1?carrierCode=ups").to_return(status: 200, body: "{}", headers: json_headers)

      client.pickups.list
      client.pickups.get("PU-1", carrier_code: "ups")
      client.pickups.cancel("PU-1", carrier_code: "ups")

      expect([list, get, cancel]).to all(have_been_requested.once)
    end

    it "schedules a pickup with the Gateway SchedulePickupRequest" do
      request = { carrierCode: "usps", pickupDate: "2026-10-20", street: "1 Main St", city: "Denver",
                  state: "CO", postalCode: "80202", packageCount: 2 }
      bodies = capture(:post, "#{ws_path}/pickups")

      client.pickups.schedule(request)

      expect(bodies).to eq([JSON.parse(request.to_json)])
    end
  end

  describe "workspace members" do
    it "sends roles as WorkspaceRole numbers" do
      invites = capture(:post, "#{ws_path}/members/invite")
      roles = capture(:put, "#{ws_path}/members/user-1/role")

      client.workspaces.invite_member(email: "a@example.com", role: :member)
      client.workspaces.invite_member(email: "b@example.com", role: FlexOps::WorkspaceRole::MERCHANT)
      client.workspaces.update_member_role("user-1", "Admin")

      expect(invites).to eq([{ "email" => "a@example.com", "role" => 2 }, { "email" => "b@example.com", "role" => 3 }])
      expect(roles).to eq([{ "newRole" => 1 }])
    end

    it "refuses an unknown role before any request" do
      expect { client.workspaces.update_member_role("user-1", "Viewer") }.to raise_error(ArgumentError, /Viewer/)
      expect { client.workspaces.invite_member(email: "a@example.com", role: 7) }.to raise_error(ArgumentError)
      expect(FlexOps::WorkspaceRole::ALL).to eq(OWNER: 0, ADMIN: 1, MEMBER: 2, MERCHANT: 3)
    end

    it "no longer creates or updates workspaces" do
      %i[create update].each { |name| expect(client.workspaces).not_to respond_to(name) }
    end
  end

  describe "carbon_offsets" do
    let(:base) { "#{ws_path}/carbon-offsets" }

    it "calls every carbon offset route" do
      quote = capture(:post, "#{base}/quote")
      purchase = capture(:post, "#{base}/purchase")
      settings = capture(:put, "#{base}/settings")
      gets = ["#{base}?page=2&pageSize=10", "#{base}/off-1", "#{base}/summary", "#{base}/settings"].map do |url|
        stub_request(:get, url).to_return(status: 200, body: "{}", headers: json_headers)
      end

      client.carbon_offsets.quote(weight_lbs: 2.5, distance_miles: 800)
      client.carbon_offsets.purchase(tracking_number: "9400", weight_lbs: 2.5, distance_miles: 800)
      client.carbon_offsets.update_settings(auto_offset_enabled: true)
      client.carbon_offsets.list(page: 2, page_size: 10)
      client.carbon_offsets.get("off-1")
      client.carbon_offsets.summary
      client.carbon_offsets.get_settings

      expect(quote).to eq([{ "weightLbs" => 2.5, "distanceMiles" => 800 }])
      expect(purchase).to eq([{ "trackingNumber" => "9400", "weightLbs" => 2.5, "distanceMiles" => 800 }])
      expect(settings).to eq([{ "autoOffsetEnabled" => true }])
      expect(gets).to all(have_been_requested.once)
    end
  end

  describe "webhooks" do
    it "sends a test event" do
      stub = stub_request(:post, "#{ws_path}/webhooks/wh-1/test").to_return(status: 200, body: "{}", headers: json_headers)

      client.webhooks.test("wh-1")

      expect(stub).to have_been_requested.once
      expect(client.webhooks).not_to respond_to(:get)
    end
  end

  describe "auth" do
    it "refreshes with the access token and the refresh token" do
      bodies = capture(:post, "#{BASE_URL}/api/Account/refresh-token")

      create_client(api_key: nil, access_token: "at-1").auth.refresh_token("rt-1")
      client.auth.refresh_token("rt-2", access_token: "at-2")

      expect(bodies).to eq([{ "token" => "at-1", "refreshToken" => "rt-1" }, { "token" => "at-2", "refreshToken" => "rt-2" }])
      expect { client.auth.refresh_token("rt-3") }.to raise_error(ArgumentError, /access_token/)
    end

    it "keeps only token acquisition" do
      %i[register get_profile update_profile change_password forgot_password reset_password verify_email].each do |name|
        expect(client.auth).not_to respond_to(name)
      end
    end
  end

  describe "legacy proxy" do
    let(:proxy) { "#{BASE_URL}/api/ApiProxy" }

    it "offers no order or inventory writes" do
      expect(client.orders).not_to respond_to(:create)
      expect(client.orders).not_to respond_to(:cancel)
      expect(client.inventory).not_to respond_to(:post_asn_receipt)
      expect(client.inventory).not_to respond_to(:update_inventory)
    end

    it "offers no carrier label generation (closed on the proxy) and no DHL pickup PATCH" do
      %i[create_domestic_label create_return_label create_international_label].each { |name| expect(client.carriers.usps).not_to respond_to(name) }
      expect(client.carriers.ups).not_to respond_to(:create_label)
      %i[create_shipment create_return_shipment].each { |name| expect(client.carriers.fedex).not_to respond_to(name) }
      expect(client.carriers.dhl).not_to respond_to(:create_shipment)
      expect(client.carriers.dhl).not_to respond_to(:update_pickup)
    end

    it "keeps the 1.x carrier writes on their VSCS paths with an Idempotency-Key" do
      rates = stub_request(:post, "#{proxy}/api/v3/RateCalculator/postRetrieveFedExRateAndTransitTimesAsync")
        .with(body: { accountNumber: "123" }.to_json, headers: { "Idempotency-Key" => /\A\h{8}-\h{4}-/ })
        .to_return(status: 200, body: "{}", headers: json_headers)
      cancel = stub_request(:put, "#{proxy}/api/v3/Shipping/putFedExCancelShipment").to_return(status: 200, body: "{}", headers: json_headers)
      pickup = stub_request(:delete, "#{proxy}/api/v3/CarrierPickup/cancelUspsCarrierPickupSchedule").to_return(status: 204)
      ups = stub_request(:post, "#{proxy}/api/v2/ShippingLabel/postUpsRateCheck").to_return(status: 200, body: "{}", headers: json_headers)
      dhl = stub_request(:post, "#{proxy}/api/v2/ShippingLabel/postDhlCreatePickup").to_return(status: 200, body: "{}", headers: json_headers)

      client.carriers.fedex.get_rates(accountNumber: "123")
      client.carriers.fedex.cancel_shipment(trackingNumber: "7946")
      expect(client.carriers.usps.cancel_pickup).to be_nil
      client.carriers.ups.get_rates({})
      client.carriers.dhl.create_pickup({})

      [rates, cancel, pickup, ups, dhl].each { |stub| expect(stub).to have_been_requested.once }
    end
  end

  describe "recurring_shipments" do
    let(:path) { "#{ws_path}/recurring-shipments" }
    let(:id) { "7d0f4c1e-2b1a-4f7e-9c55-1a2b3c4d5e6f" }
    let(:schedule) { { id: id, name: "Weekly restock", interval: 1, intervalName: "Weekly", isActive: true } }

    it "lists, reads, creates and updates schedules as bare JSON" do
      stub_request(:get, path).to_return(status: 200, body: [schedule].to_json, headers: json_headers)
      stub_request(:get, "#{path}/#{id}").to_return(status: 200, body: schedule.to_json, headers: json_headers)
      request = { name: "Weekly restock", addressId: "a-1", presetId: "p-1", interval: 1, firstRunUtc: "2026-11-02T14:00:00Z" }
      created = capture(:post, path, schedule)
      updated = capture(:put, "#{path}/#{id}", schedule.merge(interval: 3))

      expect(client.recurring_shipments.list).to eq([JSON.parse(schedule.to_json)])
      expect(client.recurring_shipments.get(id)["intervalName"]).to eq("Weekly")
      expect(client.recurring_shipments.create(request)["id"]).to eq(id)
      expect(client.recurring_shipments.update(id, { interval: 3 })["interval"]).to eq(3)
      expect(created).to eq([JSON.parse(request.to_json)])
      expect(updated).to eq([{ "interval" => 3 }])
    end

    it "deletes, pauses, resumes and triggers, each returning nil for the 204" do
      stubs = %w[pause resume trigger].map do |action|
        stub_request(:post, "#{path}/#{id}/#{action}").with { |req| req.body.to_s.empty? }.to_return(status: 204)
      end
      stubs << stub_request(:delete, "#{path}/#{id}").to_return(status: 204)

      expect(client.recurring_shipments.pause(id)).to be_nil
      expect(client.recurring_shipments.resume(id)).to be_nil
      expect(client.recurring_shipments.trigger(id)).to be_nil
      expect(client.recurring_shipments.delete(id)).to be_nil
      stubs.each { |stub| expect(stub).to have_been_requested.once }
    end

    it "sends the caller's Idempotency-Key with a trigger, which creates an order" do
      stub = stub_request(:post, "#{path}/#{id}/trigger")
        .with(headers: { "Idempotency-Key" => "restock-2026-11-02" }).to_return(status: 204)

      client.recurring_shipments.trigger(id, idempotency_key: "restock-2026-11-02")
      expect(stub).to have_been_requested.once
    end
  end

  describe "report_schedules" do
    let(:path) { "#{ws_path}/report-schedules" }
    let(:id) { "2c9e1d7a-4b3f-4e21-8a6d-0f1e2d3c4b5a" }
    let(:schedule) { { id: id, reportType: "shipments", format: 0, frequencyType: 1, timeOfDayUtc: "08:00:00", isEnabled: true } }

    def envelope(data, message: nil)
      { success: true, data: data, message: message }
    end

    it "returns the Gateway envelope from list, get, create, update and toggle" do
      stub_request(:get, path).to_return(status: 200, body: envelope([schedule]).to_json, headers: json_headers)
      stub_request(:get, "#{path}/#{id}").to_return(status: 200, body: envelope(schedule).to_json, headers: json_headers)
      request = { reportType: "shipments", format: 0, frequencyType: 1, dayOfWeek: 1, timeOfDayUtc: "08:00:00",
                  recipientEmails: "ops@example.com,cfo@example.com" }
      created = capture(:post, path, envelope(schedule))
      updated = capture(:put, "#{path}/#{id}", envelope(schedule.merge(format: 1), message: "Report schedule updated"))
      toggle = stub_request(:post, "#{path}/#{id}/toggle").with { |req| req.body.to_s.empty? }
        .to_return(status: 200, body: envelope(nil, message: "Report schedule toggled").to_json, headers: json_headers)

      expect(client.report_schedules.list["data"][0]["reportType"]).to eq("shipments")
      expect(client.report_schedules.get(id)["data"]["timeOfDayUtc"]).to eq("08:00:00")
      expect(client.report_schedules.create(request)["data"]["id"]).to eq(id)
      expect(client.report_schedules.update(id, { format: 1 })["data"]["format"]).to eq(1)
      expect(client.report_schedules.toggle(id)).to eq("success" => true, "data" => nil, "message" => "Report schedule toggled")
      expect(created).to eq([JSON.parse(request.to_json)])
      expect(updated).to eq([{ "format" => 1 }])
      expect(toggle).to have_been_requested.once
    end

    it "returns nil for the delete 204" do
      stub = stub_request(:delete, "#{path}/#{id}").to_return(status: 204)

      expect(client.report_schedules.delete(id)).to be_nil
      expect(stub).to have_been_requested.once
    end
  end

  describe "email_templates" do
    let(:path) { "#{ws_path}/email-templates" }
    let(:id) { "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d" }
    let(:template) do
      { id: id, eventType: 3, eventTypeName: "Delivered", subjectTemplate: "Delivered", htmlBodyTemplate: "<p>Hi</p>", isEnabled: true }
    end

    it "lists, reads and upserts templates as bare JSON on the email-templates route" do
      stub_request(:get, path).to_return(status: 200, body: [template].to_json, headers: json_headers)
      stub_request(:get, "#{path}/#{id}").to_return(status: 200, body: template.to_json, headers: json_headers)
      request = { eventType: 3, subjectTemplate: "Your order {{order_id}} arrived", htmlBodyTemplate: "<p>{{tracking_number}}</p>",
                  isEnabled: true }
      upserted = capture(:put, path, template)

      expect(client.email_templates.list[0]["eventTypeName"]).to eq("Delivered")
      expect(client.email_templates.get(id)["id"]).to eq(id)
      expect(client.email_templates.upsert(request)["eventType"]).to eq(3)
      expect(upserted).to eq([JSON.parse(request.to_json)])
      expect(client.email_templates).not_to respond_to(:create)
      expect(client.email_templates).not_to respond_to(:update)
    end

    it "previews a draft and returns nil for the delete 204" do
      previewed = capture(:post, "#{path}/preview", { renderedSubject: "Order ORD-12345", renderedHtmlBody: "<p>9400</p>" })
      deleted = stub_request(:delete, "#{path}/#{id}").to_return(status: 204)

      result = client.email_templates.preview(subject_template: "Order {{order_id}}", html_body_template: "<p>{{tracking_number}}</p>")
      expect(result).to eq("renderedSubject" => "Order ORD-12345", "renderedHtmlBody" => "<p>9400</p>")
      expect(previewed).to eq([{ "subjectTemplate" => "Order {{order_id}}", "htmlBodyTemplate" => "<p>{{tracking_number}}</p>" }])
      expect(client.email_templates.delete(id)).to be_nil
      expect(deleted).to have_been_requested.once
    end
  end
end
