---
title: Configuring CEAR update-blast notifications
description: Walkthrough of the "CEAR Subscriber Update Blasts" panel on the Municipalities page, plus the two per-category switches that feed it
published: true
date: 2026-11-02T00:00:00.000Z
tags: subsystem:cear, audience:admin, type:howto
editor: markdown
dateCreated: 2026-09-30T00:00:00.000Z
---

# Configuring CEAR update-blast notifications

This walks through the **"CEAR Subscriber Update Blasts"** panel — the per-municipality
control center for the update-blast notification system described in the
[CEAR admin overview](/admin/subsystems/cear/overview). If you haven't read that page yet,
start there for how this relates to the separate, always-on legacy routing blast.

Deciding *what* to turn on? Point your town manager or lead officer at
[Choosing your CEAR update-email settings](/users/subsystems/cear/choosing-update-email-settings).

## Where to find it

1. In the left sidebar, open **System → Municipalities** (the System section is visible to
   system administrators only) and select the municipality you want to configure.
2. Find the **"CEAR Subscriber Update Blasts"** panel. It's expanded by default.
3. Click **Edit blast settings** to make the table editable.

<!-- SCREENSHOT NEEDED: Municipalities page (muniManage.xhtml) showing the "CEAR Subscriber
Update Blasts" panel in read mode with the "Edit blast settings" button. -->

## The event table

The panel shows one row per blastable event type. In read mode each row shows "Yes"/"No" and
the detail-level name; in edit mode they become inputs:

| Column | What it does |
|---|---|
| **Event** | The plain-language name of the event (see the full list below). |
| **Send Blasts** | A checkbox — on enables this event type for this municipality, off (the default) disables it entirely. |
| **Detail Level** | A dropdown (MINIMAL, STANDARD, or FULL) controlling how much the email body includes for this event type. |
| **Officer May Skip** | Informational only — always "Yes." This cannot be changed; see the guarantee on the overview page. |

<!-- SCREENSHOT NEEDED: The panel in edit mode showing the full event table with a couple of
rows enabled and a couple disabled. -->

> **Tip — the Detail Level dropdown wakes up as soon as you tick Send Blasts.** Tick the
> checkbox and that row's dropdown becomes selectable immediately, in the same edit session.
> A newly enabled event starts at **MINIMAL** until you change it; untick the box and the
> dropdown greys out again (the level you picked is kept).

### The 9 event types

| Event (as shown in the panel) | Fires when |
|---|---|
| CEAR routed by officer | An officer commits any **terminal** routing decision on a CEAR: attached to an existing case, attached to a new case, attached to an occupancy period, marked invalid, referred to another department, or (muni-general only) marked action completed. Re-routing a CEAR back to unprocessed, or marking a muni-general concern's action as merely "underway," does **not** fire this — only a final/terminal outcome does. |
| Notice of violation sent | A notice of violation is marked sent on the CEAR's host case. |
| Code violation recorded | One or more code violations are attached to the CEAR's host case (one email per batch). |
| Violation marked compliant | Violations on the host case are marked compliant (one email per batch). |
| Violation nullified | Violations on the host case are nullified (one email per batch). |
| Compliance date extended | A stipulated compliance date is extended on one or more violations (one email per batch). |
| Citation status recorded | A status log entry is added to a citation, where that status has **Notify CEAR case monitors** turned on. |
| Case closed | The CEAR's host case is closed. |
| Event logged (officer-selected category) | An event is logged on the host case whose category has **Notify Case Monitors** turned on. |

> Two rows — citation status and event logged — only fire for the specific statuses and
> categories flagged as notifiable (next section). Enabling the row here is necessary but not
> sufficient for those two. The other seven fire on every occurrence once enabled.

## The two per-category switches

| Switch | Where | Label |
|---|---|---|
| Event category | Sidebar **Event tools → Event setup and categories**, open the category, panel *Notifications and Viewing* | **Notify Case Monitors** (Yes/No switch). Despite the legacy name, it means "send the CEAR update blast to this case's CEAR submitters." Muni managers can edit categories scoped to their own municipality; system administrators can edit any. |
| Citation status | Sidebar **System → Manage Dropdown Lists**, choose **Citation Status Log Status**, then the status | **Notify CEAR case monitors** (checkbox) |

**Caution — double emails.** The "Event logged" blast fires for *any* event added to a case in
a flagged category, including events the system adds on its own (for example the event a
citation status can spawn, or events written by other case automation). Those system-created
events show the officer **no notice and no skip box**, and they send on top of whatever
dedicated blast the same action already triggered. Only turn **Notify Case Monitors** on for
categories that officers pick by hand.

## Detail levels

| Level | Email includes |
|---|---|
| MINIMAL | Muni name banner, property address (or a note that the request isn't tied to an address), the CEAR's public reference code, submitted date, a one-line description of the update, your inquiry-contact block (if configured), and the footer with the unsubscribe link. **The officer's public note is not included.** |
| STANDARD | Everything in MINIMAL, plus the concern type and the officer's public note (when one was written). |
| FULL | For members of the public, identical to STANDARD — FULL is automatically reduced to STANDARD. For a CEAR that a staff member logged, adds an "Items affected" count when more than one item was affected. Copies to staff also show an "Action taken by" row at every level. |

Pick STANDARD if you want requestors to see specifics and the officer's note; pick MINIMAL if
you'd rather keep emails to a bare, generic status ping. Each event type's level is
independent — there's no "set them all at once" control.

## Saving

- **Save edits** (the same button that read "Edit blast settings") commits every row's checkbox
  and dropdown at once and shows a "CEAR blast settings saved" confirmation.
- **Cancel** (visible only in edit mode) discards unsaved changes, reloads the last saved
  configuration, and returns to read mode.

<!-- SCREENSHOT NEEDED: The panel header in edit mode showing the Save edits and Cancel
buttons. -->

## What happens immediately after you save

- Enabling a row takes effect right away — the very next matching event for this municipality
  will be eligible to email.
- Wherever the officer is acting directly, they see the notice-and-skip option (see
  [the guarantee](/admin/subsystems/cear/overview#the-one-thing-you-cannot-turn-off)) — except
  for the system-created events described above. Enabling a row doesn't mean every occurrence
  sends: the officer can skip that instance, and the recipient may have unsubscribed.

## Cautions

- There's no confirmation dialog on save — double check your checkboxes before clicking
  **Save edits**.
- **Recipients come from the email on the CEAR, not from the "send me updates" checkbox.** The
  public form's updates checkbox governs only the legacy routing email. Any CEAR with a
  requestor email (and no unsubscribe on file) is eligible for these emails when you enable an
  event. A staff member who logged a CEAR on someone's behalf receives copies only if they opted
  in when logging it.
- Because recipients are resolved per-CEAR, enabling a row does not send anything
  municipality-wide the way the legacy routing checkbox's staff-subscriber list does.
- The save action is protected by who can see the System menu; it has no separate permission
  check of its own in the coordinator.

## See also

- [CEAR admin overview](/admin/subsystems/cear/overview) — the two-system comparison and the
  officer-notice guarantee.
- [Choosing your CEAR update-email settings](/users/subsystems/cear/choosing-update-email-settings) —
  the decision guide for officers and town managers.
- [Developer notes — Update-Blast System](/dev/subsystems/cear/cear-logic#62-update-blast-system-phase-12-sept-2026-active-development) —
  full technical detail on event catalog, gating, and detail-level clamping.

Back to: [CEAR admin overview](/admin/subsystems/cear/overview) · [hub page](/system/subsystems/cear)
