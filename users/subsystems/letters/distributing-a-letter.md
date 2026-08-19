---
title: Distributing a Letter
description: The Correspondence panel — mailing, email, posting/placard, and door-hanger notices
published: true
date: 2026-08-07T00:00:00.000Z
tags: subsystem:letters, audience:staff, type:howto
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Distributing a Letter

Once a letter is finalized, the **Correspondence** panel (formerly labeled "Letters" on case,
property, and permit file screens) shows its full distribution history — every channel it's
gone out on, in one place — and lets you record a new one.

## Where you can record a distribution

You'll see a **Record distribution** (or **email or record distribution**) menu in three
different places. All three write to the exact same history shown in the Correspondence
panel, so use whichever is convenient in the moment:

- Directly on the letter's row in the main letter table — no need to open anything first.
- Inside the letter's details view, in the **Distribution history** panel.
- On **Step 4 — Finalize & Send** of the letter flow, immediately after finalizing, so you
  don't have to reopen the letter to record how it went out.

<!-- SCREENSHOT NEEDED: the "Record distribution" menu open, showing the channel options
     (Record mailing, Send by email, Record posting-placard, Record door-hanger). -->

## Recording a distribution

Use the **Record distribution** menu on a finalized letter to log any of:

- **Mailing** — the date mailed, a mail method (First Class, Certified Mail, Priority Mail, or
  Hand Delivered), an optional certified-mail tracking number, and notes.
- **Email** — see [Emailing a letter](#emailing-a-letter) below.
- **Posting / placard** — the date, a location description (e.g. "front door"), optional GPS
  coordinates, notes, and an evidence photo. A photo is strongly encouraged for placards but
  not required.
- **Door-hanger** — the same fields as posting, for door-hanger courtesy notices.

Every entry appears in the Correspondence panel with its channel, date, a short detail line,
its outcome, and any notes — so at a glance you can see everything that's been done to notify
a recipient, not just whether it was mailed.

<!-- SCREENSHOT NEEDED: the Correspondence / Distribution history table showing at least one
     entry from each channel (mail, email, posting, door-hanger) so the column layout is
     clear. -->

## Emailing a letter

Choosing **Send by email** opens a two-tab dialog:

- **Email to letter recipient** — pick from any email address already on file for the
  recipient, or add a new one right in the dialog. Adding a new address here saves it onto
  that person's own contact record and immediately becomes selectable in the picker above it,
  so you don't have to leave the letter to update their contact info first.
- **Email to other linked person** — send a copy of the finalized letter to any other person
  linked to the parent case or property (a co-owner or attorney, for example) without changing
  who the letter's official recipient is. Because this sends to someone other than the
  recipient, choosing an address here opens a second confirmation dialog before it actually
  sends.

**Sending via CodeNforce email hard-locks the letter forever** — there's no undo and no
delayed-send takeback, no matter which tab you send from. The finalized PDF is attached
automatically when available, and delivery status (sent, delivered, bounced, opened, clicked)
updates automatically on the distribution history as CodeNforce hears back from the mail
provider — you don't need to check anywhere else.

<!-- SCREENSHOT NEEDED: the Email Letter dialog's "Email to letter recipient" tab, showing the
     address picker and the inline "add a new email address" section below it. -->

See also: [Generating and sending a letter](/users/subsystems/letters/generating-and-sending-a-letter),
[Printing a letter](/users/subsystems/letters/printing-a-letter).

---

Back to: [Letters & Emailing — User Guide](/users/subsystems/letters/overview)
