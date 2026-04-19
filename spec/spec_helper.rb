# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-04-01
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require "webmock/rspec"
require "json"
require "flexops"

WebMock.disable_net_connect!

BASE_URL = "http://localhost:5000"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end

# Helper to create a client pointed at the stubbed base URL
def create_client(api_key: "sk_test_key", access_token: nil, workspace_id: "ws-test-123")
  FlexOps::Client.new(
    api_key: api_key,
    access_token: access_token,
    base_url: BASE_URL,
    workspace_id: workspace_id,
    timeout: 5
  )
end

# Helper to build a JSON response body
def json_body(data, success: true)
  { success: success, data: data }.to_json
end
