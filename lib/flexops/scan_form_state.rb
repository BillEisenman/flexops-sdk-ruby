# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-10-24
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  # The "state" of a SCAN form hash returned by client.scan_forms (the Gateway's ScanFormDto).
  # The Gateway may add other values; treat them like OUTCOME_UNKNOWN.
  module ScanFormState
    # USPS returned the manifest, and the Gateway saved its number and PDF.
    CREATED = "Created"
    # The carrier's answer was lost or did not match. The packages stay reserved: do not submit
    # them again until the outcome is resolved.
    OUTCOME_UNKNOWN = "OutcomeUnknown"

    # True when a SCAN form hash ("data" of create/get, or an item of list) is a created form.
    def self.created?(form)
      form.is_a?(Hash) && form["state"] == CREATED
    end

    # Decodes a SCAN form hash's "scanFormImage" (the base64 PS Form 5630 PDF), or returns nil when
    # it has none: sandbox forms are never sent to USPS, and an unresolved operation has no PDF.
    def self.pdf_bytes(form)
      image = form.is_a?(Hash) ? form["scanFormImage"] : nil
      image.nil? ? nil : image.unpack1("m0")
    end
  end
end
