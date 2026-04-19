# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Insurance
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def get_providers
        @http.get("#{ws_path}/insurance/providers")
      end

      def get_quote(carrier:, declared_value:, provider: nil)
        body = { carrier: carrier, declaredValue: declared_value }
        body[:provider] = provider if provider
        @http.post("#{ws_path}/insurance/quote", body: body)
      end

      def purchase(tracking_number:, carrier:, declared_value:, provider: nil)
        body = { trackingNumber: tracking_number, carrier: carrier, declaredValue: declared_value }
        body[:provider] = provider if provider
        @http.post("#{ws_path}/insurance/purchase", body: body)
      end

      def void(policy_id)
        @http.delete("#{ws_path}/insurance/policies/#{policy_id}")
      end

      def file_claim(policy_id, description:, claim_amount:)
        @http.post("#{ws_path}/insurance/policies/#{policy_id}/claims", body: { description: description, claimAmount: claim_amount })
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
