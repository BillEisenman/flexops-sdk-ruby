# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "erb"

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

      # The Gateway requires the carrier code (for example "USPS"). It is a keyword with no
      # default value so older call sites fail with a clear ArgumentError before any request.
      def cancel_label(label_id, carrier_code: nil)
        raise ArgumentError, "carrier_code is required to cancel a label (for example \"USPS\")" if carrier_code.to_s.empty?

        @http.delete("/api/shipping/labels/#{escape(label_id)}?carrierCode=#{escape(carrier_code)}")
      end

      def track(tracking_number)
        @http.get("/api/shipping/track/#{escape(tracking_number)}")
      end

      # Validates an address with POST /api/addresses/validate and returns the bare result
      # ("isValid", "validationUnavailable", "suggestedAddress", "isResidential", "warnings",
      # "validatedBy", "checkedAt").
      #
      # The address may use the rate and label field names (addressLine1, stateProvince,
      # countryCode, ...), the legacy street1/state/zip names, or the Gateway's own
      # (line1, line2, city, state, postalCode, country). Only those fields and name are sent.
      def validate_address(address)
        @http.post("/api/addresses/validate", body: to_validation_address(address))
      end

      # Buys labels for one order shipped in 1 to 99 boxes with the same carrier and service
      # (POST /api/shipping/multi-package, the Gateway MultiPackageShipmentRequest):
      #
      #   { orderId: 12345, carrierCode: "USPS", serviceCode: (optional), labelFormat: (optional),
      #     shipDate: (optional), hazmatClassification: (optional), maximumPostageAmount: 25.00,
      #     packages: [{ weightInOunces:, lengthInInches:, widthInInches:, heightInInches:,
      #                  deliveryConfirmationRequired: (optional), signatureConfirmationRequired: (optional),
      #                  insuranceCoverageRequested: (optional), insuredValue: (optional),
      #                  packageReference: (optional) }] }
      #
      # maximumPostageAmount is required: the most the whole shipment may cost, in USD (positive, at most
      # two decimals). The Gateway refuses to buy a box that would take the total above it, so you never
      # pay more: a box priced above what is left reports PriceCeilingExceeded, and once the amount is
      # used up the remaining boxes report PriceCeilingReached and are not bought. Boxes already bought
      # stay bought. A missing or invalid value is 400 ApprovalRequired.
      #
      # Weight is in ounces and every dimension in inches; all four are required. Multi-package
      # labels cannot carry HAZMAT yet: send HazmatClassification::NONE or leave hazmatClassification
      # out (any other class is refused with 400 HazmatNotSupported).
      #
      # Returns the envelope when at least one label was bought (check data["failedPackages"] and
      # each box in data["labels"]). When none was, the Gateway answers 422 AllPackagesFailed, or 409
      # OutcomeUnknown when a box's carrier outcome is unknown and a label may exist: both raise
      # FlexOps::Error whose data holds the per-box results. After OutcomeUnknown, check the order
      # before buying again. Pass your own idempotency_key (and reuse it) to make a retry you run
      # yourself safe.
      def create_multi_package(request, idempotency_key: nil)
        @http.post("/api/shipping/multi-package", body: request,
                   headers: idempotency_key.nil? ? {} : { "Idempotency-Key" => idempotency_key })
      end

      # The payload is sent as given. Set hazmatClassification on an item only when you have a declaration.
      # Batch labels cannot carry HAZMAT yet: send HazmatClassification::NONE or leave hazmatClassification
      # out (any other class is refused with 400 HazmatNotSupported). Buy HAZMAT labels one at a time
      # with create_label.
      def create_batch(request)
        @http.post("#{ws_path}/labels/batch", body: request)
      end

      # Previews a batch without buying labels. The payload is sent as given; as with create_batch, an
      # item's hazmatClassification accepts only HazmatClassification::NONE or nothing (any other class
      # is refused with 400 HazmatNotSupported).
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
        @http.get("/api/shipping/carriers")
      end

      def get_recommendations(request)
        @http.post("/api/shipping/recommendations", body: request)
      end

      def predict_delivery(request)
        @http.post("/api/shipping/predictions/delivery", body: request)
      end

      def get_savings
        @http.get("/api/shipping/savings")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end

      def escape(segment)
        ERB::Util.url_encode(segment.to_s)
      end

      # Gateway AddressValidationRequest field for each accepted address field name.
      VALIDATION_ADDRESS_FIELDS = {
        "name" => "name",
        "line1" => "line1", "addressLine1" => "line1", "street1" => "line1",
        "line2" => "line2", "addressLine2" => "line2", "street2" => "line2",
        "city" => "city",
        "state" => "state", "stateProvince" => "state",
        "postalCode" => "postalCode", "zip" => "postalCode",
        "country" => "country", "countryCode" => "country"
      }.freeze

      def to_validation_address(address)
        address.each_with_object({}) do |(key, value), mapped|
          field = VALIDATION_ADDRESS_FIELDS[key.to_s]
          mapped[field] = value unless field.nil? || value.nil?
        end
      end
    end
  end
end
