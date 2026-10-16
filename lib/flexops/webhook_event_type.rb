# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-16
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  # Event names FlexOps sends in the X-FlexOps-Event header and matches webhook
  # subscriptions against.
  #
  # Names are PascalCase and matched exactly: a dotted name such as "label.created"
  # matches nothing. TRACKING_UPDATED and TRACKING_DELIVERED are sent only to
  # workspaces in the USPS push-tracking pilot.
  module WebhookEventType
    LABEL_CREATED = "LabelCreated"
    LABEL_CANCELED = "LabelCanceled"
    BATCH_COMPLETED = "BatchCompleted"
    TRACKING_UPDATED = "TrackingUpdated"
    TRACKING_DELIVERED = "TrackingDelivered"

    ALL = [LABEL_CREATED, LABEL_CANCELED, BATCH_COMPLETED, TRACKING_UPDATED, TRACKING_DELIVERED].freeze
  end
end
