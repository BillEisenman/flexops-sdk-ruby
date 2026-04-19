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
    class Reports
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get("#{ws_path}/report-schedules/")
      end

      def get(id)
        @http.get("#{ws_path}/report-schedules/#{id}")
      end

      def create(request)
        @http.post("#{ws_path}/report-schedules/", body: request)
      end

      def update(id, request)
        @http.put("#{ws_path}/report-schedules/#{id}", body: request)
      end

      def delete(id)
        @http.delete("#{ws_path}/report-schedules/#{id}")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
