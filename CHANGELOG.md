# Changelog

All notable changes to the FlexOps Ruby SDK are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `FlexOps::WebhookEventType` constants (and `WebhookEventType::ALL`) with the event names FlexOps sends and matches subscriptions on: `LabelCreated`, `LabelCanceled`, `BatchCompleted`, and, for USPS push-tracking pilot workspaces, `TrackingUpdated` and `TrackingDelivered`. The README has a subscription sample and the event table.
- `FlexOps::HazmatClassification` constants (`NONE` = 0 ... `LITHIUM_BATTERY_USED_DEVICE` = 6, the Gateway numbers). Put `hazmatClassification:` in a label or rate request; it is sent only when you set it, and the SDK never defaults it. Labels without an `orderId` must declare it (`HazmatClassification::NONE` for an ordinary parcel).
- `returns.generate_label(return_id, hazmat_classification:)` sends a declared HAZMAT class with a return label.
- `returns.generate_label` also takes `weight_oz:`, `length_in:`, `width_in:`, `height_in:`, `carrier_code:`, `service_type:` and `payment_confirmed:`. The Gateway needs the package: a workspace with no default shipping preset gets a 400 (`PackageMeasurementsRequired`) naming the missing fields when it is left out (Gateway #672).

### Fixed
- **BREAKING**: webhook subscriptions honour the events you choose. `webhooks.create` and `webhooks.update` sent an `events:` array as-is, which the Gateway ignores, so every subscription received every event. They now send it as the Gateway's comma-separated `eventTypes` (for example `"LabelCreated,BatchCompleted"`). Both raise `ArgumentError`, without calling the API, when `events` is empty, is not an array, names an event FlexOps never sends (such as `label.created`), or is given together with `eventTypes`. Code that subscribed with dotted names now raises instead of silently receiving everything: use `FlexOps::WebhookEventType` names, or leave `events` out to receive every event. A raw `eventTypes:` string is still sent unchanged.
- `webhooks.create` always returns the subscription itself, with the `whsec_...` signing secret at `result["secret"]`. The Gateway answers a create with `201` and the bare subscription, not the `{ success, data }` envelope its other webhook routes use. That bare body was already returned as-is; an enveloped one is now unwrapped too, so the secret, shown only on create, cannot end up nested under `"data"`.
- **BREAKING**: webhook signature verification now matches what FlexOps sends (flexops-sdk-node#41). `Webhooks.verify_signature(payload, signature, secret)` hashed the body alone and compared bare hex, so it returned `false` for every real delivery. It now takes keywords, `verify_signature(payload:, signature:, timestamp:, secret:, tolerance: 300, now: Time.now)`, signs `{X-FlexOps-Timestamp}.{raw body}` with HMAC-SHA256 keyed by the whole `whsec_...` secret, accepts the `sha256=` prefix, compares with `OpenSSL.secure_compare`, and rejects missing, non-numeric or out-of-tolerance timestamps. Positional calls now raise `ArgumentError`: pass the four keywords, including the `X-FlexOps-Timestamp` header value. The new `verify_signature!` raises `FlexOps::WebhookSignatureError` (a `FlexOps::Error` whose `code` says why) instead of returning `false`. Header name constants (`Webhooks::SIGNATURE_HEADER`, `TIMESTAMP_HEADER`, `EVENT_HEADER`, ...) are added.
- The README webhook sample passed keywords the helper did not accept and is now a complete handler. Webhook bodies have no `type`/`data` envelope; the event name is in `X-FlexOps-Event`.
- `returns.generate_label(return_id)` sends `{}`; it sent no body, which the Gateway return-label route refuses with 400.
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
