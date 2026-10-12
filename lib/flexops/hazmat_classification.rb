# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-12
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  # USPS HAZMAT classification, sent as the Gateway HazmatClassification number.
  #
  # There is no default: leave hazmatClassification out when you have no answer, or send
  # HazmatClassification::NONE (0) to declare that the parcel holds no dangerous goods.
  # A label without an orderId must declare one.
  module HazmatClassification
    NONE = 0
    LIMITED_QUANTITY = 1
    LITHIUM_BATTERY_CONTAINED_IN_EQUIPMENT = 2
    LITHIUM_BATTERY_PACKED_WITH_EQUIPMENT = 3
    LITHIUM_BATTERY_STANDALONE = 4
    OTHER_RESTRICTED = 5
    LITHIUM_BATTERY_USED_DEVICE = 6

    ALL = {
      NONE: NONE,
      LIMITED_QUANTITY: LIMITED_QUANTITY,
      LITHIUM_BATTERY_CONTAINED_IN_EQUIPMENT: LITHIUM_BATTERY_CONTAINED_IN_EQUIPMENT,
      LITHIUM_BATTERY_PACKED_WITH_EQUIPMENT: LITHIUM_BATTERY_PACKED_WITH_EQUIPMENT,
      LITHIUM_BATTERY_STANDALONE: LITHIUM_BATTERY_STANDALONE,
      OTHER_RESTRICTED: OTHER_RESTRICTED,
      LITHIUM_BATTERY_USED_DEVICE: LITHIUM_BATTERY_USED_DEVICE
    }.freeze
  end
end
