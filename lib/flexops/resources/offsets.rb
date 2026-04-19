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
    class Offsets
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def offset(label_id)
        @http.post("#{ws_path}/shipping/labels/#{label_id}/offset")
      end

      def get_emissions(label_id)
        @http.get("#{ws_path}/shipping/labels/#{label_id}/emissions")
      end

      def batch_offset(label_ids)
        @http.post("#{ws_path}/shipping/labels/offset/batch", body: { labelIds: label_ids })
      end

      private

      def ws_path
        "/api/workspaces/#{@ws_id.call}"
      end
    end
  end
end
