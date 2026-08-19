---
title: Managing Print Styles
description: Creating and editing print styles — orientation, header width, and the addressee-block margins
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:admin, type:howto
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Managing Print Styles

**Print styles** are the reusable layout definitions letter templates pick from — see
[Creating and editing letter templates](/admin/subsystems/letters/creating-and-editing-letter-templates)
for how a template's **Print style** field is chosen and what it drives. This page covers the
**Manage print styles** dialog itself, opened from the Letter Template Manager toolbar.

<!-- SCREENSHOT NEEDED: the print style list, showing the ID, Description, Header width (px),
     Municipality, and Actions columns. -->

## The print style list

Shows every print style available to your municipality: **ID**, **Description**, **Header
width (px)**, **Municipality** (a "Global (all munis)" badge, or your municipality's name),
and **view / edit**. Use **Load print styles** to refresh the list, and **Add print style** to
start a new one (only offered if you have permission to create one).

A **What do these print style fields do?** link opens an illustrated field-by-field guide
image alongside this page's written version.

## Global vs. municipality-specific print styles

A print style is either:

- **Global (all municipalities)** — available everywhere, read-only for ordinary
  municipality admins ("Global print style — read only (system administrator required to
  edit)"). Only a system administrator can create or edit a global style.
- **Municipality-specific** — scoped to your own municipality only, and editable by your own
  municipality's admins.

When creating a new style, the **Municipality** selector itself is disabled unless you have
system-administrator permission — ordinary admins can only ever create municipality-specific
styles, never global ones.

## Field-by-field: the print style editor

<!-- SCREENSHOT NEEDED: the print style editor in edit mode, showing Description,
     Municipality, Page orientation, Header image width, and the three margin fields. -->

### Description

A plain label for picking this style from a template's Print style dropdown.

### Page orientation

**Portrait** or **landscape**. This is the field that actually sets the PDF page size rule —
portrait for a standard letter, landscape for IPMC placards and door-hanger courtesy notices.

### Header image width (px)

The default display width for a template's header image when this print style is applied.

### Letter margin, top (px)

How far down the page the overall letter content starts.

### Addressee margin, top (px) / Addressee margin, left (px)

**These two fields are what actually position the `<<RECIPIENT_NAME_AND_ADDRESS>>`
mail-merge field on the page** — it renders as an absolutely-positioned block (not inline text
flow), specifically so it lines up correctly inside a windowed envelope. Adjust these two
values together when the addressee text doesn't land inside the envelope window on a real
printed/mailed letter.

### Text body margin, top (px)

How far down the main letter text starts — independent of the addressee block's position, so
you can tune the two separately (the addressee block sits inside its own positioned box, while
the body text flows normally from this margin).

## Deactivating a print style

**Deactivate** removes a style from the create/edit list going forward. Letter templates
already using it keep working exactly as before — deactivating only prevents it from being
selected on *new* or newly-edited templates.

See also: [Creating and editing letter templates](/admin/subsystems/letters/creating-and-editing-letter-templates),
[Mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference).

---

Back to: [Letters & Emailing — Admin Guide](/admin/subsystems/letters/overview)
