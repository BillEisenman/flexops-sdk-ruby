# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
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

    class UspsCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def validate_address(params) = @http.get("#{PROXY}/api/v3/AddressValidation/getUspsValidateAndCorrectAddress", query: params)
      def city_state_lookup(zip_code) = @http.get("#{PROXY}/api/v3/AddressValidation/getUspsCityStateLookupByZipCode", query: { zipCode: zip_code })
      def zip_code_lookup(params) = @http.get("#{PROXY}/api/v3/AddressValidation/getUspsZipCodeLookupByAddress", query: params)
      def get_domestic_rates(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchDomesticBaseRates", body: body)
      def get_domestic_products(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchEligibleDomesticProducts", body: body)
      def get_domestic_prices(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchEligibleDomesticPrices", body: body)
      def get_international_rates(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchInternationalBaseRates", body: body)
      def get_international_prices(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postUspsSearchEligibleInternationalPrices", body: body)
      def create_domestic_label(body) = @http.post("#{PROXY}/api/v3/Shipping/postUspsGenerateDomesticShippingLabel", body: body)
      def create_return_label(body) = @http.post("#{PROXY}/api/v3/Shipping/postUspsGenerateDomesticReturnsShippingLabel", body: body)
      def create_international_label(body) = @http.post("#{PROXY}/api/v3/Shipping/postUspsGenerateInternationalShippingLabel", body: body)
      def cancel_domestic_label = @http.delete("#{PROXY}/api/v3/Shipping/cancelUspsDomesticShipmentLabel")
      def cancel_international_label = @http.delete("#{PROXY}/api/v3/Shipping/cancelUspsInternationalShipmentLabel")
      def track_summary(params) = @http.get("#{PROXY}/api/v3/Tracking/getUspsTrackingSummaryInformation", query: params)
      def track_detail(params) = @http.get("#{PROXY}/api/v3/Tracking/getUspsTrackingDetailInformation", query: params)
      def create_pickup(body) = @http.post("#{PROXY}/api/v3/CarrierPickup/postUspsCreateCarrierPickupSchedule", body: body)
      def cancel_pickup = @http.delete("#{PROXY}/api/v3/CarrierPickup/cancelUspsCarrierPickupSchedule")
      def create_scan_form(body) = @http.post("#{PROXY}/api/v3/ScanForm/postUspsCreateScanFormLabelShipment", body: body)
      def delivery_standards(params) = @http.get("#{PROXY}/api/v3/ServiceStandards/getUspsGetDeliveryStandardsEstimates", query: params)
      def find_drop_off_locations(params) = @http.get("#{PROXY}/api/v3/LocationSearch/getUspsFindValidDropOffLocations", query: params)
      def find_post_offices(params) = @http.get("#{PROXY}/api/v3/LocationSearch/getUspsFindValidPostOfficeLocations", query: params)
    end

    class UpsCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def validate_address(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsVerifyAddress", body: body)
      def get_rates(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsRateCheck", body: body)
      def create_label(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/generateNewUpsShipLabel", body: body)
      def track(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getSingleUpsTrackingDetail", query: params)
      def create_pickup(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsCreatePickup", body: body)
      def cancel_pickup = @http.delete("#{PROXY}/api/v2/ShippingLabel/deleteUpsPickup")
      def get_transit_times(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsGetTransitTimes", body: body)
      def get_landed_cost(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsGetLandedCostQuote", body: body)
      def search_locations(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsSearchLocations", body: body)
      def upload_document(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsUploadPaperlessDocument", body: body)
      def create_freight_shipment(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsCreateFreightShipment", body: body)
      def get_freight_rate(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postUpsGetFreightRate", body: body)
    end

    class FedExCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def validate_address(body) = @http.post("#{PROXY}/api/v3/AddressValidation/postFedExValidateAndCorrectDomesticAddress", body: body)
      def validate_postal_code(body) = @http.post("#{PROXY}/api/v3/AddressValidation/postFedExValidatePostalCode", body: body)
      def get_rates(body) = @http.post("#{PROXY}/api/v3/RateCalculator/postRetrieveFedExRateAndTransitTimesAsync", body: body)
      def create_shipment(body) = @http.post("#{PROXY}/api/v3/Shipping/postFedExCreateNewShipment", body: body)
      def cancel_shipment(body) = @http.put("#{PROXY}/api/v3/Shipping/putFedExCancelShipment", body: body)
      def validate_shipment(body) = @http.post("#{PROXY}/api/v3/Shipping/postFedExValidateShipment", body: body)
      def create_return_shipment(body) = @http.post("#{PROXY}/api/v3/Shipping/postFedExCreateNewReturnShipment", body: body)
      def track(body) = @http.post("#{PROXY}/api/v3/Tracking/postFedExRetrieveTrackingInfoByTrackingNumber", body: body)
      def track_multi_piece(body) = @http.post("#{PROXY}/api/v3/Tracking/postFedExRetrieveTrackingInfoForMultiPieceShipment", body: body)
      def register_tracking_notification(body) = @http.post("#{PROXY}/api/v3/Tracking/postFedExRegisterForTrackingNotification", body: body)
      def create_pickup(body) = @http.post("#{PROXY}/api/v3/CarrierPickup/postFedExCreateCarrierPickupRequest", body: body)
      def cancel_pickup(body) = @http.put("#{PROXY}/api/v3/CarrierPickup/putFedExCancelCarrierPickupRequest", body: body)
      def search_locations(body) = @http.post("#{PROXY}/api/v3/LocationSearch/postFedExSearchValidLocations", body: body)
      def get_service_standards(body) = @http.post("#{PROXY}/api/v3/ServiceStandards/postFedExRetrieveServicesAndTransitTimes", body: body)
      def get_freight_rate(body) = @http.post("#{PROXY}/api/v3/Freight/postFedExGetFreightRateQuote", body: body)
      def create_freight_shipment(body) = @http.post("#{PROXY}/api/v3/Freight/postFedExCreateFreightShipment", body: body)
      def ground_close(body) = @http.post("#{PROXY}/api/v3/GroundClose/postFedExCloseWithDocuments", body: body)
      def upload_trade_documents(body) = @http.post("#{PROXY}/api/v3/Trade/postFedExUploadTradeDocuments", body: body)
      def create_open_shipment(body) = @http.post("#{PROXY}/api/v3/OpenShip/postFedExCreateOpenShipment", body: body)
      def add_packages_to_open_shipment(body) = @http.post("#{PROXY}/api/v3/OpenShip/postFedExAddPackagesToOpenShipment", body: body)
      def confirm_open_shipment(body) = @http.post("#{PROXY}/api/v3/OpenShip/postFedExConfirmOpenShipment", body: body)
    end

    class DhlCarrier
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def validate_address(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlValidateAddress", query: params)
      def get_rates(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlRates", query: params)
      def get_multi_piece_rates(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlMultiPieceRates", body: body)
      def get_products(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlProducts", query: params)
      def create_shipment(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlCreateShipment", body: body)
      def track(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlTrackSingleShipment", query: params)
      def track_multiple(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlTrackMultipleShipments", query: params)
      def create_pickup(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlCreatePickup", body: body)
      def update_pickup(body) = @http.patch("#{PROXY}/api/v2/ShippingLabel/patchDhlUpdatePickup", body: body)
      def cancel_pickup = @http.delete("#{PROXY}/api/v2/ShippingLabel/deleteDhlPickup")
      def calculate_landed_cost(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlCalculateLandedCost", body: body)
      def screen_shipment(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlScreenShipment", body: body)
      def upload_invoice(body) = @http.post("#{PROXY}/api/v2/ShippingLabel/postDhlUploadInvoice", body: body)
      def get_proof_of_delivery(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlElectronicProofOfDelivery", query: params)
      def get_reference_data(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlReferenceData", query: params)
      def find_service_points(params) = @http.get("#{PROXY}/api/v2/ShippingLabel/getDhlServicePoints", query: params)
    end
  end
end
