# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-31
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

# frozen_string_literal: true

require "erb"

module FlexOps
  module Resources
    # HS code lookup and landed cost. These routes are not workspace-scoped; each returns a bare
    # (not enveloped) answer.
    class HsCodes
      def initialize(http)
        @http = http
      end

      def search(query, destination_country: nil, max_results: 10)
        params = { query: query, destinationCountry: destination_country, maxResults: max_results }.compact
        @http.get("/api/shipping/hs-codes/search", query: params)
      end

      def lookup(code)
        @http.get("/api/shipping/hs-codes/#{ERB::Util.url_encode(code.to_s)}")
      end

      # request:: { destinationCountry:, items: [{ description:, quantity:, value:, weightOz:,
      #           hsCode: (optional), originCountry:, skuOrProductId: (optional) }], shippingCost: }
      def estimate_landed_cost(request)
        @http.post("/api/shipping/landed-cost", body: request)
      end
    end
  end
end
