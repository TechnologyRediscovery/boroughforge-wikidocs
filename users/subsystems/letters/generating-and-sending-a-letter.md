---
title: Generating and Sending a Letter
description: The 4-step letter flow, mail-merge fields, and cloning/copying an existing letter
published: true
date: 2026-08-07T00:00:00.000Z
tags: subsystem:letters, audience:staff, type:howto
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Generating and Sending a Letter

Letters are created from the case, property, or permit file you want to send one from. Every
letter — new or based on an old one — goes through the same 4-step dialog:

1. [Choose Template](#step-1-choose-template)
2. [Recipient and Dates](#step-2-recipient-and-dates)
3. [Edit Draft](#step-3-edit-draft)
4. [Finalize and Send](#step-4-finalize-and-send)

## Step 1: Choose Template

Pick which letter template to use from the list on the left. Click **preview** on any row to
see a full preview of that template on the right before committing — nothing is created until
you click **Select template and go to step 2**.

<!-- SCREENSHOT NEEDED: Step 1 of the letter flow, showing the template list on the left and
     a template preview open on the right. -->

## Step 2: Recipient and Dates

- **Choose a recipient** from the table of people already linked to the case or property.
  Expand a row to see that person's mailing addresses and pick one with **Mail to this
  address** — or use **Mail to this person** to select the person first without picking an
  address yet. Property-level addresses (not tied to a specific person) are listed separately
  below the table.
- Use the **Person tools** above the table to **search for / add a person**, **link a new
  address to the property**, or **refresh persons list** if you just added someone and don't
  see them in the table yet.
- **Notifying Officer** — who the letter is issued on behalf of. This defaults to the case's
  assigned officer but can be changed per letter, for example if a different officer is
  covering that day.
- **Date of Record** (required) — the date the letter is dated / considered issued.
- **Action Due By** (optional) — a due-by date for the recipient to act by. It must fall on or
  after the date of record; leave it blank if the template doesn't need one.
- **Internal Notes** (optional) — office-only notes that never appear on the printed or
  emailed letter.

<!-- SCREENSHOT NEEDED: Step 2 of the letter flow, showing the recipient/address table on the
     left and the Notifying Officer, Date of Record, and Action Due By fields on the right. -->

## Step 3: Edit Draft

The letter body is a rich-text editor pre-filled from the template. Nothing is locked yet — you
can edit the text freely before finalizing.

### Mail-merge fields ("template insertion points")

Templates — and your edits here — use **template insertion points**: fields like
`<<RECIPIENT_NAME>>`, `<<DATE_OF_RECORD>>`, and (on CE case letters) `<<VIOLATIONS>>` that get
filled in automatically. Click **template insertion points reference** below the editor for the
full list your system administrator has made available; you don't need to type any of this by
hand.

If you add or remove the `<<VIOLATIONS>>` insertion point by hand while editing, click
**rescan text for template insertion points** afterward. This re-checks the draft text and
turns the violation display panel below on or off to match — it's a manual step (not automatic
on every keystroke) so the page doesn't have to re-scan the whole draft on every letter.

### Violation links (CE case letters only)

When the draft contains `<<VIOLATIONS>>`, a **violation display options** table appears,
listing the case's active violations. For each linked violation you can independently toggle:

- **Show compliance due date?** — include that violation's stipulated-compliance date.
- **Include ord text?** — include the full ordinance header/findings text, not just the
  ordinance reference.
- **Photos?** — include that violation's photos (only offered if it has any on file).

Use the **Show all / Show none** links in a column's header to set that flag for every
violation at once, or **remove from letter** on a single row to drop just that violation from
this letter — it stays on the case; this only changes what prints on this particular letter.

### Photo printing size

If any linked violation has photos (or the letter has its own attached photos), a **Photo size
for printing** control appears with three options: **Small (4/page)**, **Medium (2/page)**, or
**Large (1/page)**. This controls how many photos fit per printed page in the finalized PDF —
pick Large when detail needs to be clearly legible, Small when you just need a lot of photos on
record without many pages.

<!-- SCREENSHOT NEEDED: Step 3 of the letter flow, showing the rich-text editor, the "rescan
     text for template insertion points" link, the violation display options table, and the
     photo size selector all in view. -->

## Step 4: Finalize and Send

Review a live preview of the letter, then **Finalize & Lock**. Finalizing is permanent — the
letter's content is frozen at that point so it can't be disputed later. You can also record a
distribution (see [Distributing a letter](distributing-a-letter)) right from this step,
immediately after finalizing, without leaving the flow or reopening the letter.

<!-- SCREENSHOT NEEDED: Step 4's pre-finalization summary panel on the left and the live
     letter preview on the right. -->

## Cloning or copying an existing letter

Once a letter is finalized, a **clone / copy** link appears. This opens a mode chooser with
two distinct paths:

- **Pure clone — exact letter.** Use this when you need to send the identical letter to a
  second address (the classic case: the property address *and* the tax-bill address, same
  day). The letter body is locked and cannot be edited; only the recipient, mailing address,
  and date of record can change. The system records the link back to the original letter, so
  the identical wording is provable later if it matters.
- **Editable copy.** Use this when you want to start a new letter with the same structure as
  an old one, but you plan to change the wording (e.g. a "SECOND NOTICE" follow-up). The body
  is pre-filled from the source letter but is fully editable, and a note is added recording
  which letter it was based on.

Both paths reuse the same 4-step flow above — the mode you pick just changes what's locked at
each step.

<!-- SCREENSHOT NEEDED: the clone/copy mode-chooser dialog, showing both the "Pure clone" and
     "Editable copy" options side by side. -->

See also: [Distributing a letter](distributing-a-letter), [Printing a letter](printing-a-letter).
