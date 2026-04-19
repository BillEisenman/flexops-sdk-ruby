# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Pickups
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def schedule(request)
        @http.post("#{ws_path}/pickups", body: request)
      end

      def list
        @http.get("#{ws_path}/pickups")
      end

      def get(pickup_id)
        @http.get("#{ws_path}/pickups/#{pickup_id}")
      end

      def cancel(pickup_id)
        @http.delete("#{ws_path}/pickups/#{pickup_id}")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
