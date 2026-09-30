---
title: Code Enforcement Action Requests (CEAR) — Developer Notes
description: How CEARs are submitted, routed by officers, and notified about via email.
published: true
date: 2026-09-28T00:00:00.000Z
tags: subsystem:cear, audience:dev, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Code Enforcement Action Requests (CEAR) — Developer Notes

A **Code Enforcement Action Request (CEAR)** is a complaint or municipal concern submitted to
the CE office, either by the public (unauthenticated) or by staff on a caller's behalf. Once
submitted, officers route each CEAR through a 3-step modal flow (property confirm → route
selection → execute) that either attaches it to a code enforcement case/occupancy period or
closes it out (invalid request, no violation found, muni-general action complete). Every stage
is wired to an email-notification layer (`CommunicationCoordinator`) covering both staff
subscribers and, increasingly, the original public/internal submitter.

## Current architecture

See [CEAR Processing Logic](/dev/subsystems/cear/cear-logic) for the full submission → routing
→ status-lifecycle → email-notification walkthrough.

## In-flight feature work

Design specs, open questions, and in-progress features for this subsystem are tracked in the
codenforce repo's own dev index (per convention, "how it works" lives here; feature/debugging
work-in-progress stays in the JSF repo): `docs/subsystems/cear/cear-index.md`.

## See also

- [Communication — Developer Notes](/dev/subsystems/communication/overview) — the shared
  Resend/webhook transport layer CEAR email rides on
- [Letters & Emailing hub](/system/subsystems/letters) — the sibling subsystem sharing the same
  transport infra

Back to: [hub page](/system/subsystems/cear) · [subsystem registry](/system/subsystem-registry) entry #20

