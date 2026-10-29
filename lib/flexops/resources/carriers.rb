# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Carrier-specific calls through the legacy /api/ApiProxy passthrough (sunset 2027-06-30).
    # Lookups (GET) work with a user token, or an API key that has the permission for the data
    # they read: address, ZIP, city, location, service point and reference lookups require
    # shipping:read; tracking and proof of delivery require tracking:read; delivery standards,
    # rates and products require rates:read. A key without the permission gets 403
    # API_KEY_SCOPE_REQUIRED; keys created with the default permissions have all three.
    # The writes (POST/PUT/DELETE) are
    # deprecated and need a user token (auth.login): the Gateway refuses API-key writes on the
    # proxy with 403 API_KEY_SCOPE_REQUIRED. Label generation through the proxy is closed (410 Gone);
    # buy, cancel and schedule through client.shipping, client.pickups and client.scan_forms.
    class Carriers
      attr_reader :usps, :ups, :fedex, :dhl

      def initialize(http)
        @http = http
        @usps = UspsCarrier.new(http)
        @ups = UpsCarrier.new(http)
        @fedex = FedExCarrier.new(http)
        @dhl = DhlCarrier.new(http)
      end
    end

    # USPS through the legacy proxy. With an API key, the address, ZIP, city and location lookups
    # require shipping:read, tracking requires tracking:read and delivery standards require
    # rates:read.
    class UspsCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def validate_address(params) = @http.get("#{PROXY}/api/v3/AddressValidation/getUspsValidateAndCorrectAddress", query: params)
      def city_state_lookup(zip_code) = @http.get("#{PROXY}/api/v3/AddressValidation/getUspsCityStateLookupByZipCode", query: { zipCode: zip_code })
      def zip_code_lookup(params) = @http.get("#{PROXY}/api/v3/AddressValidation/getUspsZipCodeLookupByAddress", query: params)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_domestic_rates(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchDomesticBaseRates", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_domestic_products(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchEligibleDomesticProducts", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_domestic_prices(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchEligibleDomesticPrices", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_international_rates(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchInternationalBaseRates", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_international_prices(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchEligibleInternationalPrices", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_domestic_label(tracking_number) = cancel("/api/v3/Shipping/cancelUspsDomesticShipmentLabel", "trackingNumber", tracking_number)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_international_label(international_tracking_number)
        cancel("/api/v3/Shipping/cancelUspsInternationalShipmentLabel", "internationalTrackingNumber", international_tracking_number)
      end
      def track_summary(params) = @http.get("#{PROXY}/api/v3/Tracking/getUspsTrackingSummaryInformation", query: params)
      def track_detail(params) = @http.get("#{PROXY}/api/v3/Tracking/getUspsTrackingDetailInformation", query: params)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_pickup(body) = @http.post("#{PROXY}/api/v3/CarrierPickup/postUspsCreateCarrierPickupSchedule", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_pickup(confirmation_number) = cancel("/api/v3/CarrierPickup/cancelUspsCarrierPickupSchedule", "confirmationNumber", confirmation_number)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_scan_form(body) = @http.post("#{PROXY}/api/v3/ScanForm/postUspsCreateScanFormLabelShipment", body: body)
      def delivery_standards(params) = @http.get("#{PROXY}/api/v3/ServiceStandards/getUspsGetDeliveryStandardsEstimates", query: params)
      def find_drop_off_locations(params) = @http.get("#{PROXY}/api/v3/LocationSearch/getUspsFindValidDropOffLocations", query: params)
      def find_post_offices(params) = @http.get("#{PROXY}/api/v3/LocationSearch/getUspsFindValidPostOfficeLocations", query: params)

      private

      # Sends a USPS cancel with what it cancels in the query string; without it VSCS answers 400.
      def cancel(path, param, value)
        raise ArgumentError, "#{param} is required." if value.to_s.strip.empty?

        @http.delete("#{PROXY}#{path}", query: { param => value })
      end
    end

    # UPS through the legacy proxy. With an API key, track requires tracking:read.
    class UpsCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def validate_address(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsVerifyAddress", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_rates(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsRateCheck", body: body)
      def track(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getSingleUpsTrackingDetail", query: params)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_pickup(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsCreatePickup", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_pickup = @http.delete("#{PROXY}/api/v2/ShippingLabel/deleteUpsPickup")
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_transit_times(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsGetTransitTimes", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_landed_cost(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsGetLandedCostQuote", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def search_locations(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsSearchLocations", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def upload_document(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsUploadPaperlessDocument", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_freight_shipment(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsCreateFreightShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_freight_rate(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsGetFreightRate", body: body)
    end

    class FedExCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def validate_address(body) = @http.post("#{PROXY}/api/v3/AddressValidation/postFedExValidateAndCorrectDomesticAddress", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def validate_postal_code(body) = @http.post("#{PROXY}/api/v3/AddressValidation/postFedExValidatePostalCode", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_rates(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postRetrieveFedExRateAndTransitTimesAsync", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_shipment(body) = @http.put("#{PROXY}/api/v3/Shipping/putFedExCancelShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def validate_shipment(body) = @http.post("#{PROXY}/api/v3/Shipping/postFedExValidateShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def track(body) = @http.post("#{PROXY}/api/v3/Tracking/postFedExRetrieveTrackingInfoByTrackingNumber", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def track_multi_piece(body) = @http.post("#{PROXY}/api/v3/Tracking/postFedExRetrieveTrackingInfoForMultiPieceShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def register_tracking_notification(body) = @http.post("#{PROXY}/api/v3/Tracking/postFedExRegisterForTrackingNotification", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_pickup(body) = @http.post("#{PROXY}/api/v3/CarrierPickup/postFedExCreateCarrierPickupRequest", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_pickup(body) = @http.put("#{PROXY}/api/v3/CarrierPickup/putFedExCancelCarrierPickupRequest", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def search_locations(body) = @http.post("#{PROXY}/api/v3/LocationSearch/postFedExSearchValidLocations", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_service_standards(body) = @http.post("#{PROXY}/api/v3/ServiceStandards/postFedExRetrieveServicesAndTransitTimes", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_freight_rate(body) = @http.post("#{PROXY}/api/v3/Freight/postFedExGetFreightRateQuote", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_freight_shipment(body) = @http.post("#{PROXY}/api/v3/Freight/postFedExCreateFreightShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def ground_close(body) = @http.post("#{PROXY}/api/v3/GroundClose/postFedExCloseWithDocuments", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def upload_trade_documents(body) = @http.post("#{PROXY}/api/v3/Trade/postFedExUploadTradeDocuments", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_open_shipment(body) = @http.post("#{PROXY}/api/v3/OpenShip/postFedExCreateOpenShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def add_packages_to_open_shipment(body) = @http.post("#{PROXY}/api/v3/OpenShip/postFedExAddPackagesToOpenShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def confirm_open_shipment(body) = @http.post("#{PROXY}/api/v3/OpenShip/postFedExConfirmOpenShipment", body: body)
    end

    # DHL through the legacy proxy. With an API key, address validation, service points and
    # reference data require shipping:read; tracking and proof of delivery require
    # tracking:read; rates and products require rates:read.
    class DhlCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def validate_address(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlValidateAddress", query: params)
      def get_rates(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlRates", query: params)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def get_multi_piece_rates(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlMultiPieceRates", body: body)
      def get_products(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlProducts", query: params)
      def track(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlTrackSingleShipment", query: params)
      def track_multiple(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlTrackMultipleShipments", query: params)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def create_pickup(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlCreatePickup", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def cancel_pickup = @http.delete("#{PROXY}/api/v2/ShippingLabel/deleteDhlPickup")
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def calculate_landed_cost(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlCalculateLandedCost", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def screen_shipment(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlScreenShipment", body: body)
      # @deprecated Legacy carrier proxy (sunset 2027-06-30). Needs a user token: API keys get 403
      #   API_KEY_SCOPE_REQUIRED. Use client.shipping / client.pickups / client.scan_forms where they cover this.
      def upload_invoice(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlUploadInvoice", body: body)
      def get_proof_of_delivery(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlElectronicProofOfDelivery", query: params)
      def get_reference_data(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlReferenceData", query: params)
      def find_service_points(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlServicePoints", query: params)
    end
  end
end
