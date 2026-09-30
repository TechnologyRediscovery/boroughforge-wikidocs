---
title: Submitting a CEAR on behalf of a caller
description: Logging a phone-in or walk-in code enforcement concern yourself
published: true
date: 2026-09-30T00:00:00.000Z
tags: subsystem:cear, audience:staff, type:howto
editor: markdown
dateCreated: 2026-09-30T00:00:00.000Z
---

# Submitting a CEAR on behalf of a caller

If a resident calls in or walks in with a concern instead of using the public online form, log
it yourself from **CE → Submit Internal Request**.

<!-- SCREENSHOT NEEDED: The "Submit Internal CE Action Request" page, top of form, showing the
Request Type panel with its two radio options. -->

## 1. Request type

Choose one:

- **Property-Specific Request** — linked to a parcel address. This opens the **Property**
  panel, where you search for and select the property (via the same quick-search box used
  elsewhere in the app).
- **Municipal General Request** — an infrastructure, patrol, or non-parcel concern (e.g. "a
  streetlight is out downtown"). No property step is shown; the request isn't attached to any
  particular address.

> If you start a request as muni-general but it turns out there *is* a specific property
> involved, don't worry about getting this exactly right up front — an officer can always
> search for and attach a real property to a muni-general request later during routing (see
> [Processing and routing a CEAR](/users/subsystems/cear/processing-and-routing-a-cear)), which
> automatically reclassifies it as a standard, property-linked request.

## 2. Concern details

- **Issue Type** — pick from the active list of concern categories.
- **Description** — required; describe what was reported.
- **Urgent** — check if this needs faster attention.
- **Date of Record** — defaults to now; adjust if the caller is reporting something from
  earlier.

<!-- SCREENSHOT NEEDED: The Concern Details panel with Issue Type, Description, Urgent, and
Date of Record fields filled in. -->

## 3. Requestor

Choose **Submit as myself** if you're the one reporting the concern, or **On behalf of a
resident** to capture the caller's own information:

- **Resident Name** (required), **Phone**, **Email**.
- **Resident notifications** — two independent checkboxes:
  - *Send resident a confirmation copy* — one-time email confirming the request was received.
  - *Subscribe resident to status updates* — opts the resident's email in to receiving a
    routing-status email later, when that request eventually gets routed (legacy blast — see
    the [CEAR admin overview](/admin/subsystems/cear/overview) for how this differs from the
    newer per-event system).

<!-- SCREENSHOT NEEDED: The Requestor panel in "on behalf of a resident" mode, showing the name/
phone/email fields and the two resident-notification checkboxes. -->

## 4. Your own notifications

Before submitting, you'll see **My notifications** — the same pattern as the resident's, but
for you:

- *Send me a confirmation copy* — a one-time email to your own staff address confirming the
  submission went through.
- *Subscribe me to status updates* — you, specifically (not your municipality's whole
  subscriber list), will get emailed when this particular request is later routed, if you opt
  in here.

## 5. Submit

- **Submit without photos** — saves the request immediately.
- **Submit and attach photos** — saves the request, then opens a photo upload dialog so you
  can attach images before finishing up.
- **Cancel** — discards the form.

<!-- SCREENSHOT NEEDED: The Submission panel showing "My notifications" checkboxes and the
three action buttons (cancel / submit without photos / submit and attach photos). -->

Once submitted, the request appears on the CEAR dashboard just like a public submission, ready
for [processing and routing](/users/subsystems/cear/processing-and-routing-a-cear).

## Cautions

- **Resident Type is required** whenever you're submitting on behalf of someone else — pick the
  closest match (e.g. tenant, owner, neighbor) before you can submit.
- A property must actually be selected for a property-specific request — you can't submit with
  the type set to "property-specific" and no property chosen.

Back to: [CEAR user guide](/users/subsystems/cear/overview) · [hub page](/system/subsystems/cear)
