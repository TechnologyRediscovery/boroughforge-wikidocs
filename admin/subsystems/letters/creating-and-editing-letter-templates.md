---
title: Creating and Editing Letter Templates
description: Every field in the Letter Template Manager editor, what it actually controls, and what it's advisory-only
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:admin, type:howto
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Creating and Editing Letter Templates

The **Letter Template Manager** (Muni Tools > Letter Template Manager) is where every letter
template for your municipality is created, edited, and cloned. This page walks through each
field in the editor and explains exactly what it controls — several fields look similar but
drive very different behavior, so read the notes below before assuming a field does what its
name suggests.

<!-- SCREENSHOT NEEDED: the Letter Template Manager's template list, showing the Format,
     Title, Parent type, Print style, and Actions columns. -->

## The template list

The list shows every template for your municipality: **Format**, **Title**, **Parent type**,
**Print style**, and row actions (**view/edit**, **clone**). Use **Load templates** to refresh
the list and **New template** to start a blank one.

## Field-by-field: the template editor

<!-- SCREENSHOT NEEDED: the template editor in edit mode, showing Title, Parent object type,
     Format, Print style, Header image, and Default code elements all in view. -->

### Title

A plain label for staff picking a template from a list — free text, no special behavior.

### Parent object type

One of **Code Enforcement Case**, **Property/Parcel**, or **Permit file**. This is not just a
label — **it's a filter**. When staff start a new letter from a case, a property, or a permit
file, the template picker on Step 1 of the letter flow only offers templates whose Parent
object type matches that parent. A template scoped to Permit file will never appear in the
list when someone is drafting a letter from a CE case, and vice versa. Choose this
deliberately: it's the mechanism that keeps, say, rental-registry notices from cluttering the
template list when someone's writing a violation notice on a case.

### Format

An informational label only (e.g. "Notice," "Placard," "Reminder" — whatever labels your
municipality finds useful for browsing the list). **The letter subsystem does not branch any
logic on this field.** It has no effect on layout, orientation, margins, or which mail-merge
fields are available — it exists purely so staff scanning the template list can tell templates
apart at a glance. If you're looking for the field that actually controls how a letter is laid
out and printed, that's **Print style**, below.

### Print style

This is the field that actually drives layout. Print style controls:

- **Page orientation** — portrait for a standard letter, or landscape for IPMC placards and
  door-hanger notices.
- **Where the addressee block lands on the page** — the margins that position the
  `<<RECIPIENT_NAME_AND_ADDRESS>>` mail-merge field so it sits correctly inside a windowed
  envelope (top and left margin, set independently from the rest of the letter body's margins).
- **Header image width** — the default display width for the header image (below), and the
  page's overall header width.
- **Body text top margin** — how far down the main letter text starts, independent of the
  addressee block's position.

Pick **-- None --** for a template with no special print styling. See
[Managing print styles](/admin/subsystems/letters/managing-print-styles) for how to create and
edit the print styles themselves, including the global vs. municipality-specific styles.

### Header image

The image that prints at the top of the letter (letterhead, seal, etc.). This selector only
lists image files **already uploaded to your municipality** — you don't upload a file directly
from the template editor. To add a new header image option, go to the municipality session box
> **muni tools** > **important muni documents and files**, upload the image there, then come
back to the template editor and it will appear in this selector. Choose **-- No header image
--** for a template that shouldn't print one.

### Default code elements

**This field is for rental-registry / permit-file (occupancy period) process context — it is
not how CE case violations get onto a letter.** It's a multi-select of your municipality's
enforceable ordinance elements (filterable, ctrl/cmd+click to multi-select), and it exists to
associate a template with the ordinances it's typically used for — for example, tagging a
rental-registry template with the registry-related ordinance sections so that association is
recorded at the template level.

Two important distinctions:

- **It's metadata, not content.** Selecting default code elements here does not insert any
  ordinance text into the rendered letter automatically — there's no mail-merge field that
  reads from this list. It's a template-level association only.
- **It has nothing to do with `<<VIOLATIONS>>`.** For CE case letters, use the
  `<<VIOLATIONS>>` mail-merge field (see the
  [mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference)) instead —
  that field automatically pulls in the actual `CodeViolation` records attached to the parent
  case. `<<VIOLATIONS>>` only populates when the letter's parent is a CE case; it's ignored
  completely (renders as nothing) on Property/Parcel and Permit file letters. Default code
  elements, conversely, are available on any parent type but are most useful for the
  rental-registry/occ-period use case, not case violations.

This field only shows in view mode when at least one element has been selected; each shows the
ordinance's header text and its element ID.

### Template text

The letter body itself, edited with the same rich-text (Quill) editor used in the letter flow.
Use **mail-merge fields** — shown in-app as "template insertion points" — for anything that
should be filled in automatically per letter (recipient name/address, dates, violations,
photos, and more). See the full
[mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference) for every
available field and which parent types each applies to. Sysadmin accounts additionally get a
raw-HTML toggle for advanced formatting not reachable through the rich-text toolbar.

### Generate preview

Click **Generate preview** (in view mode) to see how the template renders with **dummy/sample
values** substituted into every mail-merge field — this is a preview only, not tied to any
real case, property, or recipient. The rendered result appears in the **Template preview**
panel below the editor panel. Until you generate one, that panel just reads "Select a template
and click 'Generate preview' to see a preview."

<!-- SCREENSHOT NEEDED: the Template preview panel showing a generated preview with dummy
     mail-merge values filled in. -->

### Deactivate

Deactivates the template so it no longer appears when staff are choosing a template for a new
letter. Existing letters already generated from it are unaffected.

## Cloning a template

Use **clone** on any template row to start a new template pre-filled from an existing one —
the fastest way to make a variant (a "second notice" version of an existing template, for
example) without retyping the whole body. The clone is a fully independent template: editing
it afterward has no effect on the original, and all the fields above (parent object type,
format, print style, header image, default code elements) are copied over as a starting point
and can be changed freely.

See also: [Mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference),
[Managing print styles](/admin/subsystems/letters/managing-print-styles).

---

Back to: [Letters & Emailing — Admin Guide](/admin/subsystems/letters/overview)
