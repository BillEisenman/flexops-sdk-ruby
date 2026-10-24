# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Read-only inventory lookups through the legacy /api/ApiProxy passthrough
    # (/api/ApiProxy/api/v1/Inventory/...). With an API key, every method requires the
    # inventory:read permission; a key without it gets 403 API_KEY_SCOPE_REQUIRED. Keys created
    # with the default permissions include inventory:read. The proxy refuses writes from API keys.
    class Inventory
      PROXY = "/api/ApiProxy"

      def initialize(http)
        @http = http
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
    end
  end
end
