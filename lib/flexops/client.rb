# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

module FlexOps
  class Client
    attr_accessor :workspace_id
    attr_reader :auth, :workspaces, :shipping, :carriers, :webhooks, :wallet,
                :insurance, :returns, :api_keys, :analytics, :orders, :inventory,
                :pickups, :scan_forms, :rules, :offsets, :hs_codes,
                :recurring_shipments, :email_templates, :reports

    def initialize(api_key: nil, access_token: nil, base_url: "https://gateway.flexops.io", workspace_id: nil, timeout: 30)
      @http = HttpClient.new(base_url: base_url, api_key: api_key, access_token: access_token, timeout: timeout)
      @workspace_id = workspace_id

      ws_id_proc = -> { @workspace_id }

      @auth = Resources::Auth.new(@http)
      @workspaces = Resources::Workspaces.new(@http, ws_id_proc)
      @shipping = Resources::Shipping.new(@http, ws_id_proc)
      @carriers = Resources::Carriers.new(@http)
      @webhooks = Resources::Webhooks.new(@http, ws_id_proc)
      @wallet = Resources::Wallet.new(@http, ws_id_proc)
      @insurance = Resources::Insurance.new(@http, ws_id_proc)
      @returns = Resources::Returns.new(@http, ws_id_proc)
      @api_keys = Resources::ApiKeys.new(@http, ws_id_proc)
      @analytics = Resources::Analytics.new(@http)
      @orders = Resources::Orders.new(@http)
      @inventory = Resources::Inventory.new(@http)
      @pickups = Resources::Pickups.new(@http, ws_id_proc)
      @scan_forms = Resources::ScanForms.new(@http, ws_id_proc)
      @rules = Resources::Rules.new(@http, ws_id_proc)
      @offsets = Resources::Offsets.new(@http, ws_id_proc)
      @hs_codes = Resources::HsCodes.new(@http, ws_id_proc)
      @recurring_shipments = Resources::RecurringShipments.new(@http, ws_id_proc)
      @email_templates = Resources::EmailTemplates.new(@http, ws_id_proc)
      @reports = Resources::Reports.new(@http, ws_id_proc)
    end

    def set_access_token(token)
      @http.set_access_token(token)
    end

    def set_api_key(key)
      @http.set_api_key(key)
    end
  end
end
