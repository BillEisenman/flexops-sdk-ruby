# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    # Token acquisition for operations that need a signed-in user. Account management
    # (registration, profile, passwords) belongs to the FlexOps portals.
    class Auth
      def initialize(http)
        @http = http
      end

      def login(email:, password:)
        @http.post("/api/Account/login", body: { email: email, password: password })
      end

      # The Gateway RefreshTokenRequest requires the expired access token as well as the refresh
      # token; it defaults to the client's current access token.
      def refresh_token(refresh_token, access_token: nil)
        token = access_token || @http.access_token
        raise ArgumentError, "access_token is required to refresh a session" if token.to_s.empty?

        @http.post("/api/Account/refresh-token", body: { token: token, refreshToken: refresh_token })
      end

      def logout
        @http.post("/api/Account/logout")
      end
    end
  end
end
