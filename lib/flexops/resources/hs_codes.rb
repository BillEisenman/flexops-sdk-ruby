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
    class HsCodes
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def search(query, destination_country: nil, max_results: 10)
        params = { query: query, destinationCountry: destination_country, maxResults: max_results }.compact
        @http.get("#{ws_path}/shipping/hs-codes/search", query: params)
      end

      def lookup(code)
        @http.get("#{ws_path}/shipping/hs-codes/#{code}")
      end

      def estimate_landed_cost(request)
        @http.post("#{ws_path}/shipping/landed-cost", body: request)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
