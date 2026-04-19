# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class ScanForms
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def create(request)
        @http.post("#{ws_path}/scan-forms", body: request)
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
