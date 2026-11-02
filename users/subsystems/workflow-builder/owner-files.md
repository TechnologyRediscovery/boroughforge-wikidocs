---
title: Owner Files
description: What an owner file is, how CodeNforce builds one from your property and person links, how its mailing address is chosen, and how to read the saved list
published: false
date: 2026-10-16T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:overview
editor: markdown
dateCreated: 2026-10-15T12:00:00.000Z
---

# Owner Files

An **owner file** is CodeNforce's version of the paper folder you keep for one owner: the owner, the
businesses they control, the properties they own, and the one address mail should go to. Each file has
a permanent **File number**, so you can write it on a printout and find it again.

> **Who can use this.** Municipal staff and above. The tools are in the **Owner Files** panel on the
> **Rental registry manager** page: open **muni tools** at the top of any page and click
> **rental registry manager**.

<!-- SCREENSHOT NEEDED: The Owner Files panel on the Rental registry manager page showing the toolbar, the summary cards and the by-owner-file table with a few saved files. -->

## What is in a file

- **The head.** One person (or, when no person is known, one business) whose name is on the folder tab.
  A person heads at most one file in a municipality.
- **Everything the head owns in the municipality.** Not only the properties in one group: the file
  follows the owner to every property they own.
- **Businesses the head controls.** A business linked to the head with the **Owner of Business** role
  is folded into the head's file, together with its properties. This goes one level only: the head,
  the businesses the head controls, and those businesses' properties. A business with two or more
  controllers is never merged into anyone's file; the head's file is flagged instead.
- **A mailing name and address.** Chosen as described below, and always changeable by a clerk.

Nothing in a file is a second copy of your data. The properties and businesses are read from the
property and person links every time the panel loads, so if you fix a link, the next reload shows it.
What a file *does* store is what you decided: its head, its title, the paper file reference, a declared
mailing name and address, and a log of everything done to it.

## What the panel shows

When you open the **Rental registry manager** page the **Owner Files** panel loads by itself and shows the
**saved** owner files, one row per file, read from each head person's current links. There is nothing
to derive first. Click **Reload saved files** to read them again after you fix a link elsewhere.

The panel's buttons are for the jobs you do now and then:

| Button | What it is for |
|---|---|
| **Add an owner file** | Start one file by choosing its head person. See [Add an owner file](/users/subsystems/workflow-builder/add-an-owner-file). |
| **Seed more files from a parcel group** | Create many files at once from the owners of one parcel group. See [Derive and save owner files](/users/subsystems/workflow-builder/derive-and-save-owner-files). |

Under the buttons you see:

- **Summary cards** counting the saved files, the businesses folded into them, how mailing addresses
  were found, and how many files share an address with another file.
- **Pending review**: log rows someone flagged for a second look. See
  [Lock and review owner files](/users/subsystems/workflow-builder/lock-and-review-owner-files).
- **Print and export**: the audit list, mailing labels and CSV. See
  [Print the audit list, mailing labels and CSV](/users/subsystems/workflow-builder/print-owner-file-labels-and-audit-list).
- The list itself, with a switch between **By owner file** and **By property**.

### By owner file

One row per file: **Title**, **Mail-to address** (with how it was found), **Parcels**,
**Members**, **Cycle lock**, **Flags**, **Last activity**, and the row's actions. The file's number
is shown as **(ID: N)** under the **Actions** menu in the last column.

- **Title** is the file's title, unless a clerk gave the file a **Mail-to name**; then the list shows
  that name.
- **Mail-to address** has a **change mailing address** link that opens a window to pick the address
  (**view mailing address** when the file is locked). **view / edit** opens **Manage owner file name
  and sorting**. See [Edit an owner file](/users/subsystems/workflow-builder/edit-an-owner-file).
- **Cycle lock** shows **locked** or **open** for the cycle in the **Rental cycle** box, with a **lock
  now** link on open files, and sorts when you click its heading. A locked file's name and mailing
  address cannot be edited. See
  [Lock and review owner files](/users/subsystems/workflow-builder/lock-and-review-owner-files).
- **Flags** has a drop-down filter; choose **Needs review** to see the files with an open review.
- **Parcels** counts every distinct property in the file: the head's own plus those of the businesses
  folded in.
- **Members** counts the **businesses folded into the file**: other people or businesses the head
  controls (linked with the **Owner of Business** role) that own at least one property in your
  municipality and that no one else also controls. It never counts the head, the properties, or
  co-owners. A **0** means the head owns everything directly. Only one level counts: a business
  controlled by a member is not folded in.

Click the arrow at the left of a row to see its mailing address choices, flags, folded businesses,
properties and log. In the **Parcels** table the **Groups** column shows a chip for every parcel group
a property is in. The **Log** under it lists everything done to the file, newest first. See
[Edit an owner file](/users/subsystems/workflow-builder/edit-an-owner-file) for the row actions.

### By property

One row per property per file, with **Property**, **Parcel ID**, **Owner of record**, **Owner file**,
**Role** (the head owns it, or a business the head controls) and the file's flags. Use the filter boxes
in the column headers to find a property and see which file it is in. A property that sits in two
files (co-ownership) appears twice, once per file.

<!-- SCREENSHOT NEEDED: The By property view with a filter typed into the Property column. -->

### Seed roles

The collapsed **Seed roles driving the derivation (read only)** box lists the link roles CodeNforce
reads: which role means "owns a property", which means "owner-occupant of", and which means "controls
a business", and from which end. Today these are changed by your administrator, not on this page.

## How the mailing address is chosen

For each file, CodeNforce looks for the address in this order and stops at the first that applies:

1. **An address a clerk declared** for the file, as long as that address link is still active.
2. **The head's one mailing address**, when the head has exactly one distinct address.
3. **A choice for a clerk**, when the head has two or more different addresses. The most recently
   updated one is shown as the proposal.
4. **The parcel owner-mailing address**, when the head has none of their own and the file's
   properties carry one (or several) owner mailing addresses. With several, the most common one is
   proposed; a tie proposes nothing.
5. **No address.** The file cannot get a label until someone adds or declares one.

Address priority and the "designation" setting are not used here. The addresses of businesses folded
into a file are never used on their own; they are only offered to a clerk as choices. A clerk can always
override the data with
[a declared address](/users/subsystems/workflow-builder/edit-an-owner-file).

## Flags

Each file shows small colored flags where the data needs a human look. The ones you will see most:

| Flag | What it means |
|---|---|
| **No mailing address** | Nothing usable was found; no label is made for this file. |
| **Head addresses differ** / **Parcel addresses differ** | Two or more candidate addresses. Pick one. |
| **Address from parcel link** | The address came from the property, not from the owner. |
| **Same address as another file** | Often the same owner entered twice. Merge true duplicates, then reload. |
| **Entity has 2+ controllers** | A business with more than one controller was not merged into any file. |
| **Controls an entity it does not hold** | The head controls a business that someone else also controls, so that business and its properties are not listed in this file. |
| **Parcel in 2+ files** / **Person in 2+ files** | Co-ownership, or a person who heads one file and sits in another. |
| **No current parcels** | A saved file whose owner no longer owns anything. Consider retiring it. |
| **Head deceased** | The head person has a deceased date. |
| **Declared address retired** | The address a clerk declared has since been retired; the data's address is used. |
| **Needs review** | Someone flagged the file for a second look and the review is not resolved yet. Use **resolve review** to clear it. |
| **Address not verified** / **PO box address** | Information for whoever checks the labels. |

## The owner file badge on properties and people

When a property or a person is in one of your municipality's owner files, a badge says so on their profile. Anyone working in the municipality can see it; it is read from the owner links each time, so if you fix a link the badge follows.

- **On a property:** an **Owner file** row between **Units** and **Property Groups** reads **In rental owner file**, with the file number, its title and why the property is in it (the owner of record heads the file, or an entity the head controls holds it).
- **On a person:** an **Owner file** row directly above **Job title** reads **Owner of 1+ rentals**, with the file.
- **Two or more files:** if a property turns up in more than one owner file, the row becomes a warning and lists every file. Owner files should never overlap, so fix the owner links until only one file holds the property.
- **Open the file:** staff at MuniStaff level and above can click the file to open the Rental registry manager. Other users see the same text without the link.

You will **not** see a badge for a co-owner who has no file of their own, for a business with two or more controllers, or for a file head whose file lists no property now.

## What gets recorded

Every change to a saved file, every lock, flag and review, and every label printed from it, adds a row
to the file's log: who, when, what, and which run. Opening the audit list is **not** logged. The log is
never edited (only a review row gets its outcome filled in). A label's log row records the sheet, the
slot and the exact lines that were printed.

## Related pages

- [Add an owner file](/users/subsystems/workflow-builder/add-an-owner-file)
- [Derive and save owner files](/users/subsystems/workflow-builder/derive-and-save-owner-files)
- [Edit an owner file](/users/subsystems/workflow-builder/edit-an-owner-file)
- [Lock and review owner files](/users/subsystems/workflow-builder/lock-and-review-owner-files)
- [Print the audit list, mailing labels and CSV](/users/subsystems/workflow-builder/print-owner-file-labels-and-audit-list)
