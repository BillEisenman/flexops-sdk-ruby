# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Analytics through the legacy /api/ApiProxy passthrough (/api/ApiProxy/api/v4/Analytics/...).
    # With an API key, each method requires the permission for the data it reads, named on the
    # method: shipping:read for shipment, carrier and delivery metrics, inventory:read for
    # inventory metrics, orders:read for order metrics and returns:read for returns metrics. A
    # key without it gets 403 API_KEY_SCOPE_REQUIRED. Keys created with the default permissions
    # have all four.
    class Analytics
      BASE = "/api/ApiProxy/api/v4/Analytics"

      def initialize(http)
        @http = http
      end

      # Shipments trend over time. With an API key, requires shipping:read.
      def shipments_trend(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ShipmentsTrend", query: date_query(start_date, end_date))
      end

      # Carrier usage summary. With an API key, requires shipping:read.
      def carrier_summary(start_date: nil, end_date: nil)
        @http.get("#{BASE}/CarrierSummary", query: date_query(start_date, end_date))
      end

      # Top shipping destinations. With an API key, requires shipping:read.
      def top_destinations(start_date: nil, end_date: nil, limit: nil)
        @http.get("#{BASE}/TopDestinations", query: date_query(start_date, end_date).merge(limit: limit).compact)
      end

      # Inventory metrics (stock levels, low-stock alerts). With an API key, requires inventory:read.
      def inventory_metrics
        @http.get("#{BASE}/InventoryMetrics")
      end

      # Stock levels by warehouse. With an API key, requires inventory:read.
      def stock_by_warehouse
        @http.get("#{BASE}/StockByWarehouse")
      end

      # Order metrics (volume, revenue). With an API key, requires orders:read.
      def order_metrics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/OrderMetrics", query: date_query(start_date, end_date))
      end

      # Order trend over time. With an API key, requires orders:read.
      def order_trend(start_date: nil, end_date: nil)
        @http.get("#{BASE}/OrderTrend", query: date_query(start_date, end_date))
      end

      # Top selling products. With an API key, requires orders:read.
      def top_selling_products(start_date: nil, end_date: nil, limit: nil)
        @http.get("#{BASE}/TopSellingProducts", query: date_query(start_date, end_date).merge(limit: limit).compact)
      end

      # Returns metrics. With an API key, requires returns:read.
      def returns_metrics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ReturnsMetrics", query: date_query(start_date, end_date))
      end

      # Returns trend over time. With an API key, requires returns:read.
      def returns_trend(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ReturnsTrend", query: date_query(start_date, end_date))
      end

      # Return reasons breakdown. With an API key, requires returns:read.
      def return_reasons(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ReturnReasons", query: date_query(start_date, end_date))
      end

      # Fulfillment performance metrics. With an API key, requires shipping:read.
      def performance_metrics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/PerformanceMetrics", query: date_query(start_date, end_date))
      end

      # Carrier delivery performance. With an API key, requires shipping:read.
      def carrier_performance(start_date: nil, end_date: nil)
        @http.get("#{BASE}/CarrierPerformance", query: date_query(start_date, end_date))
      end

      # Shipping cost analytics. With an API key, requires shipping:read.
      def shipping_cost_analytics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ShippingCostAnalytics", query: date_query(start_date, end_date))
      end

      # Delivery performance (on-time percentage). With an API key, requires shipping:read.
      def delivery_performance(start_date: nil, end_date: nil)
        @http.get("#{BASE}/DeliveryPerformance", query: date_query(start_date, end_date))
      end

      private

      def date_query(start_date, end_date)
        { startDate: start_date, endDate: end_date }.compact
      end
    end
  end
end
