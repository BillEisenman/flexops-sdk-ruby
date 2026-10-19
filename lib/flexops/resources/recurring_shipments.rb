# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Recurring shipment schedules. Answers are bare JSON (no envelope); ids are GUID strings.
    #
    # Reads work with any API key or a user token. Writes (create, update, delete, pause, resume,
    # trigger) need a user token (auth.login) or an API key granted the opt-in
    # "recurring-shipments:write" scope; a key without it gets 403 API_KEY_SCOPE_REQUIRED.
    #
    # +interval+ is the Gateway RecurrenceInterval number: Daily 0, Weekly 1, Biweekly 2,
    # Monthly 3, Custom 4 (Custom runs on +cronExpression+).
    class RecurringShipments
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

      # request:: { name:, firstRunUtc: (ISO 8601), interval: (0-4), presetId:, addressId:,
      #           cronExpression:, maxFailures: (1-100, default 3) }. Each run needs a destination
      #           +addressId+; a +presetId+ supplies the package and service. Returns the schedule.
      def create(request)
        @http.post(ws_path, body: request)
      end

      # request:: any of name:, presetId:, addressId:, interval:, cronExpression:, maxFailures:.
      def update(id, request)
        @http.put("#{ws_path}/#{id}", body: request)
      end

      # Returns nil (204).
      def delete(id)
        @http.delete("#{ws_path}/#{id}")
      end

      # Returns nil (204).
      def pause(id)
        @http.post("#{ws_path}/#{id}/pause")
      end

      # Returns nil (204).
      def resume(id)
        @http.post("#{ws_path}/#{id}/resume")
      end

      # Runs the schedule now, which creates an order. Pass the same +idempotency_key+ when you
      # retry a trigger yourself so the Gateway does not create a second order. Returns nil (204).
      def trigger(id, idempotency_key: nil)
        @http.post("#{ws_path}/#{id}/trigger",
                   headers: idempotency_key.nil? ? {} : { "Idempotency-Key" => idempotency_key })
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}/recurring-shipments"
      end
    end
  end
end
