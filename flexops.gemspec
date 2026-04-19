# ***********************************************************************
# Package          : flexops
# Author           : FlexOps, LLC
# Created          : 2026-03-08
#
# Copyright (c) 2021-2026 by FlexOps, LLC. All rights reserved.
# ***********************************************************************

require_relative "lib/flexops/version"

Gem::Specification.new do |s|
  s.name        = "flexops"
  s.version     = FlexOps::VERSION
  s.summary     = "Official FlexOps multi-carrier shipping platform SDK"
  s.description = "Ruby SDK for the FlexOps multi-carrier shipping platform API. " \
                  "Supports USPS, UPS, FedEx, DHL with rate shopping, label generation, " \
                  "tracking, webhooks, wallet, insurance, returns, and more."
  s.authors     = ["FlexOps, LLC"]
  s.email       = ["support@flexops.io"]
  s.homepage    = "https://github.com/BillEisenman/flexops-sdk-ruby"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.1"
  s.files = Dir["lib/**/*.rb"] + ["LICENSE", "README.md"].select { |f| File.exist?(f) }

  s.add_dependency "json", "~> 2.0"

  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "webmock", "~> 3.24"
end
