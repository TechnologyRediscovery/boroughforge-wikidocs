---
title: Lock and Review Owner Files
description: Lock an owner file for a rental cycle's mailing (quickly, or with a note), unlock it, flag a file for a second look, filter files that still need review, and resolve flagged reviews
published: false
date: 2026-10-28T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-16T12:00:00.000Z
---

# Lock and Review Owner Files

Two small tools keep a mailing honest: a **lock** records exactly what a file would mail for a rental
cycle and freezes the file's name and mailing address, and a **review** lets one clerk ask another to
look at a file. New to owner files? Start with [Owner Files](/users/subsystems/workflow-builder/owner-files).

## Lock a file for a rental cycle

A lock is **real**: while a file is locked for the cycle, its name and sorting and its mailing address
are view only. It does not stop printing labels.

The cycle is the one in the **Rental cycle** box in the **Print and export** box (for example
`2026-2029`). The lock applies to that cycle, so keep the box on the cycle you are mailing.

**Quick lock.** In the **Cycle lock** column, an unlocked file shows **open** and a **lock now** link.
Click it: the file is locked at once, with no window to confirm, and the row updates in place.

**Lock with a note.** In the file's row open **Actions**, choose **Lock for cycle**, optionally type a
note, then click **Lock file**. The note is optional.

CodeNforce reads the file's links again and writes one log row with a **snapshot**: the label lines,
the mailing name and address, the businesses folded in and every property with its owner link. That row
is the record of what was mailed for the cycle.

The **Cycle lock** column shows **locked** for files locked for the cycle in the **Rental cycle** box,
and **open** for the rest. Click the column heading to sort the table by it. Change the cycle in the box
to see another cycle's locks.

While a file is locked, **Manage owner file name and sorting** and **Change mailing address** open
view only (see [Edit an owner file](/users/subsystems/workflow-builder/edit-an-owner-file)), and the
system refuses a save even from a window that was opened before the lock. Adding a log entry, flagging
for review, changing the head, adding a property to a group, retiring, and unlocking are still allowed.
Anyone who can manage owner files can lock and unlock.

<!-- SCREENSHOT NEEDED: The by-owner-file table with the Cycle lock column showing locked files, open files with the lock now link, and the Actions menu open on one row. -->

### Unlock

1. Open the file's **Actions** menu and choose **Unlock for cycle**.
2. Optionally type a note and click **Unlock file**.

The unlock is another log row, and the file's name and address are editable again. The earlier snapshot
stays on the log. Each cycle is locked and unlocked on its own.

## Flag a file for review

Use this when a file needs a second look, for example an address you doubt.

1. Open the file's **Actions** menu and choose **Flag for review**.
2. Say what needs a second look (required) and click **Flag file**.

The file itself is not changed. A row waits in **Pending review**, a box on the panel that shows how
many reviews are waiting, and the file gets a **Needs review** flag in the **Flags** column (hover over
it for the reason).

## Find the files that still need review

The **Flags** column has a drop-down filter under its heading. Choose **Needs review** to list only the
files with an open review. Choose **All flags** to clear the filter.

## Resolve a review

The **Needs review** flag stays on a file until its review is resolved. There are three ways in, and
all open the same window:

- click **resolve review** in the file's **Flags** cell;
- open the file's **Actions** menu and choose **Resolve review**;
- open **Pending review** and click **resolve** on the row.

Then:

1. The row shows which file, who flagged it, when, and why.
2. Choose an **Outcome**: resolved, no action needed, deferred, ask the developer, or other (describe it
   in the notes).
3. Optionally add **Notes**, then click **Resolve review**.

The outcome and your name are recorded on the flagged row, a second row records the resolution, and the
**Needs review** flag leaves the file. Nothing is deleted. A review someone else already resolved cannot
be resolved twice. A file flagged more than once keeps the flag until every one of its reviews is
resolved.

<!-- SCREENSHOT NEEDED: The Resolve a review dialog with the outcome list open. -->
