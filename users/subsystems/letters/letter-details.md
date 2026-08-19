---
title: Viewing a Letter's Details
description: The letter details dialog — reviewing a single letter's full record outside the 4-step flow
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:staff, type:howto
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Viewing a Letter's Details

Click **view / edit** (or the "(viewing)" link) on any row in the letter table to open a
letter's **details dialog** — the full record for a single letter, outside the 4-step
[generating and sending](/users/subsystems/letters/generating-and-sending-a-letter) flow. This
is where you go to review a letter after the fact, record a distribution later on, append a
note, or clone it for a second recipient.

<!-- SCREENSHOT NEEDED: the letter details dialog, showing the Letter summary and Letter
     tools panels on the left and Distribution history on the right. -->

## Administrative alerts

If the letter has any outstanding administrative flags, they appear in a callout at the very
top of the dialog, above everything else.

## Letter summary

A read-only snapshot: **Template**, **Print style**, **Parent type**, **Reference** number,
**Date of record**, **Sent** (or "Not sent"), **Returned** (or "No"), **Recipient**, and
**Address**.

## Letter tools

- **preview draft** (before finalizing) / **view / print** (after finalizing) — opens the
  letter's print view in a new tab. See
  [Printing a letter](/users/subsystems/letters/printing-a-letter).
- **clone / copy** — available once the letter is finalized. Opens the same mode-chooser
  covered in
  [Cloning or copying an existing letter](/users/subsystems/letters/generating-and-sending-a-letter#cloning-or-copying-an-existing-letter).
- **Deactivate letter** — removes the letter from active use. This is audited and may require
  system-admin permissions depending on your role; if you don't have permission, the button is
  replaced with a note saying so. Already-deactivated letters show "This letter is already
  deactivated" instead.
- If CodeNforce detects that the letter's stored, rendered HTML doesn't match its recorded
  integrity hash, an **INTEGRITY WARNING** banner appears here instead of the tools — contact
  your system administrator if you ever see this.

## Distribution history

Every distribution attempt on this letter, across every channel (mail, email, posting/placard,
door-hanger), in one append-only table — the same history described in
[Distributing a letter](/users/subsystems/letters/distributing-a-letter). Two checkboxes above
the table let you widen what's shown:

- **show superseded records** — include mailing records that have since been amended (an
  amendment supersedes, rather than overwrites, the original).
- **show deactivated records** — include distribution records that have been deactivated.

Use the **Record distribution** menu (same options as Step 4 of the letter flow: record
mailing, send by email, record posting-placard, record door-hanger) to log a new one right
from here. Each row in the table shows its channel, date, a channel-specific detail (email
delivery status, certified-mail tracking number, or posting location + evidence photo
thumbnail), its outcome (returned, or "—"), whether it's an original or an amendment of an
earlier record, and any notes. Use **amend** on an original record to correct it (the original
is kept, hidden by default, and superseded by the amendment) or **mark returned** to record
that mail came back / a placard was removed.

<!-- SCREENSHOT NEEDED: the Distribution history table with entries from more than one
     channel, and the "show superseded records" / "show deactivated records" checkboxes
     visible above it. -->

## Notes

Office-only notes attached to the letter — never shown on the printed or emailed letter
itself. Type a note in the box and click **Append note** to add it; existing notes display
below. Notes only ever accumulate (append-only), matching the same pattern as the
Distribution history's amend-instead-of-overwrite model.

See also: [Generating and sending a letter](/users/subsystems/letters/generating-and-sending-a-letter),
[Distributing a letter](/users/subsystems/letters/distributing-a-letter).

---

Back to: [Letters & Emailing — User Guide](/users/subsystems/letters/overview)
