# FlexOps Ruby SDK

Official Ruby SDK for the [FlexOps](https://flexops.io) multi-carrier shipping platform. Supports USPS, UPS, FedEx, DHL, OnTrac, Australia Post, Canada Post, Royal Mail, and LSO with rate shopping, label generation, tracking, webhooks, wallet, insurance, returns, and more.

## Installation

Add to your Gemfile:

```ruby
gem "flexops"
```

Then:

```bash
bundle install
```

Or install directly:

```bash
gem install flexops
```

## Quick Start

```ruby
require "flexops"

# API key authentication (recommended for server-to-server)
client = FlexOps::Client.new(
  api_key: "live_...",
  workspace_id: "your-workspace-id"
)

# Get shipping rates from all carriers
rates = client.shipping.get_rates(
  origin: {addressLine1: "123 Main St", city: "New York", stateProvince: "NY", postalCode: "10001"},
  destination: {addressLine1: "456 Oak Ave", city: "Los Angeles", stateProvince: "CA", postalCode: "90210"},
  package: {weight: 16, weightUnit: "oz"}
)

request = {
  carrierCode: "USPS", serviceCode: "GROUND_ADVANTAGE",
  origin: {name: "Warehouse", addressLine1: "123 Main St", city: "New York", stateProvince: "NY", postalCode: "10001", countryCode: "US"},
  destination: {name: "Customer", addressLine1: "456 Oak Ave", city: "Los Angeles", stateProvince: "CA", postalCode: "90210", countryCode: "US"},
  package: {weight: 16, weightUnit: "oz"},
  maximumPostageAmount: 10.25, # Caller-approved ceiling in USD.
  # Required without an orderId. The SDK never fills it in; NONE (0) = not hazardous.
  hazmatClassification: FlexOps::HazmatClassification::NONE
}
preview = client.shipping.create_label(request)
puts preview["quotedPostageAmount"]

# Call only after explicit caller approval, within five minutes.
purchase_approved_label = lambda do |purchase_key|
  client.shipping.create_label(
    request.merge(confirmationToken: preview["confirmationToken"]),
    idempotency_key: purchase_key # Persist per purchase; reuse on retries.
  )
end

# Track a shipment
info = client.shipping.track("9400111899223456789012")
```

### Live label approval (1.1.0+)

The example below requires SDK 1.1.0 or later. Version 1.0.2 does not
include the per-call idempotency argument.

For live domestic single-label requests, `maximumPostageAmount` is required: positive
USD, at most two decimal places, up to 1,000,000. Missing or invalid values return
400 `ApprovalRequired`. Omitting `confirmationToken` returns a raw 200 preview
(`status`, `quotedPostageAmount`, `maximumPostageAmount`, `currency`, `expiresAt`,
`confirmationToken`). After explicit approval, resubmit the same shipment and ceiling
with the token and a unique per-purchase `Idempotency-Key` header. The token expires
after five minutes. A successful purchase returns the raw 201 label, including
`labelId`, `trackingNumber`, `carrierCode`, and `labelData`, without a `data` wrapper.

Keep the same key and request across retries. An uncertain outcome needs reconciliation;
do not start another purchase with a new key. An expired approval returns 409
`ApprovalExpired`; obtain and explicitly approve a fresh preview when no purchase is
unresolved. The ceiling bounds postage authorization, not later adjustments or separate
fees. Sandbox execution bypasses approval; batch, return, and raw carrier routes have
separate contracts. The SDK never automatically confirms a preview.

## Authentication

### API key (recommended)

```ruby
client = FlexOps::Client.new(api_key: "live_...", workspace_id: "your-workspace-id")
```

### Email / password

```ruby
client = FlexOps::Client.new(base_url: "https://gateway.flexops.io")
session = client.auth.login(email: "user@example.com", password: "password")
client.set_access_token(session["data"]["token"])
client.workspace_id = "your-workspace-id"
```

## Sandbox / test keys

Use `test_...` (instead of `live_...`) to route to the sandbox environment. Mock carriers respond, nothing hits real carrier APIs, no charges, no real labels. Perfect for CI and integration tests.

```ruby
client = FlexOps::Client.new(api_key: "test_...", workspace_id: "your-workspace-id")
```

## Carrier-specific calls

`client.carriers.usps`, `.ups`, `.fedex` and `.dhl` call carrier routes through the legacy
`/api/ApiProxy` passthrough, which the Gateway retires on 2027-06-30.

- Lookups (GET), such as address checks, tracking and DHL rates, work with an API key or a user
  token.
- The writes (POST, PUT and DELETE, such as `usps.get_domestic_rates`, `fedex.cancel_shipment`
  or `ups.create_pickup`) are deprecated. They need a user token from `auth.login`: API keys get
  403 `API_KEY_SCOPE_REQUIRED`, and no API-key scope will be added for them. They stop working when
  the proxy is retired.
- Label generation through the proxy is closed (410 Gone), so the SDK has no carrier label
  method.

Use the native routes instead where they cover the call:

| Instead of | Use |
|---|---|
| Carrier rate calls | `client.shipping.get_rates` |
| Carrier labels | `client.shipping.create_label` (`client.returns.generate_label` for returns) |
| Label cancels | `client.shipping.cancel_label` |
| Carrier pickups | `client.pickups.schedule`, `list`, `get`, `cancel` |
| USPS scan forms | `client.scan_forms.create` |
| Address validation | `client.shipping.validate_address` |
| Tracking | `client.shipping.track` |

```ruby
# USPS city and state for a ZIP code (works with an API key)
place = client.carriers.usps.city_state_lookup("10001")
```

## Retries and idempotency

The client retries a request up to three times with exponential backoff:

- GET: after a dropped connection or timeout, and on 429, 500, 502, 503 and 504.
- POST, PUT and PATCH: after a dropped connection or timeout, and on 429, 502, 503, 504 and
  409 `IDEMPOTENCY_CONFLICT` (the first request with that key is still running). Never on 500:
  the Gateway does not replay a 5xx, so a retry could run the write (and charge the wallet)
  again.
- DELETE: only on 429.

A key reused with a different request body gets 422 `IDEMPOTENCY_KEY_REUSED`; it is not retried
and raises `FlexOps::Error` with that `code`. Error codes are matched exactly, so a label
purchase's own 409 `IdempotencyConflict` (altered inputs under a used key) is not retried either.

Every POST, PUT and PATCH carries an `Idempotency-Key` header. Pass your own to
`shipping.create_label(request, idempotency_key: ...)`, `insurance.purchase(..., idempotency_key: ...)`
or `carbon_offsets.purchase(..., idempotency_key: ...)`, and store it so a retry your app makes after
an error or a timeout reuses it; otherwise the client generates one UUID
per call and sends it on every retry of that call, so the Gateway replays a write it already
finished instead of running it twice. A 2xx response with no body returns `nil`.

## Workspace members

Roles are the Gateway `WorkspaceRole` numbers (Owner 0, Admin 1, Member 2, Merchant 3). Pass a
`FlexOps::WorkspaceRole` constant or a name; the SDK sends the number.

```ruby
client.workspaces.invite_member(email: "ops@example.com", role: :member)
client.workspaces.update_member_role(user_id, FlexOps::WorkspaceRole::ADMIN)

result = client.workspaces.list_members
members = result["data"]["members"] # also "pendingInvites", "userLimit", "canInviteMore"
```

## Recurring shipments, report schedules and email templates

Reads work with any API key or a user token. Writes (every POST, PUT and DELETE, including the
email template preview) need a user token from `auth.login` or an API key granted the
resource's opt-in scope: `recurring-shipments:write`, `report-schedules:write` or
`email-templates:write`. Older keys do not have these scopes; a key without one gets 403
`API_KEY_SCOPE_REQUIRED` with `requiredScopes`. Enums are sent as numbers and ids are GUID
strings.

```ruby
# Recurring shipments (bare JSON). interval: Daily 0, Weekly 1, Biweekly 2, Monthly 3, Custom 4
schedule = client.recurring_shipments.create(
  name: "Weekly restock", addressId: address_id, presetId: preset_id,
  interval: 1, firstRunUtc: "2026-11-02T14:00:00Z"
)
client.recurring_shipments.pause(schedule["id"])  # nil (204); also resume, delete
client.recurring_shipments.trigger(schedule["id"], idempotency_key: run_key) # creates an order now

# Report schedules ({ success, data, message } envelope).
# format: Csv 0, Json 1; frequencyType: Daily 0, Weekly 1, Monthly 2
report = client.report_schedules.create(
  reportType: "shipments", format: 0, frequencyType: 1, dayOfWeek: 1,
  timeOfDayUtc: "08:00:00", recipientEmails: "ops@example.com"
)["data"]
client.report_schedules.toggle(report["id"]) # flips isEnabled

# Tracking email templates (bare JSON), one per event. eventType: LabelCreated 0, InTransit 1,
# OutForDelivery 2, Delivered 3, Exception 4, ReturnToSender 5
client.email_templates.upsert(eventType: 3, subjectTemplate: "Delivered: {{tracking_number}}",
                              htmlBodyTemplate: "<p>Your package arrived.</p>")
client.email_templates.preview(subject_template: "Hi {{recipient_name}}", html_body_template: "<p>{{status}}</p>")
```

## Multi-package labels

One order shipped in several boxes with the same carrier and service; each box gets its own label and
a box that fails does not stop the others. Multi-package labels cannot carry HAZMAT: send
`FlexOps::HazmatClassification::NONE` or leave `hazmatClassification` out. `maximumPostageAmount` is required: the
most the whole shipment may cost in USD (positive, at most two decimals). The Gateway refuses to buy a box that would
take the total above it (`PriceCeilingExceeded`; once the amount is used up the remaining boxes report
`PriceCeilingReached`), and a request without a valid ceiling is 400 `ApprovalRequired`.

```ruby
begin
  shipment = client.shipping.create_multi_package(
    { orderId: 12345, carrierCode: "USPS", serviceCode: "PRIORITY",
      hazmatClassification: FlexOps::HazmatClassification::NONE,
      maximumPostageAmount: 25.00, # required: the most the whole shipment may cost, in USD
      packages: [{ weightInOunces: 16, lengthInInches: 10, widthInInches: 8, heightInInches: 4, packageReference: "Box 1 of 2" },
                 { weightInOunces: 8, lengthInInches: 6, widthInInches: 6, heightInInches: 6, packageReference: "Box 2 of 2" }] },
    idempotency_key: "order-12345-boxes" # optional; reuse it when you retry
  )
rescue FlexOps::Error => e
  # No label was bought: 422 AllPackagesFailed, or 409 OutcomeUnknown when a label may exist
  # (check the order before buying again). e.data holds the per-box results.
end
```

`client.returns.get` reads a received return by its numeric return id; read an RMA with
`client.returns.get_rma("RMA-1001")` or page through them with `client.returns.list_rmas`.

## Wallet balance

```ruby
balance = client.wallet.get_balance # {"hasWallet" => true, "balanceCents" => 1250, "balance" => 12.5}
```

The request carries `X-Workspace-Id` set to the client's `workspace_id`. Funding and
transaction history are managed in the FlexOps portal.

## Webhook subscriptions

Managing webhooks needs a signed-in user's access token. The Gateway refuses API keys on every webhook route, reads included (`list` and `list_delivery_logs` as well as `create`, `update`, `delete`, `rotate_secret` and `test`), with 403 `SIGNED_IN_USER_REQUIRED`, whatever the key's scopes; the SDK raises `FlexOps::Error` with that `code`. Reads are refused too because webhook delivery logs carry each delivery's payload (order and customer data). A client with an API key sends the key even when an access token is also set, so use a client created without `api_key`. Verifying deliveries (below) makes no request and needs no credentials.

```ruby
# Sign in as a user (or pass access_token:); an API key gets 403 SIGNED_IN_USER_REQUIRED here.
client = FlexOps::Client.new(workspace_id: "your-workspace-id")
session = client.auth.login(email: "user@example.com", password: "password")
client.set_access_token(session["data"]["token"])

# Leave events out to receive every event.
webhook = client.webhooks.create(
  url: "https://your-app.com/webhooks/flexops",
  events: [FlexOps::WebhookEventType::LABEL_CREATED,
           FlexOps::WebhookEventType::LABEL_CANCELED,
           FlexOps::WebhookEventType::BATCH_COMPLETED]
)
signing_secret = webhook["secret"] # "whsec_...", returned only on create; store it

# Change the events (or url, description, status: "Active", "Paused", "Disabled").
client.webhooks.update(webhook["id"], events: [FlexOps::WebhookEventType::LABEL_CREATED])
```

`create` returns the subscription itself (`"id"`, `"url"`, `"eventTypes"`, `"status"`, `"secret"`, ...), because the Gateway answers it with the bare subscription. The other webhook methods return the usual `{"success" => true, "data" => ...}` envelope.

`events` is sent as the Gateway's comma-separated `eventTypes`. FlexOps sends these events, named exactly as below (`FlexOps::WebhookEventType::ALL` lists them). Names are PascalCase and matched exactly, so a name like `label.created` would never match; `create` and `update` raise `ArgumentError`, before any request, for an unknown name, an empty list or a non-array.

| Event | Sent when |
|---|---|
| `LabelCreated` | A live label is purchased (sandbox labels send nothing) |
| `LabelCanceled` | A live label is voided |
| `BatchCompleted` | A batch label job finishes |
| `TrackingUpdated` | A USPS tracking scan arrives (USPS push-tracking pilot workspaces only) |
| `TrackingDelivered` | A USPS package is delivered (USPS push-tracking pilot workspaces only) |

You can send a raw `eventTypes:` string (`"*"` or names joined by commas with no spaces) instead of `events:`; it is passed through unchecked, for example to subscribe to an event newer than your SDK version.

## Webhook verification

FlexOps signs each delivery with HMAC-SHA256 over `{X-FlexOps-Timestamp}.{raw body}`, keyed with your subscription secret (`whsec_...`, used as-is), and sends it as `X-FlexOps-Signature: sha256=<hex>`. Verify the raw body before you parse it.

```ruby
# Rails controller action
def flexops_webhook
  payload = request.raw_post

  valid = FlexOps::Resources::Webhooks.verify_signature(
    payload:   payload,
    signature: request.headers["X-FlexOps-Signature"], # "sha256=..."
    timestamp: request.headers["X-FlexOps-Timestamp"], # Unix seconds
    secret:    ENV.fetch("FLEXOPS_WEBHOOK_SECRET")      # "whsec_..."
  )
  return head :unauthorized unless valid

  # The body is the event data itself (no type/data envelope).
  # The event name is in a header; test events send "test".
  data = JSON.parse(payload)
  case request.headers["X-FlexOps-Event"]
  when "test"
    # data: {"type"=>"test", "message"=>"...", "timestamp"=>"...", "subscriptionId"=>"..."}
  when "TrackingUpdated"
    # data["trackingNumber"], data["status"], ...
  end
  head :ok
end
```

Deliveries whose timestamp is more than 300 seconds from your clock (either way) are rejected to limit replays; pass `tolerance:` (seconds) to change that. `verify_signature!` takes the same arguments and raises `FlexOps::WebhookSignatureError` instead of returning `false`; its `code` says why (`WEBHOOK_SIGNATURE_MISMATCH`, `WEBHOOK_TIMESTAMP_OUTSIDE_TOLERANCE`, `WEBHOOK_INVALID_TIMESTAMP`, `WEBHOOK_MISSING_SIGNATURE`, `WEBHOOK_MISSING_SECRET`).

## Curl quickstart

Every SDK method is a thin wrapper around the FlexOps REST API. If you want to verify the API before committing to the SDK — or you're integrating from a language we don't ship a SDK for — these curl invocations hit the same endpoints:

```bash
# Shop rates across all connected carriers
curl -X POST https://gateway.flexops.io/api/shipping/rates \
  -H "X-API-Key: live_..." \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"addressLine1": "123 Main St", "city": "New York", "stateProvince": "NY", "postalCode": "10001", "countryCode": "US"},
    "destination": {"addressLine1": "456 Oak Ave", "city": "Los Angeles", "stateProvince": "CA", "postalCode": "90210", "countryCode": "US"},
    "package": {"weight": 16, "weightUnit": "oz"}
  }'

# Preview a live label; this does not purchase it.
# hazmatClassification 0 = not hazardous; required when there is no orderId.
curl -X POST https://gateway.flexops.io/api/shipping/labels \
  -H "X-API-Key: live_..." \
  -H "Content-Type: application/json" \
  -d '{
    "carrierCode": "USPS", "serviceCode": "GROUND_ADVANTAGE",
    "origin": {"name": "Warehouse", "addressLine1": "123 Main St", "city": "New York", "stateProvince": "NY", "postalCode": "10001", "countryCode": "US"},
    "destination": {"name": "Customer", "addressLine1": "456 Oak Ave", "city": "Los Angeles", "stateProvince": "CA", "postalCode": "90210", "countryCode": "US"},
    "package": {"weight": 16, "weightUnit": "oz"},
    "maximumPostageAmount": 10.25,
    "hazmatClassification": 0
  }'

# After explicit approval, resend the same body with confirmationToken from
# the preview and an Idempotency-Key header unique to this purchase.
# See the SDK example above; retain that key for retries.

# Track a shipment
curl https://gateway.flexops.io/api/shipping/track/9400111899223456789012 \
  -H "X-API-Key: live_..."

# Cancel a label
curl -X DELETE "https://gateway.flexops.io/api/shipping/labels/lbl_123?carrierCode=USPS" \
  -H "X-API-Key: live_..."
```

Use a `test_...` key instead of `live_...` to hit the sandbox environment; mock carriers respond, no real charges, no real labels.

## Resources

| Resource | Description |
|----------|-------------|
| `client.auth` | Login, token refresh, logout |
| `client.workspaces` | List and read workspaces; list, invite and remove members, change roles |
| `client.shipping` | Rate shopping, labels, multi-package labels, tracking, address validation, batch, cancel |
| `client.carriers` | USPS, UPS, FedEx and DHL calls through the legacy proxy; writes are deprecated and need a user token |
| `client.webhooks` | Subscription create/update/delete, secret rotation, test events, delivery logs, signature verification |
| `client.wallet` | Workspace balance |
| `client.insurance` | Providers, quotes, policies, void, claims |
| `client.returns` | List and read received returns; create, read and list RMAs; return labels; receive |
| `client.analytics` | Shipments, orders, carrier performance (legacy proxy reads) |
| `client.orders` | Order reads (legacy proxy) |
| `client.inventory` | Inventory reads (legacy proxy) |
| `client.pickups` | Schedule, list, read and cancel carrier pickups |
| `client.scan_forms` | USPS scan forms |
| `client.rules` | Shipping rules: create, read, update, delete, reorder, test |
| `client.hs_codes` | HS code search and lookup, landed cost |
| `client.carbon_offsets` | Carbon offset quotes, purchases, summary and settings |
| `client.recurring_shipments` | Recurring shipment schedules: create, update, pause, resume, trigger, delete |
| `client.report_schedules` | Scheduled report emails: create, update, toggle, delete |
| `client.email_templates` | Tracking email templates: upsert, preview, delete |

API keys, workspace settings and account management are managed in the FlexOps portals.

## Configuration

```ruby
client = FlexOps::Client.new(
  base_url:     "https://gateway.flexops.io",  # API base URL
  api_key:      "live_...",                # API key auth
  workspace_id: "your-workspace-id",       # Default workspace
  timeout:      30                         # Request timeout (seconds)
)
```

## Requirements

- Ruby 3.1+

## License

MIT © FlexOps, LLC. See [LICENSE](LICENSE) for full text.
