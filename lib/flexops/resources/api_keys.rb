# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class ApiKeys
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get("#{ws_path}/api-keys")
      end

      def create(request)
        @http.post("#{ws_path}/api-keys", body: request)
      end

      def revoke(key_id)
        @http.delete("#{ws_path}/api-keys/#{key_id}")
      end

      def rotate(key_id)
        @http.post("#{ws_path}/api-keys/#{key_id}/rotate")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
