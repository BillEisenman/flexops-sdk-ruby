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

      def list_members
        @http.get("/api/workspaces/#{@ws_id.call}/members")
      end

      # Invites a member. +role+ is a FlexOps::WorkspaceRole number or name (for example
      # :member); it is required because the Gateway reads a missing role as Owner.
      def invite_member(email:, role:)
        @http.post("/api/workspaces/#{@ws_id.call}/members/invite",
                   body: { email: email, role: FlexOps::WorkspaceRole.to_wire(role) })
      end

      def remove_member(user_id)
        @http.delete("/api/workspaces/#{@ws_id.call}/members/#{user_id}")
      end

      # Changes a member's role; +role+ is a FlexOps::WorkspaceRole number or name.
      def update_member_role(user_id, role)
        @http.put("/api/workspaces/#{@ws_id.call}/members/#{user_id}/role",
                  body: { newRole: FlexOps::WorkspaceRole.to_wire(role) })
      end
    end
  end
end
