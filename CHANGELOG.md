# Changelog

All notable changes to the FlexOps Ruby SDK are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Docs: `shipping.create_batch`, `shipping.preview_batch` and `returns.generate_label` now say that
  `hazmatClassification` accepts only `HazmatClassification::NONE` (0) or nothing; the Gateway refuses any other
  class with 400 `HazmatNotSupported`. No behavior change.
- Docs: every `webhooks` method that calls the Gateway (`list`, `create`, `update`, `delete`, `rotate_secret`,
  `list_delivery_logs` and `test`), the resource and the README now say it needs a signed-in user's access token.
  The Gateway refuses API keys on every webhook route, reads included, with 403 `SIGNED_IN_USER_REQUIRED`
  (`FlexOps::Error`), whatever the key's scopes; reads are refused because webhook delivery logs carry each
  delivery's payload (order and customer data). A client with an API key sends the key even when an access token
  is set. The README webhook example now signs in first. `verify_signature` needs no credentials. No behavior
  change.

## [2.2.0] - 2026-10-22

2.2.0 requires a maximum total price on multi-package labels: the Gateway refuses to buy a box that would take the shipment above it. It changes only the multi-package call released earlier today.

### Changed
- The `shipping.create_multi_package` request requires `maximumPostageAmount`: the most the whole shipment may
  cost, in USD (positive, at most two decimals). The Gateway refuses to buy a box that would take the total above
  it, so a shipment never costs more. A box priced above what is left reports `PriceCeilingExceeded`; once the
  amount is used up the remaining boxes report `PriceCeilingReached` and are not bought. Boxes already bought stay
  bought. The Gateway requires it from the release that ships this change (a request without it is 400
  `ApprovalRequired`), so this is breaking only for a `create_multi_package` call written against 2.1.0, released
  2026-10-22.

## [2.1.0] - 2026-10-22

2.1.0 adds multi-package labels and RMA reads, and corrects the returns `get` docs. Existing code keeps working.

### Added
- `shipping.create_multi_package(request, idempotency_key: nil)` buys labels for one order shipped in 1 to 99 boxes (`POST /api/shipping/multi-package`). `hazmatClassification` accepts only `HazmatClassification::NONE` or nothing; the Gateway refuses any other class with 400 `HazmatNotSupported`.
- `returns.get_rma(rma_number)` and `returns.list_rmas(page:, page_size:)` read return authorizations (`GET .../returns/rma/{rmaNumber}` and `GET .../returns/rma`). There was no way to read an RMA back after creating it.
- `FlexOps::Error#data` carries the envelope's `data` on an error reply. A multi-package 422 `AllPackagesFailed` or 409 `OutcomeUnknown` puts the per-box results there.

### Fixed
- `returns.get` and `returns.list` are documented as reading received returns: `get` takes the numeric return id, and an RMA number such as `RMA-1001` matches no Gateway route. Use `get_rma`.

## [2.0.0] - 2026-10-19

2.0.0 exposes only the documented public Gateway API and makes retries safe for purchases.
Every method left calls an operation in the Developer Docs OpenAPI reference; a contract test
(`spec/flexops/contract_spec.rb`) checks each one against a vendored operation list.

### Removed (breaking)
- `client.api_keys` (signed-in users only). Manage keys in the FlexOps portals.
- `client.offsets`: its per-label offset routes never existed on the Gateway. Use `client.carbon_offsets`.
- `wallet.add_funds`, `wallet.list_transactions` and `wallet.configure_auto_reload` (no API-key route).
- `auth.register`, `get_profile`, `update_profile`, `change_password`, `forgot_password`, `reset_password` and `verify_email`. `login`, `refresh_token` and `logout` remain for user-token operations.
- `workspaces.create` and `workspaces.update`.
- `returns.approve`, `reject`, `cancel` and `process_refund` (routes the Gateway does not serve).
- `webhooks.get(id)` (no such route; use `webhooks.list`).
- `orders.create`, `orders.cancel`, `inventory.post_asn_receipt` and `inventory.update_inventory`: writes through the legacy `/api/ApiProxy`, which refuses API-key writes.
- Carrier label generation through `/api/ApiProxy`, which the Gateway closes (410 Gone): `carriers.usps.create_domestic_label`, `create_return_label` and `create_international_label`; `carriers.ups.create_label`; `carriers.fedex.create_shipment` and `create_return_shipment`; `carriers.dhl.create_shipment`. Buy labels with `client.shipping.create_label` (`client.returns.generate_label` for returns).
- `carriers.dhl.update_pickup` (PATCH; the proxy has no PATCH route).

### Changed (breaking)
- Retries are safe for writes. Every POST, PUT and PATCH sends an `Idempotency-Key`: yours (`shipping.create_label(..., idempotency_key:)`) or one UUID generated per call and reused on each retry of that call, so the Gateway replays a write it already finished. Writes retry only after a dropped connection or timeout and on 429, 502, 503, 504 and 409 `IDEMPOTENCY_CONFLICT`; never on 500, which the Gateway does not replay. DELETE retries only on 429. GET retries as before (network errors, 429, 500, 502, 503, 504). A key reused with a different request gets 422 `IDEMPOTENCY_KEY_REUSED`, which is not retried.
- `client.recurring_shipments`, `client.report_schedules` and `client.email_templates` call the Gateway's real routes and shapes; the 1.x paths and bodies never worked. Reads work with any API key; writes need a user token or an API key with the opt-in `recurring-shipments:write`, `report-schedules:write` or `email-templates:write` scope (403 `API_KEY_SCOPE_REQUIRED` otherwise).
  - `recurring_shipments`: `list`, `get`, `create`, `update`, `delete`, `pause`, `resume` and `trigger(id, idempotency_key:)` on `/api/workspaces/{ws}/recurring-shipments` (bare JSON; 204 actions return `nil`). `list` no longer takes paging or `is_active` filters.
  - `client.reports` is renamed `client.report_schedules`: `list`, `get`, `create`, `update`, `delete` and `toggle` on `report-schedules`, returning the `{ success, data, message }` envelope (delete returns `nil`).
  - `email_templates` uses `email-templates` (not `shipment-email-templates`): `list`, `get`, `upsert` (PUT, keyed by `eventType`; replaces `create` and `update`), `delete` and `preview(subject_template:, html_body_template:)`, which renders a draft and replaces `preview(id, context)`.
- Carrier writes through the legacy `/api/ApiProxy` (POST, PUT and DELETE on `client.carriers.usps`, `.ups`, `.fedex` and `.dhl`) are kept with their 1.x names and paths but are deprecated (`@deprecated`; the proxy sunsets 2027-06-30) and need a user token: API keys get 403 `API_KEY_SCOPE_REQUIRED`. They now send an `Idempotency-Key` and follow the write retry rules. Carrier GET lookups work with API keys as before. The label-generation methods the Gateway closed are removed (see Removed).
- A 2xx response with no body (204, or Content-Length 0) returns `nil` instead of an empty string.
- `shipping.validate_address` posts the documented flat `AddressValidationRequest` (`name`, `line1`, `line2`, `city`, `state`, `postalCode`, `country`) to `POST /api/addresses/validate` and returns its result (`isValid`, `validationUnavailable`, `suggestedAddress`, `isResidential`, `warnings`, `validatedBy`, `checkedAt`). Addresses with rate/label field names or legacy `street1`/`state`/`zip` names are mapped; other fields are not sent.
- `wallet.get_balance` reads `GET /api/wallet/my-balance` with `X-Workspace-Id` set to the configured workspace and returns the bare `{ hasWallet, balanceCents, balance }`.
- `client.hs_codes` uses `/api/shipping/hs-codes/search`, `/api/shipping/hs-codes/{code}` and `POST /api/shipping/landed-cost`, without a workspace in the path; answers are bare.
- `insurance.get_quote(declared_value:, carrier_code:, tracking_number:, provider:)`, `purchase(tracking_number:, carrier_code:, declared_value:, coverage_tier:, provider:)` (now `POST insurance/policies`) and `file_claim(policy_id:, claim_reason:, claim_amount:, evidence_json:)` (now `POST insurance/claims`) send the Gateway field names; `carrier:` and `description:` are gone.
- `returns.create` posts to `returns/rma` (`orderId`, `reason`, `items: [{ sku, quantity }]`, ...). `returns.mark_received(rma_id, rma_number:, inspected_items:, warehouse_id:)` sends the Gateway `ReceiveRmaRequest`. `returns.list` filters by `start_date:`/`end_date:`; `status:` was never read by the Gateway.
- `rules.reorder` posts `{ rules: [{ ruleId, priority }] }` with POST; it also accepts rule ids in order.
- `pickups.list` reads `pickups/scheduled`; `pickups.get` and `pickups.cancel` take `carrier_code:` (the Gateway defaults to `usps`).
- `workspaces.invite_member(email:, role:)` requires the role, since the Gateway reads a missing role as Owner. Roles are sent as `WorkspaceRole` numbers; `update_member_role` sends `{ newRole }`. `list_members` returns the Gateway envelope whose `data` holds `members`, `pendingInvites`, `userLimit` and `canInviteMore`.
- `auth.refresh_token(refresh_token, access_token:)` sends the access token the Gateway `RefreshTokenRequest` requires (default: the client's current access token).

### Added
- `client.carbon_offsets`: `quote`, `purchase`, `list`, `get`, `summary`, `get_settings` and `update_settings`.
- `insurance.purchase` and `carbon_offsets.purchase` accept `idempotency_key:`. Store it with the purchase and reuse
  it when your app retries, so the Gateway returns the first result instead of charging again.
- `rules.test(request)` evaluates the shipping rules against a sample shipment.
- `webhooks.test(webhook_id)` sends a test event.
- `FlexOps::WorkspaceRole` constants (`OWNER` 0, `ADMIN` 1, `MEMBER` 2, `MERCHANT` 3).
- `returns.generate_label` takes `rate_indicator:`; `carrier_code:` stays optional.
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
