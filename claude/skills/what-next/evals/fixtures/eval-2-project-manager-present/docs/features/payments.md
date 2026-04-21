---
feature: Payments
slug: payments
status: draft
priority: p2
area: payments
depends_on: [auth]
last_updated: 2026-04-15
---

# Payments

## Overview
Accept credit card payments via Stripe.

## Capabilities
- [ ] One-off checkout
- [ ] Subscription plans

## Requirements
- PCI compliance via Stripe-hosted fields

## Acceptance Criteria
- Given valid card, when checkout submitted, then PaymentIntent is created.

## Out of Scope
- Crypto payments
