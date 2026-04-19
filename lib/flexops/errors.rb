# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  class Error < StandardError
    attr_reader :status, :code, :errors

    def initialize(message, status: 0, code: nil, errors: nil)
      super(message)
      @status = status
      @code = code
      @errors = errors
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
end
