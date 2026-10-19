# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Wallet
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      # Returns the configured workspace's balance, bare: { "hasWallet", "balanceCents", "balance" }.
      # Funding and transaction history are managed in the FlexOps portal.
      def get_balance
        ws_id = @ws_id.call
        @http.get("/api/wallet/my-balance", headers: ws_id.to_s.empty? ? {} : { "X-Workspace-Id" => ws_id.to_s })
      end
    end
  end
end
