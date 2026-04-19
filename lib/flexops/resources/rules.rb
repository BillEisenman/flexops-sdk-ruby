# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Rules
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get("#{ws_path}/shipping-rules")
      end

      def get(rule_id)
        @http.get("#{ws_path}/shipping-rules/#{rule_id}")
      end

      def create(rule)
        @http.post("#{ws_path}/shipping-rules", body: rule)
      end

      def update(rule_id, rule)
        @http.put("#{ws_path}/shipping-rules/#{rule_id}", body: rule)
      end

      def delete(rule_id)
        @http.delete("#{ws_path}/shipping-rules/#{rule_id}")
      end

      def reorder(rule_ids)
        @http.put("#{ws_path}/shipping-rules/reorder", body: rule_ids)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
