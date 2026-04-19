# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require_relative "flexops/version"
require_relative "flexops/errors"
require_relative "flexops/http"
require_relative "flexops/client"
require_relative "flexops/resources/auth"
require_relative "flexops/resources/workspaces"
require_relative "flexops/resources/shipping"
require_relative "flexops/resources/carriers"
require_relative "flexops/resources/webhooks"
require_relative "flexops/resources/wallet"
require_relative "flexops/resources/insurance"
require_relative "flexops/resources/returns"
require_relative "flexops/resources/api_keys"
require_relative "flexops/resources/analytics"
require_relative "flexops/resources/orders"
require_relative "flexops/resources/inventory"
require_relative "flexops/resources/pickups"
require_relative "flexops/resources/scan_forms"
require_relative "flexops/resources/rules"
require_relative "flexops/resources/offsets"
require_relative "flexops/resources/hs_codes"
require_relative "flexops/resources/recurring_shipments"
require_relative "flexops/resources/email_templates"
require_relative "flexops/resources/reports"

module FlexOps
end
