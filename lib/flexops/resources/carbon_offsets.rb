# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Carbon offsets for shipments. Answers use the { success, data, message, errorCode } envelope.
    class CarbonOffsets
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def quote(weight_lbs:, distance_miles:)
        @http.post("#{ws_path}/quote", body: { weightLbs: weight_lbs, distanceMiles: distance_miles })
      end

      # Buys an offset for a shipment and debits the workspace wallet.
      # Pass an idempotency_key you store with the purchase to make your own retry safe: after an
      # error or a timeout, retry with the same key and the Gateway returns the first result instead
      # of buying again. Without one, the SDK's own retries still share a key, but a new call gets a new key.
      def purchase(tracking_number:, weight_lbs:, distance_miles:, idempotency_key: nil)
        @http.post("#{ws_path}/purchase",
                   body: { trackingNumber: tracking_number, weightLbs: weight_lbs, distanceMiles: distance_miles },
                   headers: idempotency_key.nil? ? {} : { "Idempotency-Key" => idempotency_key })
      end

      def list(page: nil, page_size: nil)
        query = { page: page, pageSize: page_size }.compact
        @http.get(ws_path, query: query.empty? ? nil : query)
      end

      def get(offset_id)
        @http.get("#{ws_path}/#{offset_id}")
      end

      def summary
        @http.get("#{ws_path}/summary")
      end

      def get_settings
        @http.get("#{ws_path}/settings")
      end

      def update_settings(auto_offset_enabled:)
        @http.put("#{ws_path}/settings", body: { autoOffsetEnabled: auto_offset_enabled })
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}/carbon-offsets"
      end
    end
  end
end
