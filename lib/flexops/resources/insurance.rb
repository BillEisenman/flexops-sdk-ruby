# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Shipping insurance. Answers use the { success, data, message, errorCode } envelope.
    class Insurance
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def get_providers
        @http.get("#{ws_path}/insurance/providers")
      end

      def get_quote(declared_value:, carrier_code:, tracking_number: nil, provider: nil)
        body = { declaredValue: declared_value, carrierCode: carrier_code,
                 trackingNumber: tracking_number, provider: provider }.compact
        @http.post("#{ws_path}/insurance/quote", body: body)
      end

      def purchase(tracking_number:, carrier_code:, declared_value:, coverage_tier: nil, provider: nil)
        body = { trackingNumber: tracking_number, carrierCode: carrier_code, declaredValue: declared_value,
                 coverageTier: coverage_tier, provider: provider }.compact
        @http.post("#{ws_path}/insurance/policies", body: body)
      end

      def void(policy_id)
        @http.delete("#{ws_path}/insurance/policies/#{policy_id}")
      end

      def file_claim(policy_id:, claim_reason:, claim_amount:, evidence_json: nil)
        body = { policyId: policy_id, claimReason: claim_reason, claimAmount: claim_amount,
                 evidenceJson: evidence_json }.compact
        @http.post("#{ws_path}/insurance/claims", body: body)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
