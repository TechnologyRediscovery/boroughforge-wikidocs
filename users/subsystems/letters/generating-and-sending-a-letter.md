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

1. **Choose Template** — pick which letter template to use.
2. **Recipient & Dates** — who it's going to, the mailing address, the date of record, and
   (if applicable) the action-due date.
3. **Edit Draft** — the letter body, with a per-violation display panel if the template
   includes a violations list (toggle ordinance header/findings text, the stipulated-compliance
   date, and photos, per violation).
4. **Finalize & Send** — review a live preview of the letter, then **Finalize & Lock**.
   Finalizing is permanent — the letter's content is frozen at that point so it can't be
   disputed later.

## Mail-merge fields

Templates are written with fields that get filled in automatically when you generate a
letter — you don't need to type any of this by hand. The ones you'll see most often:
recipient name and address, date of record, action-due date, the violations table, photos,
and the municipality's contact info. Your system administrator manages the full list of
available fields in the Letter Template Manager.

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

See also: [Distributing a letter](distributing-a-letter), [Printing a letter](printing-a-letter).
