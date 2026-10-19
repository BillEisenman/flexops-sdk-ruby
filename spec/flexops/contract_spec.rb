# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# Every public resource method must call an operation the Developer Docs publish.
#
# spec/fixtures/gateway-operations.json is the sorted "METHOD /path" list from the Developer Docs
# OpenAPI snapshot (Docs/FlexOpsDeveloperDocs static/openapi/gateway.json, commit in "sourceCommit").
# Refresh it from that file when the Gateway's documented API changes.
module GatewayContract
  OPERATIONS_FILE = File.expand_path("../fixtures/gateway-operations.json", __dir__)
  PROXY_PREFIX = "/api/apiproxy/"
  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze

  # Label-generation suffixes the Gateway closes on the proxy (410 Gone in every environment;
  # ApiProxyLegacyRouteSemantics). Labels are bought with POST /api/shipping/labels.
  CLOSED_LABEL_SUFFIXES = %w[
    generateNewUpsShipLabel postNewShipLabelOrder postUspsGenerateDomesticShippingLabel
    postUspsGenerateDomesticReturnsShippingLabel postUspsGenerateInternationalShippingLabel
    postUspsGenerateDomesticIndiciaLabel postFedExCreateNewShipment postFedExCreateNewReturnShipment
    postDhlCreateShipment postOnTracCreateShipment postLsoCreateShipment postAusPostCreateShipment
    postCanadaPostCreateShipment postRoyalMailCreateShipment
  ].map(&:downcase).freeze

  # The only methods allowed to send a POST, PUT or DELETE through ApiProxy: the 1.x carrier
  # writes kept as deprecated, user-token-only calls (API keys get 403 API_KEY_SCOPE_REQUIRED).
  DEPRECATED_PROXY_WRITES = %w[
    FlexOps::Resources::UspsCarrier#get_domestic_rates
    FlexOps::Resources::UspsCarrier#get_domestic_products
    FlexOps::Resources::UspsCarrier#get_domestic_prices
    FlexOps::Resources::UspsCarrier#get_international_rates
    FlexOps::Resources::UspsCarrier#get_international_prices
    FlexOps::Resources::UspsCarrier#cancel_domestic_label
    FlexOps::Resources::UspsCarrier#cancel_international_label
    FlexOps::Resources::UspsCarrier#create_pickup
    FlexOps::Resources::UspsCarrier#cancel_pickup
    FlexOps::Resources::UspsCarrier#create_scan_form
    FlexOps::Resources::UpsCarrier#validate_address
    FlexOps::Resources::UpsCarrier#get_rates
    FlexOps::Resources::UpsCarrier#create_pickup
    FlexOps::Resources::UpsCarrier#cancel_pickup
    FlexOps::Resources::UpsCarrier#get_transit_times
    FlexOps::Resources::UpsCarrier#get_landed_cost
    FlexOps::Resources::UpsCarrier#search_locations
    FlexOps::Resources::UpsCarrier#upload_document
    FlexOps::Resources::UpsCarrier#create_freight_shipment
    FlexOps::Resources::UpsCarrier#get_freight_rate
    FlexOps::Resources::FedExCarrier#validate_address
    FlexOps::Resources::FedExCarrier#validate_postal_code
    FlexOps::Resources::FedExCarrier#get_rates
    FlexOps::Resources::FedExCarrier#cancel_shipment
    FlexOps::Resources::FedExCarrier#validate_shipment
    FlexOps::Resources::FedExCarrier#track
    FlexOps::Resources::FedExCarrier#track_multi_piece
    FlexOps::Resources::FedExCarrier#register_tracking_notification
    FlexOps::Resources::FedExCarrier#create_pickup
    FlexOps::Resources::FedExCarrier#cancel_pickup
    FlexOps::Resources::FedExCarrier#search_locations
    FlexOps::Resources::FedExCarrier#get_service_standards
    FlexOps::Resources::FedExCarrier#get_freight_rate
    FlexOps::Resources::FedExCarrier#create_freight_shipment
    FlexOps::Resources::FedExCarrier#ground_close
    FlexOps::Resources::FedExCarrier#upload_trade_documents
    FlexOps::Resources::FedExCarrier#create_open_shipment
    FlexOps::Resources::FedExCarrier#add_packages_to_open_shipment
    FlexOps::Resources::FedExCarrier#confirm_open_shipment
    FlexOps::Resources::DhlCarrier#get_multi_piece_rates
    FlexOps::Resources::DhlCarrier#create_pickup
    FlexOps::Resources::DhlCarrier#cancel_pickup
    FlexOps::Resources::DhlCarrier#calculate_landed_cost
    FlexOps::Resources::DhlCarrier#screen_shipment
    FlexOps::Resources::DhlCarrier#upload_invoice
  ].freeze

  # Dummy argument for each parameter name; anything else gets a string.
  DUMMIES = {
    request: {}, rule: {}, params: {}, address: {}, data: {},
    rules: ["rule-1"], role: :member, inspected_items: [], email: "a@example.com",
    declared_value: 10, claim_amount: 5, weight_lbs: 1.5, distance_miles: 100, auto_offset_enabled: true
  }.freeze

  # Optional keywords a method needs to get past its own argument checks.
  OPTIONAL_KEYWORDS = {
    "FlexOps::Resources::Shipping#cancel_label" => { carrier_code: "USPS" },
    "FlexOps::Resources::Auth#refresh_token" => { access_token: "at-1" }
  }.freeze

  def self.normalize(path)
    path.split("?").first.downcase.sub(%r{\A/api/v\d+(\.\d+)?/}, "/api/").chomp("/")
  end

  def self.proxy?(path)
    path.start_with?(PROXY_PREFIX)
  end

  def self.closed_label_path?(path)
    CLOSED_LABEL_SUFFIXES.any? { |suffix| path.downcase.end_with?(suffix) }
  end

  # True when the YARD comment block right above the method carries @deprecated.
  def self.deprecated?(entry)
    klass, name = entry.split("#")
    file, line = Object.const_get(klass).instance_method(name).source_location
    File.readlines(file)[0...(line - 1)].reverse.take_while { |l| l.strip.start_with?("#") }
        .any? { |l| l.include?("@deprecated") }
  end

  def self.documented
    @documented ||= JSON.parse(File.read(OPERATIONS_FILE))["operations"].map do |operation|
      verb, path = operation.split(" ", 2)
      [verb.upcase, normalize(path).split("/")]
    end
  end
end

RSpec.describe "Documented Gateway API contract" do
  def documented?(verb, path)
    # /api/ApiProxy/{**path} is a catch-all: any proxied path matches its documented verb.
    segments = path.split("/")
    segments = segments.first(3) + ["{path}"] if GatewayContract.proxy?(path)
    GatewayContract.documented.any? do |doc_verb, doc_segments|
      doc_verb == verb && doc_segments.length == segments.length &&
        doc_segments.zip(segments).all? { |doc, seg| doc.start_with?("{") || doc == seg }
    end
  end

  def call_with_dummies(resource, name)
    args = []
    kwargs = {}
    resource.method(name).parameters.each do |kind, param|
      value = GatewayContract::DUMMIES.fetch(param, "#{param}-1")
      case kind
      when :req then args << value
      when :keyreq then kwargs[param] = value
      end
    end
    kwargs.merge!(GatewayContract::OPTIONAL_KEYWORDS.fetch("#{resource.class}##{name}", {}))
    resource.public_send(name, *args, **kwargs)
  end

  # Calls every public method of +resource+, descending into nested resources (client.carriers.usps).
  def exercise(resource, calls, exercised)
    exercised[resource.class] ||= []
    resource.class.public_instance_methods(false).sort.each do |name|
      before = calls.length
      result = call_with_dummies(resource, name)
      if calls.length == before && result.class.name.to_s.start_with?("FlexOps::Resources::")
        exercise(result, calls, exercised)
      else
        exercised[resource.class] << [name, calls[before..]]
      end
    end
  end

  let(:client) { create_client }
  let(:calls) { [] }
  let(:exercised) { {} }

  before do
    allow_any_instance_of(FlexOps::HttpClient).to receive(:sleep)
    stub_request(:any, /localhost:5000/).to_return do |req|
      calls << [req.method.to_s.upcase, GatewayContract.normalize(req.uri.path)]
      { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } }
    end

    resources = FlexOps::Client.public_instance_methods(false).sort.filter_map do |name|
      next unless FlexOps::Client.instance_method(name).arity.zero?

      value = client.public_send(name)
      value if value.class.name.to_s.start_with?("FlexOps::Resources::")
    end
    resources.each { |resource| exercise(resource, calls, exercised) }
  end

  it "exercises every public method of every resource class with an HTTP call" do
    resource_classes = FlexOps::Resources.constants.map { |c| FlexOps::Resources.const_get(c) }.grep(Class)
    expect(exercised.keys).to match_array(resource_classes)

    silent = exercised.flat_map { |klass, methods| methods.select { |_, sent| sent.empty? }.map { |name, _| "#{klass}##{name}" } }
    expect(silent).to be_empty, "methods that sent no request: #{silent.join(", ")}"
  end

  it "calls only documented Gateway operations" do
    undocumented = calls.reject { |verb, path| documented?(verb, path) }.uniq
    expect(undocumented).to be_empty, "undocumented: #{undocumented.map { |c| c.join(" ") }.join(", ")}"
  end

  it "sends a write through the legacy ApiProxy only from the deprecated carrier allowlist" do
    proxy_writers = exercised.flat_map do |klass, methods|
      methods.select { |_, sent| sent.any? { |verb, path| GatewayContract.proxy?(path) && GatewayContract::WRITE_METHODS.include?(verb) } }
             .map { |name, _| "#{klass}##{name}" }
    end
    expect(proxy_writers).to match_array(GatewayContract::DEPRECATED_PROXY_WRITES)
  end

  it "marks every allowlisted proxy write @deprecated" do
    undeprecated = GatewayContract::DEPRECATED_PROXY_WRITES.reject { |entry| GatewayContract.deprecated?(entry) }
    expect(undeprecated).to be_empty, "missing @deprecated: #{undeprecated.join(", ")}"
  end

  it "never calls a label-generation route the Gateway closed on the proxy (410 Gone)" do
    closed = calls.select { |_, path| GatewayContract.proxy?(path) && GatewayContract.closed_label_path?(path) }
    expect(closed).to be_empty, "closed label routes: #{closed.map { |c| c.join(" ") }.join(", ")}"
  end

  it "sends no PATCH through the proxy, which has no PATCH route" do
    expect(calls.select { |verb, path| verb == "PATCH" && GatewayContract.proxy?(path) }).to be_empty
  end
end
