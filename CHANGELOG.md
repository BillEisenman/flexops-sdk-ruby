# Changelog

All notable changes to the FlexOps Ruby SDK are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial README with installation, quick start, authentication (API key and email/password), sandbox guidance, direct carrier operations, webhook verification, and a curl quickstart section.

### Changed
- Retargeted `homepage` in `flexops.gemspec` to `github.com/BillEisenman/flexops-sdk-ruby` (organization migration from `FlexOps/`).

## [1.0.0] - 2026-03-08

### Added
- Initial public release.
- `FlexOps::Client` entry point with API key and email/password authentication.
- 20 resource modules covering auth, workspaces, shipping, carriers, webhooks, wallet, insurance, returns, api keys, analytics, orders, inventory, pickups, scan forms, rules, offsets, HS codes, recurring shipments, email templates, and reports.
- Direct carrier access for USPS, UPS, FedEx, and DHL.
- Requires Ruby 3.0+.
