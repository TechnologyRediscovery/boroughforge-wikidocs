---
title: Letters & Emailing — Admin Guide
description: Setting up letter templates, print formats, and generic signing officers
published: true
date: 2026-08-07T00:00:00.000Z
tags: subsystem:letters, audience:admin, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Letters & Emailing — Admin Guide

Letters are authored from reusable **templates**, managed from Muni Tools > Letter Template
Manager. This page covers the setup work a system administrator does once per municipality;
day-to-day letter creation and sending is covered in the [user guide](/users/subsystems/letters/overview).

## Topics

- [Creating and editing letter templates](/admin/subsystems/letters/creating-and-editing-letter-templates) —
  every field in the template editor: parent object type filtering, format vs. print style,
  header images, default code elements, and cloning a template.
- [Mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference) — the full
  catalog of template insertion points, grouped by category, with which parent types each
  applies to.
- [Managing print styles](/admin/subsystems/letters/managing-print-styles) — portrait vs.
  landscape, header image width defaults, and the addressee-block margin fields.
- [Generic officer signatures](/admin/subsystems/letters/generic-officer-signatures) — how a
  municipality can sign letters from a generic person instead of the individual officer.

## Template Manager

- Create, edit, and clone letter templates. Cloning a template is the fastest way to make a
  variant (e.g. a "second notice" version) without retyping the whole body.
- Templates are written with **mail-merge fields** (shown in the app as "template insertion
  points") that get replaced with real data when a letter is generated — recipient name and
  address, action-due date, municipality contact info, the violations table, and photos are
  the fields officers rely on most. The template manager has a built-in mail-merge field
  reference dialog listing every available field.
- Each template has a **print format and orientation** — regular letter (portrait), or
  landscape formats intended for IPMC placards and door-hanger courtesy notices.

## Generic officer signatures

See [Generic officer signatures](/admin/subsystems/letters/generic-officer-signatures) for the
full setup steps — a municipality can choose to sign letters from a generic/arbitrary person
rather than the individual issuing officer, which is a one-time setup task done here in the
admin side.

See also: [subsystem registry](/system/subsystem-registry), entry #12.
