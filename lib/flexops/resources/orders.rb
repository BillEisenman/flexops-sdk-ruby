# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Read-only order lookups through the legacy /api/ApiProxy passthrough
    # (/api/ApiProxy/api/v1/Order/...). With an API key, every method requires the orders:read
    # permission; a key without it gets 403 API_KEY_SCOPE_REQUIRED. Keys created with the default
    # permissions include orders:read. The proxy refuses writes from API keys.
    class Orders
      BASE = "/api/ApiProxy/api/v1/Order"

      def initialize(http)
        @http = http
      end

      def get_new_orders(params = nil)
        @http.get("#{BASE}/getNewOrderList", query: params)
      end

      def get_by_status(params = nil)
        @http.get("#{BASE}/getAllOrderListByStatus", query: params)
      end

      def get_details(order_number)
        @http.get("#{BASE}/getCompleteOrderDetailsByOrderNumber", query: { orderNumber: order_number })
      end

      def get_extended_details(order_number)
        @http.get("#{BASE}/getExtendedOrderDetailsByOrderNumber", query: { orderNumber: order_number })
      end

      def get_status(order_number)
        @http.get("#{BASE}/getIndividualOrderStatusByOrderNumber", query: { orderNumber: order_number })
      end

      def get_items(order_number)
        @http.get("#{BASE}/getAllOrderItemsByOrderNumber", query: { orderNumber: order_number })
      end

      def get_ship_methods
        @http.get("#{BASE}/getAvailableShipMethodsList")
      end

      def get_warehouses
        @http.get("#{BASE}/getActiveWarehouseList")
      end

      def get_country_codes
        @http.get("#{BASE}/getCountryNameCodeList")
      end

      def get_status_types
        @http.get("#{BASE}/getOrderStatusTypesList")
      end
    end
  end
end
