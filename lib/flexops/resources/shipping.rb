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
        @http.post("#{ws_path}/shipping/rates", body: request)
      end

      def get_cheapest_rate(request)
        @http.post("#{ws_path}/shipping/rates/cheapest", body: request)
      end

      def get_fastest_rate(request)
        @http.post("#{ws_path}/shipping/rates/fastest", body: request)
      end

      def create_label(request)
        @http.post("#{ws_path}/shipping/labels", body: request)
      end

      def cancel_label(label_id)
        @http.delete("#{ws_path}/shipping/labels/#{label_id}")
      end

      def track(tracking_number)
        @http.get("#{ws_path}/shipping/track/#{tracking_number}")
      end

      def validate_address(address)
        @http.post("#{ws_path}/shipping/addresses/validate", body: address)
      end

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
    end
  end
end
