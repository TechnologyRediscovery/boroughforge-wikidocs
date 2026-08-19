---
title: Distribution Channels and Webhooks
description: LetterDistributionEntry, the Resend email send path, the inbound delivery-status webhook, and the physical channels
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:dev, type:architecture
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Distribution Channels and Webhooks

`LetterDistributionEntry` (Phase 15.1, table `letterdistributionentry`, renamed from
`lettermailingattempt`) is the single row type for every way a finalized letter is
distributed — mail, email, posting/placard, hand delivery, or a door-hanger courtesy notice.
One append-only history per letter, one entity, channel-specific fields left null when
irrelevant.

## `LetterDistributionMethod` — the channel enum

```java
public enum LetterDistributionMethod {
    FIRST_CLASS_MAIL, CERTIFIED_MAIL, HAND_DELIVERY,
    DOOR_HANGER, POSTING_PLACARD, EMAIL_NON_CNF, EMAIL_CNF_API;

    public enum Kind { PHYSICAL_MAIL, PHYSICAL, ELECTRONIC }
}
```

Each value carries: `label`, `kind`, `requiresTrackingNumber` (certified mail only),
`requiresPhysicalPresence` (drives whether the UI offers evidence-photo capture), and an
**audit/attributability axis** (II.E) — three booleans that answer "who logged this and can
it be undone":

- **`userAttributable`** — true for every channel except `EMAIL_CNF_API`. A user-attributable
  entry was logged by an identifiable human acting on their own account (mail, hand delivery,
  posting, or an email sent *outside* CNF and just recorded here).
- **`creatorCanDeacSameDay`** / **`managerCanDeacSecondDayOrLater`** — who can deactivate a
  mistaken entry, and when.
- **`EMAIL_CNF_API` is the one non-user-attributable channel** — an automated system
  transmission. Once logged, it hard-locks the letter forever: not even a system admin may
  deactivate it or its parent letter. This is why the in-app "Sending via CodeNforce email
  hard-locks the letter forever" warning is unconditional, not permission-gated — there's no
  override path by design.

`DOOR_HANGER` vs. `POSTING_PLACARD` are kept as separate channels (not one "posting" channel
with a sub-type flag) because their legal weight differs: a door-hanger is a courtesy notice,
a placard is an IPMC-specified posting with conspicuous-visibility requirements — different
default templates apply.

## Physical channels (mail, hand delivery, posting, door-hanger)

`LetterCoordinator.letter_recordMailingAttempt(...)` (mail/hand-delivery, via the
**mark-sent** dialog) and `letter_distributeByPosting(...)` (posting/placard/door-hanger, via
the **record-posting** dialog) both write a `LetterDistributionEntry` directly — no external
service involved. `letter_distributeByPosting` additionally handles the optional evidence
photo: when photo bytes are supplied, the blob is inserted and linked to the **letter**
(via `BlobCoordinator.insertBlobAndInsertMetadataAndLinkToParent`) *before* the distribution
entry is written, and the returned photodoc id is stamped onto
`distributionEvidencePhotodocId` — the composite FK
`letterdistributionentry_distevidence_fk` guarantees the photo actually belongs to that
letter. A photo is "rich-optional" (D4): never required, strongly encouraged for placards.

The amendment/supersede model carries over from the original mailing-attempt design: any
channel's entry can be superseded by an `amendmentOfEntryId`-linked amendment rather than
edited in place, and any entry can be soft-deactivated (`deactivatedTs`) — the details
dialog's "show superseded records" / "show deactivated records" checkboxes control whether
these hidden-by-default rows are shown.

## Email channel — `letter_distributeByEmail()`

Sends the finalized letter via the Resend API and logs a `EMAIL_CNF_API` distribution entry:

1. Preconditions: the letter must be finalized (`lockedAndQueuedTs != null`) with non-empty
   `renderedHtml`, and a non-blank recipient address must be supplied (already
   suggest-and-confirmed by the officer in the Email Letter dialog — see D11).
2. **Email body (D2 option b):** a short cover note + the full rendered letter HTML inline,
   with the Phase 8 finalization PDF attached **when one exists** — when no PDF is available
   the message degrades gracefully to HTML-only (D5 soft prerequisite; never blocks the send).
3. Sends via `CommunicationCoordinator.sendEmail(...)`, which never throws on an API-level
   error — failure is captured in the returned `EmailLog` instead, so a Resend outage doesn't
   crash the officer's request.
4. Writes the `LetterDistributionEntry` with `distributionMethod = EMAIL_CNF_API`, linking
   `emailLogId` to the just-created log row, and an initial `emailDeliveryStatus` of `"sent"`
   or `"failed"` based on whether the log recorded a Resend error.

`CommunicationCoordinator` (also shared with the CEAR emailing subsystem) loads
`resend.api.key`, `resend.from.address`/`resend.from.name`, and `resend.environment` from
`codenforce.properties` at CDI startup; `resend.environment=test` writes emails to stdout only
(no live API call) — see `CommunicationCoordinator.loadEmailConfig()`.

## Inbound delivery-status webhook (Phase 14B)

Resend calls back into CodeNforce as delivery events happen (delivered, bounced, opened,
clicked, complained, delayed) via a webhook — this is what keeps
`LetterDistributionEntry.emailDeliveryStatus` current without polling.

**Endpoint:** `POST /api/webhooks/resend/letter` — `LetterEmailWebhookResource` (JAX-RS,
`@Path("/webhooks")` + `/resend/letter`).

### Signature verification — Svix envelope, not a bare HMAC of the body

Resend delivers webhook signatures via the **Svix** envelope format. This is easy to get
subtly wrong, so the exact scheme (`CommunicationCoordinator.comm_verifyResendWebhookSignature`)
is worth stating precisely:

1. **Raw bytes only.** The JAX-RS method captures the request body as `byte[]`, never
   `String` — no JSON provider or charset round-trip is allowed to touch the bytes before the
   signature is checked; the body is only parsed with Jackson *after* verification succeeds.
2. **Signed content is `<svix-id>.<svix-timestamp>.<raw body>`** — three parts joined with
   `.`, **not** the raw body alone.
3. **HMAC-SHA256**, keyed with the webhook secret **after** stripping its `whsec_` prefix and
   base64-decoding the remainder. There is deliberately no fallback to raw UTF-8 bytes if the
   base64 decode fails — a misconfigured secret must fail loudly, not silently "succeed" via a
   second, non-spec encoding.
4. **Replay-tolerance window:** `svix-timestamp` must be within `WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS`
   (300s) of server time, or the request is rejected outright — a captured legitimate request
   would otherwise carry a perpetually-valid signature.
5. **Header fallback:** checks `Svix-Signature` first, falling back to `Resend-Signature` if
   blank — the signature value itself is space-delimited `v1,<base64sig>` tokens; any one
   matching is sufficient (supports secret rotation).

The resource always returns `200` for events it processed *or* safely ignored (so Resend
doesn't retry non-actionable payloads), `401` only on signature failure, and `400` on an
unparseable body.

### Event processing — `LetterCoordinator.letter_processResendDeliveryEvent`

```java
public boolean letter_processResendDeliveryEvent(String eventType, String resendMessageId)
```

1. `mapResendEventToStatus(eventType)` normalizes the Resend event type
   (`email.delivered` → `delivered`, `email.bounced` → `bounced`, `email.complained` →
   `complained`, `email.opened` → `opened`, `email.clicked` → `clicked`,
   `email.delivery_delayed` → `delayed`; anything else → unhandled, returns `false`).
2. Resolves the `EmailLog` by Resend message id (`SystemIntegrator.getEmailLogByResendMessageId`),
   then the owning `LetterDistributionEntry` by that log's id
   (`LetterIntegrator.getDistributionEntryByEmailLogId`).
3. Stamps the normalized status + timestamp onto the entry
   (`LetterIntegrator.updateEntryEmailDeliveryStatus`).

The method is **idempotent** — re-applying the same event just re-writes the same status and
timestamp, since Resend (like most webhook providers) does not guarantee exactly-once
delivery.

See also: [Clone/copy architecture](/dev/subsystems/letters/clone-copy-architecture),
[Mail-merge token implementation](/dev/subsystems/letters/mail-merge-token-implementation).

Back to: [Letters & Emailing — Developer Notes](/dev/subsystems/letters/overview)
