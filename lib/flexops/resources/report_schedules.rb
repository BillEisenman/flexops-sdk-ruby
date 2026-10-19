# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Scheduled report emails. Answers use the { success, data, message } envelope, except
    # delete, which returns nil (204). Ids are GUID strings.
    #
    # Reads work with any API key or a user token. Writes (create, update, delete, toggle) need a
    # user token (auth.login) or an API key granted the opt-in "report-schedules:write" scope; a
    # key without it gets 403 API_KEY_SCOPE_REQUIRED.
    #
    # Numbers on the wire: +format+ Csv 0, Json 1; +frequencyType+ Daily 0, Weekly 1, Monthly 2;
    # +dayOfWeek+ 0-6 (Sunday 0, for Weekly); +dayOfMonth+ 1-28 (for Monthly).
    class ReportSchedules
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get(ws_path)
      end

      def get(id)
        @http.get("#{ws_path}/#{id}")
      end

      # request:: { reportType: (e.g. "shipments"), format:, frequencyType:, timeOfDayUtc: ("HH:mm:ss"),
      #           recipientEmails: (comma-separated), dayOfWeek:, dayOfMonth:, filterParametersJson:,
      #           maxFailures: (1-100, default 3) }.
      def create(request)
        @http.post(ws_path, body: request)
      end

      # request:: any of the create fields.
      def update(id, request)
        @http.put("#{ws_path}/#{id}", body: request)
      end

      # Returns nil (204).
      def delete(id)
        @http.delete("#{ws_path}/#{id}")
      end

      # Flips isEnabled. The envelope's data is nil; read the schedule to see the new state.
      def toggle(id)
        @http.post("#{ws_path}/#{id}/toggle")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}/report-schedules"
      end
    end
  end
end
