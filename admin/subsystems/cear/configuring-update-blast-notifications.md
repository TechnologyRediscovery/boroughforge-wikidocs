---
title: Configuring CEAR update-blast notifications
description: Walkthrough of the "CEAR Subscriber Update Blasts" panel in Municipality Manager
published: true
date: 2026-09-30T00:00:00.000Z
tags: subsystem:cear, audience:admin, type:howto
editor: markdown
dateCreated: 2026-09-30T00:00:00.000Z
---

# Configuring CEAR update-blast notifications

This walks through the **"CEAR Subscriber Update Blasts"** panel — the per-municipality
control center for the update-blast notification system described in the
[CEAR admin overview](/admin/subsystems/cear/overview). If you haven't read that page yet,
start there for how this relates to the separate, always-on legacy routing blast.

## Where to find it

1. Go to **Muni Tools → Municipality Manager** and select the municipality you want to
   configure.
2. Scroll to the **"CEAR Subscriber Update Blasts"** panel. It's collapsed by default — click
   its header to expand it.

<!-- SCREENSHOT NEEDED: Municipality Manager page, collapsed "CEAR Subscriber Update Blasts"
panel header, before clicking to expand. -->

## The event table

Once expanded, the panel shows one row per blastable event type:

| Column | What it does |
|---|---|
| **Event** | The plain-language name of the event (see the full list below). |
| **Send Blasts** | A checkbox — on enables this event type for this municipality, off (the default) disables it entirely. |
| **Detail Level** | A dropdown (MINIMAL, STANDARD, or FULL) controlling how much the email body includes for this event type. Disabled/grayed out until you check "Send Blasts" for that row. |
| **Officer May Skip** | Informational only — always "yes." This cannot be changed; see the guarantee on the overview page. |

<!-- SCREENSHOT NEEDED: The expanded panel showing the full event table with a couple of rows
enabled (checkbox checked, detail level dropdown active) and a couple disabled (checkbox
unchecked, dropdown grayed out). -->

### The 9 event types

| Event (as shown in the panel) | Fires when |
|---|---|
| CEAR routed by officer | An officer commits any **terminal** routing decision on a CEAR: attached to an existing case, attached to a new case, attached to an occupancy period, marked invalid, referred to another department, or (muni-general only) marked action completed. Re-routing a CEAR back to unprocessed, or marking a muni-general concern's action as merely "underway," does **not** fire this — only a final/terminal outcome does. |
| Notice of violation sent | A notice of violation is marked sent on the CEAR's host case. |
| Code violation recorded | A code violation is attached to the CEAR's host case. |
| Violation marked compliant | A violation on the host case is marked compliant. |
| Violation nullified | A violation on the host case is nullified. |
| Compliance date extended | A stipulated compliance date is extended on a violation. |
| Citation status recorded | A citation status change is logged where that specific status (e.g. "Hearing Scheduled," "Dismissed," "Paid in Full") has been flagged as notifiable. Not every citation status change notifies — only the ones your codebook administrator has flagged. |
| Case closed | The CEAR's host case is closed. |
| Event logged (notify-monitors category) | An officer logs a case event whose category has been flagged as "notify monitors." Not every logged event notifies — only categories flagged that way. |

> Two of the rows above (citation status and event-category) only fire for the *specific*
> statuses/categories your codebook setup has separately flagged as notifiable — enabling the
> row here is necessary but not sufficient for those two. The other seven fire on every
> occurrence of that event once enabled.

## Detail levels

| Level | Email includes |
|---|---|
| MINIMAL | Muni name, the CEAR's public reference code, a plain-language statement of what happened, the property address (or a note that the request isn't tied to a specific address), any public note, and the unsubscribe link. |
| STANDARD | Everything in MINIMAL, plus event-specific specifics — e.g. the concern type for a routing blast, or an itemized list of affected violations for a batch action. |
| FULL | Reserved for future use — currently always sent at STANDARD detail regardless of what you select here. |

Pick STANDARD if you want requestors and staff to see real specifics; pick MINIMAL if you'd
rather keep emails to a bare, generic status ping. Each event type's level is independent —
there's no "set them all at once" control.

## Saving

- **Save Blast Settings** commits every row's checkbox and dropdown at once, for every event
  type in the table.
- **Cancel** discards any unsaved changes and collapses back to the last saved configuration.

<!-- SCREENSHOT NEEDED: The panel's Save/Cancel buttons at the top of the form. -->

## What happens immediately after you save

- Enabling a row takes effect right away — the very next matching event (a routing decision,
  a violation marked compliant, etc.) for this municipality will be eligible to email.
- The acting officer still sees the one-click notice-and-skip option on every eligible action
  regardless of what you just saved (see [the guarantee](/admin/subsystems/cear/overview#the-one-thing-you-cannot-turn-off)).
  Enabling a row here does not mean every occurrence is guaranteed to send — the officer can
  still opt out of that one instance, and the specific recipient may have already opted out
  via their own unsubscribe link.

## Cautions

- There's no confirmation dialog on save — double check your checkboxes before clicking
  **Save Blast Settings**.
- Because recipients are resolved per-CEAR (the external requestor, and/or the specific staff
  member who logged that particular request), enabling a row does not send anything
  municipality-wide the way the legacy routing checkbox's staff-subscriber list does — there's
  no bulk-notify-everyone behavior here to worry about.

## See also

- [CEAR admin overview](/admin/subsystems/cear/overview) — the two-system comparison and the
  officer-notice guarantee.
- [Developer notes — Update-Blast System](/dev/subsystems/cear/cear-logic#62-update-blast-system-phase-12-sept-2026-active-development) —
  full technical detail on event catalog, gating, and detail-level clamping.

Back to: [CEAR admin overview](/admin/subsystems/cear/overview) · [hub page](/system/subsystems/cear)
