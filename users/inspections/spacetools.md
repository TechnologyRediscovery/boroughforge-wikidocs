---
title: Managing inspected spaces
description: Inspected space management tools afford lots of officer flexibility to document details of inspected areas of a property
published: true
date: 2026-05-11T12:46:47.753Z
tags: 
editor: markdown
dateCreated: 2026-05-11T12:33:25.643Z
---

# Managing inspected spaces

An **inspected space** is a single room or area within a property that has been added to a field inspection checklist. Each space carries its own details, dimensional measurements, occupancy limits, and inspection findings. The tools described below are available from the field inspection profile page.

---

### Space List

All spaces added to an inspection appear in a table on the inspection profile. For each space the table shows:

- **Space type** — the name of the checklist space type (e.g., *Bedroom*, *Kitchen*, *Common Area*).
- **Floor number** — displayed as *Fl. 2*, *Fl. -1*, etc. Floor **0** is not shown; use 0 only when a floor designation does not apply. Use **negative numbers for below-grade floors** (basement = −1, sub-basement = −2, and so on).
- **Location description** — a free-text note you entered describing where in the building this particular room is (e.g., *"north side, second unit"*).
- **Square footage** — the computed total area, shown when it is greater than zero.

At the bottom of the table, running totals are shown for the entire inspection: **total inspected square footage**, **total maximum occupancy**, and **total maximum sleeping persons**.

---

### Space Details Dialog

Click **edit space details** in a space row to open the details dialog. This is not available once the inspection has a determination or has been dispatched.

![spacedetailsdialog.png](/inspections/spacedetailsdialog.png)

#### Location panel

| Field | Notes |
|---|---|
| Location description | Free-text. Describe where in the building this space is. |
| Building floor number | Integer. Use 0 to leave blank, negative for below-grade. |

> Floors numbered 0 will not appear in the space list. Basement = −1, not 0.

#### Size panel

Up to **two rectangular areas** can be measured per space. Enter length and width in **feet and inches separately**; the square footage for each area is computed automatically. The dialog shows the combined total square footage for both areas.

Use a second area when the room has an irregular shape that is best approximated as two rectangles.

#### Occupancy Restrictions panel

| Field | Notes |
|---|---|
| Maximum persons | Maximum legal occupancy count for this space. |
| Maximum sleeping persons | Separate limit for use as sleeping quarters. |
| Egress count | Number of compliant egress routes. |

#### Notes panel

A rich-text editor for any observations, explanations, or follow-up notes specific to this space. Supports bold, italic, underline, colored text, and bulleted/numbered lists.

#### Space Designations panel

Boolean designations (bedroom, living area, kitchen, bathroom, finished space). Note: these save to the database but do not currently appear on reports.

#### Saving and cancelling

- **Cancel** — discards all changes and restores the space to its last saved state.
- **Save** — writes all changes to the database and refreshes the inspection table immediately.

---

### Space Display Order

By default, spaces are listed in the following computed order:

1. Highest floor first, descending (floor 5 → 4 → 3 → 2 → 1 → 0 → −1 → −2 …).
2. Within each floor, alphabetically by space type name.

This computed order is applied automatically on every load — no setup is needed.

#### Setting a custom order

To reorder spaces manually:

1. Click **edit space order** in the column header. Each space row shows a small control box with four links.
2. Use **to top**, **move up**, **move down**, and **to bottom** to reposition individual spaces. Each click saves the new order to the database immediately — there is no separate save step.
3. Click **done ordering** when finished. The custom order is now the permanent display order for this inspection.

![editspaceorder.png](/inspections/editspaceorder.png)
![reorderingtools.png](/inspections/reorderingtools.png)

#### Resetting to default

Click **reset order** (visible while in ordering mode) to clear all custom positions and return to the computed floor + alphabetical order. The reset takes effect immediately.

#### How the order is stored

Custom order is stored per space as a position number. If a new space is added to an inspection that already has a custom order, the system detects that the new space has no position number and automatically falls back to the computed floor + alpha order for the whole inspection. Re-enter ordering mode to re-establish a custom sequence that includes the new space.

---