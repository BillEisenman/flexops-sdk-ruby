# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  class Error < StandardError
    # data is the envelope's "data" on an error reply, when the Gateway sends one. A
    # multi-package 422 AllPackagesFailed or 409 OutcomeUnknown carries the per-box results there.
    attr_reader :status, :code, :errors, :data

    def initialize(message, status: 0, code: nil, errors: nil, data: nil)
      super(message)
      @status = status
      @code = code
      @errors = errors
      @data = data
    end
  end

  class AuthError < Error
    def initialize(message = "Authentication required. Check your access token or API key.")
      super(message, status: 401, code: "UNAUTHORIZED")
    end
  end

  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(retry_after: 0)
      super("Rate limited. Retry after #{retry_after}s", status: 429, code: "RATE_LIMITED")
      @retry_after = retry_after
    end
  end

  # Raised by Resources::Webhooks.verify_signature! when a webhook delivery
  # is not authentic or not fresh. +code+ says why, for example
  # "WEBHOOK_SIGNATURE_MISMATCH" or "WEBHOOK_TIMESTAMP_OUTSIDE_TOLERANCE".
  class WebhookSignatureError < Error
    def initialize(message, code:)
      super(message, code: code)
    end
  end
end
