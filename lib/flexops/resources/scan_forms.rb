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
    # USPS SCAN forms. Replies are the Gateway envelope as a Hash with string keys:
    # { "success" => true, "message" => nil, "data" => form, "errors" => nil, "errorCode" => nil }.
    # A form (the Gateway's ScanFormDto) has:
    #
    # "scanFormId"::       32 hexadecimal digits, no dashes; pass it to #get.
    # "state"::            FlexOps::ScanFormState::CREATED or OUTCOME_UNKNOWN.
    # "originPostalCode":: the origin ZIP, or nil.
    # "trackingNumbers"::  the packages on the form.
    # "createdAtUtc"::     ISO 8601 in UTC, for example "2026-09-08T21:14:03.512Z".
    # "scanFormImage"::    the PS Form 5630 PDF, base64; nil for sandbox forms and unresolved
    #                      operations. FlexOps::ScanFormState.pdf_bytes decodes it.
    # "manifestNumber"::   the USPS manifest number; "SBOX..." in the sandbox, "" while unresolved.
    # "manifestDate"::     the mailing date, for example "2026-09-08T00:00:00".
    # "packageCount"::     how many packages the form covers.
    # "statusMessage"::    a status line for people.
    # "success"::          true when "state" is "Created".
    # "errorMessage"::     not set by the current Gateway; refusals raise FlexOps::Error.
    # "isSandbox"::        true for a sandbox (test key) form, never sent to USPS.
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
      #
      # Returns the envelope whose "data" is the created form, also when the same requestId and
      # inputs are sent again. Raises FlexOps::Error with status 409 when the requestId was used
      # with different inputs, when the packages already belong to a manifest, or when this or an
      # earlier operation needs review (its message names the operation; do not resubmit those
      # packages), and 400 when the request or package selection is refused. A 409 is not retried.
      def create(request)
        given = request[:requestId] || request["requestId"]
        body = given ? request : request.reject { |key, _| key.to_s == "requestId" }.merge(requestId: SecureRandom.uuid)
        @http.post("#{ws_path}/scan-forms", body: body)
      end

      # Lists the workspace's saved scan forms ("data" is an Array of forms), newest mailing date
      # first, including any whose outcome is unknown.
      def list
        @http.get("#{ws_path}/scan-forms")
      end

      # Gets a saved scan form by its "scanFormId". A form that does not exist raises
      # FlexOps::Error with status 404.
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
