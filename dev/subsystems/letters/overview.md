---
title: Letters & Emailing — Developer Notes
description: Architecture summary for the letters/correspondence subsystem
published: true
date: 2026-08-07T00:00:00.000Z
tags: subsystem:letters, audience:dev, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Letters & Emailing — Developer Notes

Letters can attach to a `CECase`, a `Property`/parcel, or an `OccPeriod` (permit file) via
`IFace_LetterHolder`. Core classes: `LetterCoordinator` (business logic), `LetterIntegrator`
(JDBC), `LetterFlowBB` (the 4-step creation dialog), `LetterHtmlRenderer` (mail-merge token
substitution), `LetterTemplate`/`LetterCodeViolation`/`LetterDistributionEntry` (entities).

## Current architecture (as of August 2026)

- **Clone/copy** — `LetterFlowMode` (`NEW_LETTER` / `PURE_CLONE` / `EDITABLE_COPY`) drives which
  fields are locked in the flow dialog. Pure clone writes `letter.cloneof_letterid` for a
  court-defensible identical copy; editable copy pre-fills text but sets no lineage FK.
- **Distribution** — `LetterDistributionEntry` (renamed from `LetterMailingAttempt`) records
  every distribution channel (mail, email, posting/placard, door-hanger) in one history,
  surfaced in `letterTableCC.xhtml`'s unified Distribution/Correspondence panel.
- **PDF** — `letter_generateFinalizationPDF()` renders the frozen HTML to PDF via
  openhtmltopdf-pdfbox at finalization time, inlining photos as base64 data URIs. See the
  [PDF & document encoding primer](/dev/subsystems/letters/pdf-encoding-primer) for the
  libraries involved, PDF format internals, and styling/encoding gotchas.
- **Email** — `letter_distributeByEmail()` sends via Resend, with inbound delivery-status
  webhooks (`LetterEmailWebhookResource`) updating the distribution entry.
- **Mail-merge tokens** — canonical registry is `LetterTokenType`; `LetterHtmlRenderer`
  performs substitution, gated by `isApplicableTo(LetterParentType)`.

Full implementation history, as-built deviations from spec, and the active backlog live in
the codenforce repo at `docs/subsystems/letters+emailing/` (`letterUpgrades-jul2026.md`,
`letterSubsystem-remainingWork-aug2026.md`) — that folder is engineering scratch space, not
end-user documentation, but it's the authoritative source for anything not covered here.

See also: [subsystem registry](/system/subsystem-registry), entry #12.
