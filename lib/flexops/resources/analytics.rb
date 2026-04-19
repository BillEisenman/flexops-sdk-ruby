# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Analytics
      BASE = "/api/ApiProxy/api/v4/Analytics"

      def initialize(http)
        @http = http
      end

      def shipments_trend(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ShipmentsTrend", query: date_query(start_date, end_date))
      end

      def carrier_summary(start_date: nil, end_date: nil)
        @http.get("#{BASE}/CarrierSummary", query: date_query(start_date, end_date))
      end

      def top_destinations(start_date: nil, end_date: nil, limit: nil)
        @http.get("#{BASE}/TopDestinations", query: date_query(start_date, end_date).merge(limit: limit).compact)
      end

      def inventory_metrics
        @http.get("#{BASE}/InventoryMetrics")
      end

      def stock_by_warehouse
        @http.get("#{BASE}/StockByWarehouse")
      end

      def order_metrics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/OrderMetrics", query: date_query(start_date, end_date))
      end

      def order_trend(start_date: nil, end_date: nil)
        @http.get("#{BASE}/OrderTrend", query: date_query(start_date, end_date))
      end

      def top_selling_products(start_date: nil, end_date: nil, limit: nil)
        @http.get("#{BASE}/TopSellingProducts", query: date_query(start_date, end_date).merge(limit: limit).compact)
      end

      def returns_metrics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ReturnsMetrics", query: date_query(start_date, end_date))
      end

      def returns_trend(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ReturnsTrend", query: date_query(start_date, end_date))
      end

      def return_reasons(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ReturnReasons", query: date_query(start_date, end_date))
      end

      def performance_metrics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/PerformanceMetrics", query: date_query(start_date, end_date))
      end

      def carrier_performance(start_date: nil, end_date: nil)
        @http.get("#{BASE}/CarrierPerformance", query: date_query(start_date, end_date))
      end

      def shipping_cost_analytics(start_date: nil, end_date: nil)
        @http.get("#{BASE}/ShippingCostAnalytics", query: date_query(start_date, end_date))
      end

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
