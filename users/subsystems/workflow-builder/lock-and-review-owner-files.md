---
title: Lock and Review Owner Files
description: Lock an owner file for a rental cycle's mailing, unlock it, flag a file for a second look, and resolve flagged reviews
published: false
date: 2026-10-16T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-16T12:00:00.000Z
---

# Lock and Review Owner Files

Two small tools keep a mailing honest: a **lock** records exactly what a file would mail for a rental
cycle, and a **review** lets one clerk ask another to look at a file. New to owner files? Start with
[Owner Files](/users/subsystems/workflow-builder/owner-files).

## Lock a file for a rental cycle

Locking is a record, not a barrier. It does not stop anyone from editing the file or printing labels.

1. In the **Print and export** box, type the **Rental cycle** (for example `2026-2029`). The lock
   applies to this cycle.
2. In the file's row open **Actions** and choose **Lock for the cycle**.
3. Optionally type a note, then click **Lock file**.

CodeNforce reads the file's links again and writes one log row with a **snapshot**: the label lines,
the mailing name and address, the businesses folded in and every property with its owner link. That row
is the record of what was mailed for the cycle.

The **Cycle lock** column then shows **locked** for files locked for the cycle in the **Rental cycle**
box, and **open** for the rest. Change the cycle in the box to see another cycle's locks. Editing a
locked file shows a warning in the edit window; saving is still allowed.

<!-- SCREENSHOT NEEDED: The by-owner-file table with the Cycle lock column showing locked and open files and the Actions menu open on one row. -->

### Unlock

1. Open the file's **Actions** menu and choose **Unlock for the cycle**.
2. Type why the file is being unlocked (required) and click **Unlock file**.

The unlock is another log row. The earlier snapshot stays on the log. Each cycle is locked and unlocked
on its own.

## Flag a file for review

Use this when a file needs a second look, for example an address you doubt.

1. Open the file's **Actions** menu and choose **Flag for review**.
2. Say what needs a second look (required) and click **Flag file**.

The file itself is not changed. A row waits in **Pending review**, a box on the panel that shows how
many reviews are waiting.

## Resolve a review

1. Open **Pending review** and click **resolve** on a row. The row shows which file, who flagged it, when,
   and why.
2. Choose an **Outcome**: resolved, no action needed, deferred, ask the developer, or other (describe it
   in the notes).
3. Optionally add **Notes**, then click **Resolve review**.

The outcome and your name are recorded on the flagged row, and a second row records the resolution.
Nothing is deleted. A review someone else already resolved cannot be resolved twice.

<!-- SCREENSHOT NEEDED: The Resolve a review dialog with the outcome list open. -->
