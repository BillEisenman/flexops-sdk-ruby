# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Returns
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list(page: nil, page_size: nil, start_date: nil, end_date: nil)
        query = { page: page, pageSize: page_size, startDate: start_date, endDate: end_date }.compact
        @http.get("#{ws_path}/returns", query: query.empty? ? nil : query)
      end

      def get(return_id)
        @http.get("#{ws_path}/returns/#{return_id}")
      end

      # Creates an RMA and returns the enveloped RMA (201).
      #
      # request:: { orderId: (a number), orderNumber: (optional), reason:,
      #           items: [{ sku:, quantity:, reason: (optional) }], notes: (optional),
      #           customerEmail: (optional), reasonId: (optional) }
      def create(request)
        @http.post("#{ws_path}/returns/rma", body: request)
      end

      # Generates a return label for an RMA.
      #
      # The carrier needs the package weight and all three dimensions: pass weight_oz, length_in,
      # width_in and height_in. Anything left out comes from the workspace's default shipping
      # preset; with no preset the Gateway answers 400 PackageMeasurementsRequired naming the
      # missing fields.
      #
      # Only what you set is sent; the Gateway uses "usps" when carrier_code is left out.
      # hazmat_classification (a HazmatClassification) declares what the return holds.
      def generate_label(rma_number, weight_oz: nil, length_in: nil, width_in: nil, height_in: nil,
                         carrier_code: nil, service_type: nil, payment_confirmed: nil, hazmat_classification: nil,
                         rate_indicator: nil)
        # Always a JSON object: the Gateway binds a required GenerateReturnLabelRequest body and refuses an empty one with 400.
        body = {
          carrierCode: carrier_code, serviceType: service_type, weightOz: weight_oz, lengthIn: length_in,
          widthIn: width_in, heightIn: height_in, paymentConfirmed: payment_confirmed,
          hazmatClassification: hazmat_classification, rateIndicator: rate_indicator
        }.compact
        @http.post("#{ws_path}/returns/#{rma_number}/label", body: body)
      end

      # Records the inspected items of a received RMA.
      #
      # rma_id::          the numeric RMA id (the route segment)
      # rma_number::      the RMA number, for example "RMA-1001"
      # inspected_items:: [{ partNumber:, partDescription: (optional), quantity:,
      #                   disposition: 0 restock, 1 dispose or 2 forward, inspectionNotes: (optional) }]
      # warehouse_id::    the receiving warehouse; the Gateway uses 1 when it is left out
      def mark_received(rma_id, rma_number:, inspected_items:, warehouse_id: nil)
        body = { rmaNumber: rma_number, warehouseId: warehouse_id, inspectedItems: inspected_items }.compact
        @http.post("#{ws_path}/returns/#{rma_id}/receive", body: body)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
