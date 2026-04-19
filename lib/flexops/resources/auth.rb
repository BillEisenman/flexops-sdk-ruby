# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Auth
      def initialize(http)
        @http = http
      end

      def login(email:, password:)
        @http.post("/api/Account/login", body: { email: email, password: password })
      end

      def register(request)
        @http.post("/api/Account/register", body: request)
      end

      def refresh_token(refresh_token)
        @http.post("/api/Account/refresh-token", body: { refreshToken: refresh_token })
      end

      def logout
        @http.post("/api/Account/logout")
      end

      def get_profile
        @http.get("/api/Account/profile")
      end

      def update_profile(data)
        @http.put("/api/Account/profile", body: data)
      end

      def change_password(current_password:, new_password:)
        @http.post("/api/Account/change-password", body: { currentPassword: current_password, newPassword: new_password })
      end

      def forgot_password(email:)
        @http.post("/api/Account/forgot-password", body: { email: email })
      end

      def reset_password(token:, new_password:)
        @http.post("/api/Account/reset-password", body: { token: token, newPassword: new_password })
      end

      def verify_email(token:)
        @http.post("/api/Account/verify-email", body: { token: token })
      end
    end
  end
end
