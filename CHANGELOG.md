# Changelog

All notable changes to the FlexOps Ruby SDK are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `FlexOps::HazmatClassification` constants (`NONE` = 0 ... `LITHIUM_BATTERY_USED_DEVICE` = 6, the Gateway numbers). Put `hazmatClassification:` in a label or rate request; it is sent only when you set it, and the SDK never defaults it. Labels without an `orderId` must declare it (`HazmatClassification::NONE` for an ordinary parcel).
- `returns.generate_label(return_id, hazmat_classification:)` sends a declared HAZMAT class with a return label.

### Fixed
- `shipping.create_label` posts to the Gateway route `/api/shipping/labels`; it used a workspace-scoped path the Gateway does not serve.
- `shipping.track`, `cancel_label`, `get_carriers`, `get_recommendations`, `predict_delivery` and `get_savings` use the Gateway `/api/shipping/...` routes instead of workspace-scoped paths the Gateway does not serve. `cancel_label(label_id, carrier_code:)` now needs the carrier code the Gateway requires; without it the SDK raises `ArgumentError` before any request.
- `shipping.validate_address` posts the Gateway `{ address: {...} }` request to `/api/shipping/addresses/validate`, and maps a legacy `street1`/`state`/`zip` address to the Gateway field names.

## [1.1.0] - 2026-09-19

### Bounded label purchase support

- Single-label requests support maximumPostageAmount and confirmationToken.
- CreateLabel/create_label accepts a per-purchase idempotency key and preserves it on retries.
- Preview and purchase responses are raw objects, not success/data envelopes.
- Gateway errorCode is preserved on SDK errors.
- Read the README approval flow and migration notes before upgrading.

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
