# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Shipping
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def get_rates(request)
        @http.post("/api/shipping/rates", body: request)
      end

      def get_cheapest_rate(request)
        @http.post("/api/shipping/rates/cheapest", body: request)
      end

      def get_fastest_rate(request)
        @http.post("/api/shipping/rates/fastest", body: request)
      end

      # Returns a raw preview or label; confirmation always belongs to the caller.
      # A label without an orderId must declare hazmatClassification (a HazmatClassification;
      # HazmatClassification::NONE for an ordinary parcel). The SDK never fills it in.
      def create_label(request = {}, idempotency_key: nil, **fields)
        request = request.merge(fields)
        @http.post("/api/shipping/labels", body: request,
                   headers: idempotency_key.nil? ? {} : { "Idempotency-Key" => idempotency_key })
      end

      def cancel_label(label_id)
        @http.delete("#{ws_path}/shipping/labels/#{label_id}")
      end

      def track(tracking_number)
        @http.get("#{ws_path}/shipping/track/#{tracking_number}")
      end

      # Sends the Gateway AddressValidationRequest ({ address: {...} }). A legacy
      # street1/state/zip address is mapped to the Gateway field names.
      def validate_address(address)
        @http.post("/api/shipping/addresses/validate", body: { address: to_shipping_address(address) })
      end

      # The payload is sent as given. Set hazmatClassification on an item only when you have a declaration.
      def create_batch(request)
        @http.post("#{ws_path}/labels/batch", body: request)
      end

      def preview_batch(request)
        @http.post("#{ws_path}/labels/batch/preview", body: request)
      end

      def get_batch_status(job_id)
        @http.get("#{ws_path}/labels/batch/#{job_id}")
      end

      def download_batch_label(job_id, item_id)
        @http.get("#{ws_path}/labels/batch/#{job_id}/items/#{item_id}/label")
      end

      def get_carriers
        @http.get("#{ws_path}/shipping/carriers")
      end

      def get_recommendations(request)
        @http.post("#{ws_path}/shipping/recommendations", body: request)
      end

      def predict_delivery(request)
        @http.post("#{ws_path}/shipping/predictions/delivery", body: request)
      end

      def get_savings
        @http.get("#{ws_path}/shipping/savings")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end

      LEGACY_ADDRESS_FIELDS = {
        "street1" => "addressLine1",
        "street2" => "addressLine2",
        "state" => "stateProvince",
        "zip" => "postalCode",
        "country" => "countryCode"
      }.freeze

      # Maps an address to the Gateway ShippingAddress; canonical input passes through.
      def to_shipping_address(address)
        return address unless address.key?(:street1) || address.key?("street1")

        address.each_with_object({}) do |(key, value), mapped|
          mapped[LEGACY_ADDRESS_FIELDS.fetch(key.to_s, key.to_s)] = value unless value.nil?
        end
      end
    end
  end
end
