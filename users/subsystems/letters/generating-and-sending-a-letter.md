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

The template list on the left only shows templates scoped to the parent object type you're
sending from — a case, a property, or a permit file (see the
[admin guide](/admin/subsystems/letters/creating-and-editing-letter-templates) if you think a
template is missing from the list; it may be scoped to a different parent type).

- Click **preview** on any row to load a full preview of that template on the right, with
  dummy/sample values in place of the mail-merge fields — nothing is created or committed by
  previewing. Before you preview anything, the panel just reads "Click 'preview' on a template
  row to see a preview."
- Click **Select template and go to step 2** on a row when you've settled on one. This is the
  only action on this step that actually starts the letter.

<!-- SCREENSHOT NEEDED: Step 1 of the letter flow, showing the template list on the left and
     a template preview open on the right. -->

## Step 2: Recipient and Dates

> **Cloning a letter?** See [Cloning or copying an existing letter](#cloning-or-copying-an-existing-letter)
> below — clone mode changes what's shown on this step (a banner naming the source letter,
> and no template pick since that's inherited from the source).

**Person tools**, above the recipient table, let you fix up who's available without leaving
the flow:

- **Search for / add a person** — opens the person search/linking dialog so you can find or
  create a person and link them to this case/property on the spot.
- **Link new address to property** — opens the address dialog to attach another mailing
  address to the property.
- **Refresh persons list** — reloads the candidate table below, for when you just added
  someone with the tool above and don't see them yet.

**Choose a recipient**, from the candidate table of people already linked to the case or
property:

- Click the row-expand arrow on a person's row to reveal their mailing addresses, then click
  **Mail to this address** next to the one you want.
- Or click **Mail to this person** directly on the row to lock in the person without picking
  an address yet (useful if you need to add an address for them first).
- **Property addresses** — a separate list below the person table, for addresses tied to the
  property itself rather than to a specific person (e.g. "the property" as its own mailing
  target) — each with its own **Mail to this address** button.
- Your current picks are echoed back in two boxes to the right — **Recipient person** and
  **Mailing address** — each reading "Select a person/address from the left" until you've
  made a choice. **Next** stays disabled until both boxes are filled in.

Below the recipient picker:

- **Notifying Officer** — who the letter is issued on behalf of. Defaults to the case's
  assigned officer but can be changed per letter (e.g. a different officer covering that day).
- **Date of Record** (required) — the date the letter is dated / considered issued. Leaving
  this blank blocks you from proceeding, with an inline validation message.
- **Action Due By** (optional) — a due-by date for the recipient to act by. It must fall on or
  after the date of record; if you pick an earlier date, the field is highlighted and an
  inline message explains why. Leave it blank if the template doesn't need one.
- **Internal Notes** (optional) — office-only notes that never appear on the printed or
  emailed letter.

<!-- SCREENSHOT NEEDED: Step 2 of the letter flow, showing the recipient/address table on the
     left (with the person/address selection boxes visible) and the Notifying Officer, Date of
     Record, and Action Due By fields on the right. -->

## Step 3: Edit Draft

The letter body is a rich-text editor pre-filled from the template. Nothing is locked yet — you
can edit the text freely before finalizing. Once the letter has a reference number assigned, it
shows in a bar above the editor.

> **Tip:** In the editor, press Enter once for a new paragraph — a single Enter creates the
> paragraph break, and the printed/PDF letter adds spacing between paragraphs automatically.
> You don't need a blank line in between.

> **Cloning a letter?** A **pure clone** shows the body as read-only text instead of an editor
> — see [Cloning or copying an existing letter](#cloning-or-copying-an-existing-letter). An
> **editable copy** shows the normal editor below, just pre-filled from the source letter.

### Mail-merge fields ("template insertion points")

Templates — and your edits here — use **template insertion points**: fields like
`<<RECIPIENT_NAME>>`, `<<DATE_OF_RECORD>>`, and (on CE case letters) `<<VIOLATIONS>>` that get
filled in automatically. Click **template insertion points reference** below the editor for the
full list (see also the admin
[mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference), which adds
notes on which parent types each field applies to); you don't need to type any of this by hand.

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
- **Photos?** — include that violation's photos, with a count shown next to the checkbox
  (only offered if it has any on file; expand the row to see thumbnails of the actual photos
  that will print).

Use the **Show all / Show none** links in a column's header to set that flag for every
violation at once, or **remove from letter** on a single row to drop just that violation from
this letter — it stays on the case; this only changes what prints on this particular letter.

### Photo printing size

If any linked violation has photos (or the letter has its own attached photos), a **Photo size
for printing** control appears with three options: **Small (4/page)**, **Medium (2/page)**, or
**Large (1/page)**. This controls how many photos fit per printed page in the finalized PDF —
pick Large when detail needs to be clearly legible, Small when you just need a lot of photos on
record without many pages.

### Saving a draft and coming back later

You don't have to finish the flow in one sitting. **Save Draft and Close** (available here on
Step 3, and as **Save in Draft State** on Step 4 before finalizing) closes the dialog without
finalizing — the letter is kept in **Draft** status and stays listed in the panel with an
**edit draft** link, so you can reopen and continue it whenever you're ready. A draft letter
also has a **finalize** link right next to its status badge, if you decide it's ready without
reopening the full flow.

<!-- SCREENSHOT NEEDED: Step 3 of the letter flow, showing the rich-text editor, the "rescan
     text for template insertion points" link, the violation display options table, and the
     photo size selector all in view. -->

## Step 4: Finalize and Send

The left column summarizes what you're about to finalize — template, recipient, mailing
address, date of record, action due by (with a "days from now" count), the number of
violations attached, and the reference number once one's assigned. If this letter is a clone
or copy, an extra row names the source letter. The right column shows a **live preview** of
the letter with real data (not dummy values), including the header image if the template has
one.

- **Save in Draft State** — leaves the flow without finalizing (see
  [Saving a draft and coming back later](#saving-a-draft-and-coming-back-later) above).
- **Finalize & Lock** — asks you to confirm ("Lock this letter for mailing? This cannot be
  undone.") and then permanently freezes the letter's content. This can't be reversed, so the
  wording and attached violations should be final before you click it.

Once finalized, the summary switches to a **Letter Finalized** badge with the finalized
timestamp, and two new actions appear:

- **Print finalized letter** — opens the finalized PDF in a new tab.
- **Record distribution** — the same menu covered in
  [Distributing a letter](/users/subsystems/letters/distributing-a-letter): record a mailing,
  email the letter via CodeNforce, or record a posting/placard or door-hanger — right from this
  step, without reopening the letter afterward.

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
each step: Step 2 shows a banner naming the source letter, and Step 3 either shows the body as
read-only text (pure clone) or a normal, pre-filled editor (editable copy).

<!-- SCREENSHOT NEEDED: the clone/copy mode-chooser dialog, showing both the "Pure clone" and
     "Editable copy" options side by side. -->

See also: [Distributing a letter](/users/subsystems/letters/distributing-a-letter),
[Printing a letter](/users/subsystems/letters/printing-a-letter),
[Mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference).

---

Back to: [Letters & Emailing — User Guide](/users/subsystems/letters/overview)
