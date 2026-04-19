# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "openssl"

module FlexOps
  module Resources
    class Webhooks
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get("#{ws_path}/webhooks")
      end

      def get(webhook_id)
        @http.get("#{ws_path}/webhooks/#{webhook_id}")
      end

      def create(request)
        @http.post("#{ws_path}/webhooks", body: request)
      end

      def update(webhook_id, data)
        @http.put("#{ws_path}/webhooks/#{webhook_id}", body: data)
      end

      def delete(webhook_id)
        @http.delete("#{ws_path}/webhooks/#{webhook_id}")
      end

      def rotate_secret(webhook_id)
        @http.post("#{ws_path}/webhooks/#{webhook_id}/rotate-secret")
      end

      def list_delivery_logs(webhook_id)
        @http.get("#{ws_path}/webhooks/#{webhook_id}/deliveries")
      end

      def self.verify_signature(payload, signature, secret)
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
        OpenSSL.secure_compare(expected, signature)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
