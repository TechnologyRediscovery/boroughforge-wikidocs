---
title: Mail-Merge Token Reference
description: Full catalog of letter template insertion points, grouped by category, with which parent types each applies to
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:admin, type:reference
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Mail-Merge Token Reference

Letter templates use **mail-merge fields** — shown in-app as "template insertion points" — to
pull in real data when a letter is generated. This page catalogs every available token, what
it renders, and (critically) which **parent object types** it's actually populated on. A
handful of tokens are silently ignored (rendered as empty) on parent types they don't apply
to, so a template author needs to know this table, not just the token names.

Insertion points are written as `<<TOKEN_NAME>>` directly in the template text. The same
reference is available in-app from the Template Manager's collapsed **Mail merge field
reference** panel, and inline from the letter flow's editor while drafting a letter.

<!-- SCREENSHOT NEEDED: the in-app mail-merge field reference panel, showing a couple of the
     category sections. -->

## Date and reference

| Token | Description | Applies to |
|---|---|---|
| `<<DATE_OF_RECORD>>` | The letter's date of record, as set in Step 2 of the letter flow. | All parent types |
| `<<ACTION_DUE_DATE>>` | The action-due-by date, as set in Step 2. | All parent types |
| `<<REFERENCE_NUMBER>>` | The letter's auto-generated reference number. Not editable — always system-assigned. | All parent types |

## Recipient

| Token | Description | Applies to |
|---|---|---|
| `<<RECIPIENT_NAME>>` | The selected recipient's name. | All parent types |
| `<<MAILING_ADDRESS>>` | The selected mailing address. | All parent types |
| `<<RECIPIENT_NAME_AND_ADDRESS>>` | Name and address together, as a single positioned block — this is the one meant to land inside a windowed envelope. Its on-page position is controlled by the template's **print style** (top/left margins), not by where you place the token in the text. | All parent types |

## Sender and officer

| Token | Description | Applies to |
|---|---|---|
| `<<SENDER_NAME>>` | The signing officer's name (or the generic signing person, if configured — see [Generic officer signatures](/admin/subsystems/letters/generic-officer-signatures)). Not editable. | All parent types |
| `<<SENDER_BLOCK>>` | A fuller sender block (name, title, etc.). Not editable. | All parent types |
| `<<SENDER_SIGNATURE_IMAGE>>` | The signer's signature image, if one is on file. Not editable. | All parent types |
| `<<GENERIC_SENDER_NAME>>` | The municipality's configured generic sender name, independent of who the actual signing officer is. Not editable. | All parent types |

## Municipality

| Token | Description | Applies to |
|---|---|---|
| `<<MUNI_NAME>>` | The municipality's name. Not editable. | All parent types |
| `<<MUNI_PHONE>>` | The municipality's main phone number. Not editable. | All parent types |
| `<<MUNI_CONTACT_BLOCK>>` | A fuller municipality contact block (address, phone, office hours, etc., as configured). Not editable. | All parent types |

## Property

| Token | Description | Applies to |
|---|---|---|
| `<<PARCEL_ID>>` | The target property's parcel/tax ID. Not editable. | All parent types |
| `<<TARGET_PROPERTY_ADDRESS_1_LINE>>` | The target property's address, single-line format. Not editable. | All parent types |
| `<<TARGET_PROPERTY_ADDRESS_2_LINE>>` | The target property's address, two-line format. Not editable. | All parent types |
| `<<UNIT_LIST>>` | A list of the property's units. Not editable. | **Property/Parcel only** — renders as empty on CE case and permit file letters |

## Violations

| Token | Description | Applies to |
|---|---|---|
| `<<VIOLATIONS>>` | A full table of the case's linked code violations, built from the actual `CodeViolation` records — including, per violation, whatever combination of ordinance text, compliance due date, and photos was selected on Step 3 of the letter flow. Not editable directly (it's a generated table block). | **CE Case only** — completely ignored (renders as nothing) on Property/Parcel and Permit file letters |

This is also the field to use instead of the Template Manager's **Default code elements**
setting for anything involving actual case violations — Default code elements is a
template-level ordinance tag for rental-registry/occ-period context, not a rendering token.
See [Creating and editing letter templates](/admin/subsystems/letters/creating-and-editing-letter-templates)
for the full distinction.

## Photos

| Token | Description | Applies to |
|---|---|---|
| `<<PHOTOS>>` | A general photo block for images attached directly to the letter (not tied to a specific violation). Not editable. | All parent types |

## Notes on availability

- In a template that hasn't been generated onto a real letter yet (i.e. the Template
  Manager's own **Generate preview**), every token above is treated as applicable and filled
  with a dummy/sample value — the parent-type restrictions only take effect once the template
  is actually used to draft a real letter.
- A token that isn't applicable to a letter's parent type is stripped out (rendered as empty)
  rather than left as literal text — you'll never see a raw `<<UNIT_LIST>>` printed on a CE
  case letter, for example.

See also: [Creating and editing letter templates](/admin/subsystems/letters/creating-and-editing-letter-templates).

---

Back to: [Letters & Emailing — Admin Guide](/admin/subsystems/letters/overview)
