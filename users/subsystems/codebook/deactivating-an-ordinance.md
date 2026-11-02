---
title: Deactivating an Ordinance or a Code Book Entry
description: What happens when you deactivate an ordinance or remove it from a code book, who is allowed to, and what to do when CodeNforce blocks it
published: true
date: 2026-11-02T00:00:00.000Z
tags: subsystem:codebook, audience:staff, type:howto
editor: markdown
dateCreated: 2026-11-02T00:00:00.000Z
---

# Deactivating an ordinance or a code book entry

Before CodeNforce deactivates an ordinance, it checks everywhere that ordinance is used, shows you the result, and lets you cancel. Only when you confirm does it deactivate the ordinance and remove it from the places that used it. You can start from two pages, and both show the same kind of dialog.

## What deactivating does, and what it never does

An ordinance can be used in three kinds of places:

- **Code books**: the code book entry that lists the ordinance.
- **Checklists**: a space type on an inspection checklist that includes the ordinance.
- **Lightning case templates**: a one-click case template that cites the ordinance.

When you deactivate an ordinance, CodeNforce removes it from every one of those places you are allowed to change, in one step. If anything goes wrong partway, **nothing** is changed.

**Inspections and violations that already used the ordinance are never changed.** Think of the code book as a menu: deactivating a dish takes it off the menu, but it does not change an order that was already placed. Existing inspection results, code violations, notices and letters keep the ordinance exactly as they had it.

Nothing is permanently deleted, with one exception. A lightning case template's link to the ordinance is removed, and the template gets a note recording what was removed, so the link can be re-added by hand (see [Undoing a deactivation](#undoing-a-deactivation)).

## Who can do it

The short version: you can deactivate an ordinance when **every place it is used belongs to your own municipality**. A **sys admin** can deactivate any ordinance.

An ordinance lives in a code source that many municipalities share, so one ordinance can sit in several municipalities' code books at once. Deactivating it would change those other municipalities' code books, checklists and lightning case templates. Only a sys admin may do that, which is why a shared ordinance needs one.

| The ordinance is used in... | Sys admin | Everyone else |
|---|---|---|
| Your municipality's code books, checklists or lightning case templates | Can deactivate | Can deactivate (if your account may manage that code source or code book) |
| Another municipality's active code book, checklist or lightning case template | Can deactivate, after ticking a confirmation box | **Blocked** |
| A code book with no owning municipality | Can deactivate | **Blocked** |
| An inactive code book, checklist or template of another municipality | Can deactivate | Listed, left alone, and **never blocks you** |

> **Manager required.** If your municipality requires a manager to change checklists or code books, a non-manager is blocked on the rows that need one. The dialog says *blocks you: manager required* next to those rows.

> **Leave cross-municipality view first.** While you are viewing another municipality, nobody, sys admins included, can deactivate an ordinance. Switch back to your own municipality and try again.

> **A lightning case template can never be left with no ordinance.** If removing this ordinance would leave a template with none, the deactivation is blocked for **everyone, sys admins included**. Edit that lightning case template first (give it another ordinance), then come back.

If your account is not allowed to manage the code source or code book in question, CodeNforce refuses the deactivation.

## Deactivate an ordinance from the Ordinances page

1. Open the **Ordinances** page and find the ordinance in the list.
2. Click **deactivate** on its row. The **Deactivate Ordinance** dialog opens.

   <!-- SCREENSHOT NEEDED: the Deactivate Ordinance dialog for an ordinance used in two code books, one checklist and one lightning case template, showing the three tables with a result next to each row and the commit button at the top -->

3. Read the dialog (see [Reading the dialog](#reading-the-dialog) below). It lists every code book, checklist space type and lightning case template that uses the ordinance, with what would happen to each.
4. If you are allowed to proceed, the dialog shows a button at the top such as **Deactivate and remove from 2 code books, 1 checklist entry and 1 lightning case template**. Click it. If the ordinance is used nowhere, the button simply reads **Deactivate ordinance**.
5. The ordinance list refreshes and the ordinance is gone. A confirmation message summarizes what was changed.

To back out, click **Cancel** (top left). Nothing has changed until you click the deactivate button.

## Remove a single ordinance from a code book

Use this when the ordinance should stay available elsewhere and you only want it out of **one code book**.

1. Open the **Code Books** page and select the code book.
2. Click **deactivate** on the entry's row. The **Deactivate code book entry** dialog opens.
3. It shows the same tables and the same results as above. Deactivating the code book entry also removes the ordinance from any checklist or lightning case template that uses **that entry**.
4. Click the deactivate button at the top.

The ordinance itself stays active and stays in its code source. Only this code book entry is removed. Nothing else about the code book changes.

## Remove several ordinances from a code book at once

1. On the **Code Books** page, tick the entries you want in the checkbox column.
2. Click **batch deactivate**. The **Deactivate code book entries** dialog lists each ordinance with its result.
3. Click the button at the top, which reads like **Deactivate 5 entries**.

Each entry is checked and deactivated on its own. An entry that is blocked for you is **skipped** and listed afterward with the reason; it never holds back the others. After the run, the dialog shows how many were deactivated and which were skipped.

## Reading the dialog

The dialog shows one table per place the ordinance is used. Each row ends with a result:

| Result | What it means |
|---|---|
| **will be deactivated** | Your deactivation will deactivate this code book entry or checklist entry. |
| **ordinance will be removed from it** | A lightning case template. The ordinance is removed from it and a note is added. The template keeps its other ordinances (the row says how many). |
| **inactive, left alone** | Already inactive. It is listed for information and is not changed (or it belongs to someone else's inactive object). |
| **blocks you: another municipality's** | An active use that belongs to another municipality. Only a sys admin can proceed. |
| **blocks you: no owning municipality** | A code book that has no owning municipality. Only a sys admin can proceed. |
| **blocks you: manager required** | Your municipality requires a manager for this change. |
| **blocks: it would be left with no ordinance** | A lightning case template would be left with no ordinances. Blocks everyone. |

One blocked row blocks the whole deactivation. CodeNforce never does half the job. The dialog then explains which rows blocked you, names the object and its municipality, and offers a link to email **support@codenforce.org** for sys admin help.

Rows marked *(yours)* belong to your own municipality.

### Sys admins: the confirmation box

When a deactivation would change **another municipality's** code books, checklists or lightning case templates, a sys admin must tick the box *I understand this changes other municipalities' code books, checklists or lightning case templates* before the deactivate button works. In batch mode there is one box per entry that needs it.

### If something changed while the dialog was open

If someone else changed one of the affected code books, checklists or lightning case templates while you were reading the dialog, CodeNforce does not guess. It tells you that things changed and that **nothing was deactivated**, refreshes the dialog and lets you review it again.

## Undoing a deactivation

There is no undo button. A sys admin can reverse a deactivation because every row one deactivation changes is stamped with the **same date and time**, along with who did it. That shared timestamp identifies exactly what a single deactivation touched, so a sys admin can reactivate just those rows.

The one exception is a lightning case template's link to the ordinance, which is removed outright instead of stamped. The note added to that template records the ordinance and the canned finding it carried, so a sys admin can re-add the link by hand. If you deactivated something by mistake, contact **support@codenforce.org** and say which ordinance and roughly when.

## See also

- [Text block manager](/users/subsystems/codebook/textblocks)
