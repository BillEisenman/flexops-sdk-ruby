# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Inventory
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
      end

      def post_asn_receipt(receipt)
        @http.post("#{PROXY}/api/v1/Inventory/postNewAsnReceipt", body: receipt)
      end

      def get_warehouse_snapshot(params = nil)
        @http.get("#{PROXY}/api/v1/Inventory/getWarehouseInventorySnapshot", query: params)
      end

      def get_complete_snapshot(params = nil)
        @http.get("#{PROXY}/api/v1/Inventory/getCompleteInventorySnapshot", query: params)
      end

      def get_part_numbers(params = nil)
        @http.get("#{PROXY}/api/v1/Inventory/getPartNumberList", query: params)
      end

      def update_inventory(data)
        @http.post("#{PROXY}/api/v2/Inventory/postCustomerInventoryUpdate", body: data)
      end
    end
  end
end
