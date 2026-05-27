# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`flexops` is the **official hand-crafted Ruby SDK** for the FlexOps Platform. It targets the FlexOps **Gateway BFF**. Published to RubyGems as `flexops`; current tag `v1.0.1`.

> **Gateway-targeted, not VSCS-targeted.** All hand-crafted SDKs in this family (.NET, Node, Python, Go, PHP, Ruby) hit Gateway. The Java SDK is the lone exception — it was auto-generated against VisionSuiteCoreServices and is archived as of 2026-03-08.

## Build & Run Commands

```bash
bundle install                  # Install dependencies
bundle exec rspec               # Run tests
gem build flexops.gemspec       # Build the gem locally (produces flexops-X.Y.Z.gem)
```

## Architecture

```text
Customer Ruby app  →  flexops (this repo)  →  Gateway BFF (gateway.flexops.io)
                                              ↓
                                              VSCS / Integrations / etc.
```

## Key Directories

| Path | Purpose |
|---|---|
| `lib/flexops/` | Gem source — client, version, models, errors |
| `lib/flexops/version.rb` | Single source of truth for the gem version (referenced from `flexops.gemspec`) |
| `spec/` | RSpec tests |
| `flexops.gemspec` | Gem metadata |
| `Gemfile` | Bundler-managed dev/test dependencies |
| `CHANGELOG.md` | Per-release notes |

## Conventions

- Gem version is single-sourced from `lib/flexops/version.rb` (`FlexOps::VERSION`) — bump it, don't hardcode versions elsewhere.
- Errors come back as typed exception classes carrying Gateway's error envelope — don't raise `StandardError` directly.
- Keep dependency surface small; consumers bundle this into wildly different Ruby host apps.

## Publish

GitHub Actions handles RubyGems publish via **OIDC trusted publishing** (no long-lived `RUBYGEMS_API_KEY`). Bump `FlexOps::VERSION` in `lib/flexops/version.rb`, tag, push — the workflow does `gem build` and `gem push`.

## Related Repositories

| Repository | Purpose |
|---|---|
| **This repo** | `flexops` on RubyGems |
| FlexOps Gateway | The HTTP API this SDK calls — `BillEisenman/FlexOpsGateway` |
| Sibling SDKs | `FlexOps.Sdk` (.NET), `@flexops/sdk` (Node), `flexops` (Python), `flexops/sdk` (PHP), `flexops-sdk-go` (Go) |
| FlexOps Developer Docs | Hosts the SDK page — `BillEisenman/FlexOpsDeveloperDocs` |
