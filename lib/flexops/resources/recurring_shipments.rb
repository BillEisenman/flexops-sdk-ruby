# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-31
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# frozen_string_literal: true

module FlexOps
  module Resources
    class RecurringShipments
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list(page: nil, page_size: nil, is_active: nil)
        query = { page: page, pageSize: page_size, isActive: is_active }.compact
        @http.get("#{ws_path}/recurring-shipments/", query: query.empty? ? nil : query)
      end

      def get(id)
        @http.get("#{ws_path}/recurring-shipments/#{id}")
      end

      def create(request)
        @http.post("#{ws_path}/recurring-shipments/", body: request)
      end

      def update(id, request)
        @http.put("#{ws_path}/recurring-shipments/#{id}", body: request)
      end

      def delete(id)
        @http.delete("#{ws_path}/recurring-shipments/#{id}")
      end

      def pause(id)
        @http.post("#{ws_path}/recurring-shipments/#{id}/pause")
      end

      def resume(id)
        @http.post("#{ws_path}/recurring-shipments/#{id}/resume")
      end

      def trigger(id)
        @http.post("#{ws_path}/recurring-shipments/#{id}/trigger")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
