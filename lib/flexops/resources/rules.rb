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

      # rule:: { name:, priority:, isEnabled:, warehouseId: (optional),
      #        conditions: [{ field:, operator:, value:, group: (optional) }], actions: [{ type:, value: }] }
      def create(rule)
        @http.post("#{ws_path}/shipping-rules", body: rule)
      end

      # rule:: the fields to change, named as for #create.
      def update(rule_id, rule)
        @http.put("#{ws_path}/shipping-rules/#{rule_id}", body: rule)
      end

      def delete(rule_id)
        @http.delete("#{ws_path}/shipping-rules/#{rule_id}")
      end

      # Sets rule priorities. +rules+ is an array of { ruleId:, priority: } hashes, or of rule ids
      # in the order to apply (the first gets priority 0).
      def reorder(rules)
        items = rules.each_with_index.map do |rule, index|
          rule.is_a?(Hash) ? rule : { ruleId: rule, priority: index }
        end
        @http.post("#{ws_path}/shipping-rules/reorder", body: { rules: items })
      end

      # Evaluates the workspace's rules against a sample shipment without changing anything.
      #
      # request:: { weightOz:, declaredValue:, destinationCountry:, destinationState:,
      #           destinationPostalCode:, orderSource:, itemCount:, shipMethod:, destinationZone:, tags: }
      def test(request)
        @http.post("#{ws_path}/shipping-rules/test", body: request)
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
