# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Wallet
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def get_balance
        @http.get("#{ws_path}/wallet/balance")
      end

      def add_funds(amount)
        @http.post("#{ws_path}/wallet/add-funds", body: { amount: amount })
      end

      def list_transactions(page: nil, page_size: nil, start_date: nil, end_date: nil)
        query = { page: page, pageSize: page_size, startDate: start_date, endDate: end_date }.compact
        @http.get("#{ws_path}/wallet/transactions", query: query.empty? ? nil : query)
      end

      def configure_auto_reload(enabled:, threshold: nil, amount: nil)
        @http.put("#{ws_path}/wallet/auto-reload", body: { enabled: enabled, threshold: threshold, amount: amount }.compact)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
