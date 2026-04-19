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

      def list(page: nil, page_size: nil, status: nil)
        query = { page: page, pageSize: page_size, status: status }.compact
        @http.get("#{ws_path}/returns", query: query.empty? ? nil : query)
      end

      def get(return_id)
        @http.get("#{ws_path}/returns/#{return_id}")
      end

      def create(request)
        @http.post("#{ws_path}/returns", body: request)
      end

      def approve(return_id)
        @http.post("#{ws_path}/returns/#{return_id}/approve")
      end

      def reject(return_id, reason)
        @http.post("#{ws_path}/returns/#{return_id}/reject", body: { reason: reason })
      end

      def cancel(return_id)
        @http.post("#{ws_path}/returns/#{return_id}/cancel")
      end

      def generate_label(return_id)
        @http.post("#{ws_path}/returns/#{return_id}/label")
      end

      def mark_received(return_id, items)
        @http.post("#{ws_path}/returns/#{return_id}/receive", body: { items: items })
      end

      def process_refund(return_id)
        @http.post("#{ws_path}/returns/#{return_id}/refund")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
