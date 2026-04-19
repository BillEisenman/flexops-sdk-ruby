# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  module Resources
    class Workspaces
      def initialize(http, ws_id_proc)
        @http = http
        @ws_id = ws_id_proc
      end

      def list
        @http.get("/api/workspaces")
      end

      def get(workspace_id = nil)
        id = workspace_id || @ws_id.call
        @http.get("/api/workspaces/#{id}")
      end

      def create(request)
        @http.post("/api/workspaces", body: request)
      end

      def update(data)
        @http.put("/api/workspaces/#{@ws_id.call}", body: data)
      end

      def list_members
        @http.get("/api/workspaces/#{@ws_id.call}/members")
      end

      def invite_member(email:, role: nil)
        body = { email: email }
        body[:role] = role if role
        @http.post("/api/workspaces/#{@ws_id.call}/members/invite", body: body)
      end

      def remove_member(user_id)
        @http.delete("/api/workspaces/#{@ws_id.call}/members/#{user_id}")
      end

      def update_member_role(user_id, role)
        @http.put("/api/workspaces/#{@ws_id.call}/members/#{user_id}/role", body: { role: role })
      end
    end
  end
end
