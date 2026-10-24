# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "uri"

module FlexOps
  module Resources
    class Pickups
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      # Schedules a carrier pickup. API keys need shipping:write; the public demo keys are refused.
      #
      # request:: { carrierCode:, pickupDate:, street:, city:, state:, postalCode:,
      #           country: (optional, "US"), packageCount:, totalWeightOz: (optional),
      #           specialInstructions:, readyTime:, closeTime:, contactName:, contactPhone: (all optional) }
      def schedule(request)
        @http.post("#{ws_path}/pickups", body: request)
      end

      # Lists the workspace's scheduled pickups.
      def list
        @http.get("#{ws_path}/pickups/scheduled")
      end

      # The Gateway uses "usps" when carrier_code is left out.
      def get(pickup_id, carrier_code: nil)
        @http.get("#{ws_path}/pickups/#{pickup_id}", query: carrier_code.nil? ? nil : { carrierCode: carrier_code })
      end

      # Cancels a scheduled pickup. API keys need shipping:write; the public demo keys are refused.
      # The Gateway uses "usps" when carrier_code is left out.
      def cancel(pickup_id, carrier_code: nil)
        query = carrier_code.nil? ? "" : "?#{URI.encode_www_form(carrierCode: carrier_code)}"
        @http.delete("#{ws_path}/pickups/#{pickup_id}#{query}")
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
