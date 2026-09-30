---
title: Communication — Developer Notes
description: Architecture summary for the email/SMS transport-layer subsystem
published: true
date: 2026-09-28T00:00:00.000Z
tags: subsystem:communication, audience:dev, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Communication — Developer Notes

`CommunicationCoordinator` is the shared outbound-email transport used across CodeNforce —
CEAR confirmation/routing/update-blast emails and the Letters subsystem's `EMAIL_CNF_API`
distribution channel both send through it. See `letters` (entry #12 in the
[subsystem registry](/system/subsystem-registry)) for letter *content/template authoring* —
this subsystem is transport/delivery only; SMS is planned but not yet built.

## Current architecture

- **Outbound send, CEAR email features, and Resend webhook signature verification** — see
  [Resend email facility and webhook verification](/dev/subsystems/communication/resend-email-and-webhooks)
  for the full send path, every CEAR email feature built on it (subscription/routing/update
  blasts, per-muni blast settings), the inbound delivery-status webhook, and a primer on the
  Svix envelope / HMAC signing scheme it relies on.

See also: [Letters — distribution channels and webhooks](/dev/subsystems/letters/distribution-channels-and-webhooks)
for the letter-specific `EMAIL_CNF_API` channel and the only webhook receiver currently wired up.

Back to: [Communication hub](/system/subsystems/communication) · [subsystem registry](/system/subsystem-registry) entry #17.
