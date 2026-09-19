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
  api_key: "fxk_live_...",
  workspace_id: "ws_abc123"
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
  maximumPostageAmount: 10.25 # Caller-approved ceiling in USD.
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

### Live label approval (unreleased SDK changes)

The example below requires this source revision; the published 1.0.2 packages do
not include the new per-call idempotency argument. Release these SDK changes before
using that argument from a package registry.

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
client = FlexOps::Client.new(api_key: "fxk_live_...", workspace_id: "ws_abc123")
```

### Email / password

```ruby
client = FlexOps::Client.new(base_url: "https://gateway.flexops.io")
client.auth.login(email: "user@example.com", password: "password")
client.workspace_id = "ws_abc123"
```

## Sandbox / test keys

Use `fxk_test_...` (instead of `fxk_live_...`) to route to the sandbox environment. Mock carriers respond, nothing hits real carrier APIs, no charges, no real labels. Perfect for CI and integration tests.

```ruby
client = FlexOps::Client.new(api_key: "fxk_test_...", workspace_id: "ws_abc123")
```

## Direct carrier operations

Access carrier-specific endpoints when you need full control:

```ruby
# USPS domestic label
label = client.carriers.usps.create_domestic_label(
  image_type: "PDF",
  mail_class: "PRIORITY_MAIL",
  weight_in_ounces: 16
)

# FedEx rate quote
rates = client.carriers.fedex.get_rates(...)

# UPS tracking
info = client.carriers.ups.track(tracking_number: "1Z999AA10123456784")

# DHL shipment
shipment = client.carriers.dhl.create_shipment(...)
```

## Webhook verification

```ruby
valid = FlexOps::Resources::Webhooks.verify_signature(
  payload:   request.body.read,
  signature: request.headers["X-FlexOps-Signature"],
  secret:    "whsec_..."
)
```

## Curl quickstart

Every SDK method is a thin wrapper around the FlexOps REST API. If you want to verify the API before committing to the SDK — or you're integrating from a language we don't ship a SDK for — these curl invocations hit the same endpoints:

```bash
# Shop rates across all connected carriers
curl -X POST https://gateway.flexops.io/api/shipping/rates \
  -H "X-API-Key: fxk_live_..." \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"addressLine1": "123 Main St", "city": "New York", "stateProvince": "NY", "postalCode": "10001", "countryCode": "US"},
    "destination": {"addressLine1": "456 Oak Ave", "city": "Los Angeles", "stateProvince": "CA", "postalCode": "90210", "countryCode": "US"},
    "package": {"weight": 16, "weightUnit": "oz"}
  }'

# Preview a live label; this does not purchase it.
curl -X POST https://gateway.flexops.io/api/workspaces/ws_abc123/shipping/labels \
  -H "X-API-Key: fxk_live_..." \
  -H "Content-Type: application/json" \
  -d '{
    "carrierCode": "USPS", "serviceCode": "GROUND_ADVANTAGE",
    "origin": {"name": "Warehouse", "addressLine1": "123 Main St", "city": "New York", "stateProvince": "NY", "postalCode": "10001", "countryCode": "US"},
    "destination": {"name": "Customer", "addressLine1": "456 Oak Ave", "city": "Los Angeles", "stateProvince": "CA", "postalCode": "90210", "countryCode": "US"},
    "package": {"weight": 16, "weightUnit": "oz"},
    "maximumPostageAmount": 10.25
  }'

# After explicit approval, resend the same body with confirmationToken from
# the preview and an Idempotency-Key header unique to this purchase.
# See the SDK example above; retain that key for retries.

# Track a shipment
curl https://gateway.flexops.io/api/workspaces/ws_abc123/shipping/track/9400111899223456789012 \
  -H "X-API-Key: fxk_live_..."

# Cancel a label (via the unified carrier-agnostic endpoint)
curl -X DELETE https://gateway.flexops.io/api/v3.0/shipping/Usps/cancel/9400111899223456789012 \
  -H "X-API-Key: fxk_live_..."
```

Use an `fxk_test_...` key instead of `fxk_live_...` to hit the sandbox environment; mock carriers respond, no real charges, no real labels.

## Resources

| Resource | Description |
|----------|-------------|
| `client.auth` | Login, register, password management |
| `client.workspaces` | Workspace CRUD, membership, branding |
| `client.shipping` | Rate shopping, labels, tracking, batch, cancel |
| `client.carriers` | USPS, UPS, FedEx, DHL direct endpoints |
| `client.webhooks` | Subscription CRUD, signature verification, delivery logs |
| `client.wallet` | Balance, transactions, auto-reload |
| `client.insurance` | Quotes, purchase, claims (first-party + U-PIC) |
| `client.returns` | RMA lifecycle: create, batch, QR codes, photo upload, cost recovery |
| `client.api_keys` | Key creation, rotation, revocation |
| `client.analytics` | Shipments, orders, carrier performance |
| `client.orders` | Order management |
| `client.inventory` | Warehouse inventory |
| `client.pickups` | Carrier pickup scheduling |
| `client.scan_forms` | USPS scan forms |
| `client.rules` | Shipping automation rules |
| `client.offsets` | Carbon offset purchases |
| `client.hs_codes` | HS code lookup for international customs |
| `client.recurring_shipments` | Scheduled recurring shipments |
| `client.email_templates` | Branded post-purchase email templates |
| `client.reports` | Report generation and scheduled delivery |

## Configuration

```ruby
client = FlexOps::Client.new(
  base_url:     "https://gateway.flexops.io",  # API base URL
  api_key:      "fxk_live_...",            # API key auth
  workspace_id: "ws_abc123",               # Default workspace
  timeout:      30                         # Request timeout (seconds)
)
```

## Requirements

- Ruby 3.0+

## License

MIT © FlexOps, LLC. See [LICENSE](LICENSE) for full text.
