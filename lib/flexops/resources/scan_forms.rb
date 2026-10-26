# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "securerandom"

module FlexOps
  module Resources
    class ScanForms
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      # Creates a USPS SCAN form. API keys need shipping:write; the public demo keys are refused.
      #
      # request:: { trackingNumbers: [...] (1 to 1,000), manifestDate: "YYYY-MM-DD",
      #           requestId: (optional), originPostalCode: (optional), warehouseId: (optional) }
      #
      # Live creation needs manifestDate: without it the Gateway answers 400 "Choose the label
      # mailing date." The sandbox defaults it to today (UTC).
      #
      # requestId identifies the operation. Repeating a request with the same ID returns the same
      # form instead of creating another; reusing it with different inputs is 409. When it is left
      # out, one is generated for this call and sent on every retry of it, so a retry cannot create
      # a second form. Pass your own to retry the call yourself after an unknown outcome.
      def create(request)
        given = request[:requestId] || request["requestId"]
        body = given ? request : request.reject { |key, _| key.to_s == "requestId" }.merge(requestId: SecureRandom.uuid)
        @http.post("#{ws_path}/scan-forms", body: body)
      end

      def list
        @http.get("#{ws_path}/scan-forms")
      end

      def get(scan_form_id)
        @http.get("#{ws_path}/scan-forms/#{scan_form_id}")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
