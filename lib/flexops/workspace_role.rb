# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-19
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  # Workspace member role, sent as the Gateway WorkspaceRole number.
  module WorkspaceRole
    OWNER = 0
    ADMIN = 1
    MEMBER = 2
    MERCHANT = 3

    ALL = { OWNER: OWNER, ADMIN: ADMIN, MEMBER: MEMBER, MERCHANT: MERCHANT }.freeze

    # Returns the wire number for a role given as a number or a name (:member, "Admin").
    # Raises ArgumentError, before any request, for anything else.
    def self.to_wire(role)
      return role if role.is_a?(Integer) && ALL.value?(role)

      if role.is_a?(String) || role.is_a?(Symbol)
        number = ALL[role.to_s.upcase.to_sym]
        return number unless number.nil?
      end

      raise ArgumentError, "Unknown workspace role: #{role.inspect}. Use one of #{ALL.keys.join(", ")} or 0-3."
    end
  end
end
