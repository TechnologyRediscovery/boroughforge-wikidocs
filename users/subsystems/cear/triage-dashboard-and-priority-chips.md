---
title: Triage dashboard and priority chips
description: Reading the color-coded age indicators on the CEAR dashboard
published: true
date: 2026-09-30T00:00:00.000Z
tags: subsystem:cear, audience:staff, type:howto
editor: markdown
dateCreated: 2026-09-30T00:00:00.000Z
---

# Triage dashboard and priority chips

As of September 2026, the CEAR dashboard highlights how long each unprocessed request has been
sitting, so the oldest ones are impossible to miss.

## The days-since-submission chip

Every unprocessed request card shows a large, bold chip in its upper-left corner counting the
days since it was submitted. It's color-coded against the 10-day processing target:

| Days since submission | Color | Meaning |
|---|---|---|
| 0–5 | Green | On track |
| 6–9 | Yellow | Getting close — caution |
| 10+ | Red, bold | Overdue |

<!-- SCREENSHOT NEEDED: Three CEAR cards side by side showing the green, yellow, and red chip
states. -->

The same color coding appears in the **Submitted** column of the CEAR search/table view, as a
smaller pill under the date — so you get the same at-a-glance signal whether you're browsing
cards or scanning the table.

<!-- SCREENSHOT NEEDED: The CEAR search table's "Submitted" column showing the compact
color-coded pill under a couple of dates. -->

## Once a request is routed

The days-since-submission chip only matters while a request is still waiting to be routed —
once it's routed (reaches a terminal status), the chip disappears and is replaced with a simple
**"Routed `<date>`"** line, right-aligned under the status badge on the card (and as a muted
line under the date in the table). At that point the SLA clock that mattered — how long it sat
unprocessed — is over, so the age figure is no longer shown.

<!-- SCREENSHOT NEEDED: A routed CEAR card showing the "Routed <date>" line where the chip used
to be. -->

## Finding the view/manage link

The **view/manage** link for each card sits on the same line as the property address/location,
right-aligned — not buried at the bottom of the card.

<!-- SCREENSHOT NEEDED: A CEAR card's address row with the location icon on the left and the
view/manage link right-aligned on the same line. -->

## See also

- [Processing and routing a CEAR](/users/subsystems/cear/processing-and-routing-a-cear) — what
  happens once you click into a request.

Back to: [CEAR user guide](/users/subsystems/cear/overview) · [hub page](/system/subsystems/cear)
