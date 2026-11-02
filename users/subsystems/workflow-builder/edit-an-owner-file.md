---
title: Edit an Owner File
description: Change a file's title, paper reference and mailing name, change its mailing address in its own window, read its linked objects, add one of its properties to a parcel group, and retire a file
published: false
date: 2026-10-28T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-15T12:00:00.000Z
---

# Edit an Owner File

Every saved file has two links in its row, **view / edit** and **linked objects**, and an **Actions**
menu. New to owner files? Start with [Owner Files](/users/subsystems/workflow-builder/owner-files).

## Edit the file's name and sorting

1. In the file's row, click **view / edit**. The window is called **Manage owner file name and
   sorting**.
2. Change the **Title** (labels and lists sort on it), the **Paper file reference**, or the
   **Mail-to name** (blank uses the head's name).
3. Click **Save changes**. Only real changes are written; each is logged. Saving with no changes
   says "Nothing changed".

**Paper file reference** is where this owner's physical paper folder lives, for example a cabinet,
drawer or box number, so a clerk can walk to it. It is free text, up to 200 characters. CodeNforce
never reads it; it is printed on the CSV roster next to the file. Leave it blank when there is no paper
folder. Click **What is this?** beside the box in the window for the same explanation.

This window does not change the mailing address. The mailing address has its own window, below.

## Change the mailing address

1. In the file's row, find the **Mail-to address** column and click **change mailing address**. (If the
   file is locked, the link says **view mailing address** and the window is read only; see below.)
2. In the **Change mailing address** window, pick one of the offered addresses, or the first choice to
   use whatever the data says. The list shows each distinct address once, with where it comes from and
   its role: the owner's own addresses, a folded business's, every mailing address linked to any of the
   file's properties (whatever its role), and the own addresses of anyone linked to those properties as
   **property manager**. An address that comes from several places names all of them. The note also
   says which one the data would choose. Click an address to open its record.
3. Click **Save mailing address**. The change is logged.
4. If the window shows **Declared address retired**, the address picked earlier was retired; saving
   without picking one clears the old declaration.

## A locked file is view only

If the file is locked for the rental cycle in the **Rental cycle** box, both windows above open
**view only**: a **View only** note at the top says why, the boxes and choices are greyed out, there is
no save button, and **Cancel** reads **Close**. Saving is also refused by the system, so an old page left
open cannot get around the lock. Unlock the file first (**Actions**, **Unlock for cycle**; anyone who
can manage owner files can). The windows are also view only when the **Rental cycle** box is empty,
because a lock belongs to a cycle. A lock does not stop adding a log entry, flagging for review, changing
the head, adding a property to a group or retiring the file. See
[Lock and review owner files](/users/subsystems/workflow-builder/lock-and-review-owner-files).

To link the file to a different head person, see
[Add an owner file](/users/subsystems/workflow-builder/add-an-owner-file).

<!-- SCREENSHOT NEEDED: The Manage owner file name and sorting window with the title, paper reference (and its help tip) and mail-to name. -->
<!-- SCREENSHOT NEEDED: The Change mailing address window with the address radio list. -->

> **The list shows the mail-to name.** When a file has a **Mail-to name**, the **Title** column in the
> list shows that name instead of the file title. The title itself is unchanged; it is what labels and
> the CSV sort on.

## Assign a mailing address from the list

When the data cannot choose (the head has two or more different addresses, or the file's properties
carry two or more owner mailing addresses), the file's expanded row lists **Candidate addresses: a
clerk picks one**.

1. Expand the file's row.
2. At the end of the address you want, click **assign for mailing**.

This does the same as picking that address in the **view / edit** window: the address becomes the
file's declared mailing address and the change is logged. The list of candidates then disappears, and
the **Mail-to address** column shows it as declared by a clerk. Your title, paper reference and mailing
name are not touched. To undo it, open **view / edit** and choose the first address option. A proposal
that is not saved yet shows "save the file first" instead of the link.

## Read the file's log

At the bottom of the expanded row, under **Parcels**, the **Log** lists everything that was done to
the file, newest first: when, what, who, the rental cycle and the details. Hover over a description for
the technical details. Nothing in the log can be edited.

## Read the file's linked objects

Click **linked objects** in the file's row. CodeNforce reads the head person's links again right then
and shows the properties the head owns, then each business the head controls and that business's
properties, one level down. Each line says which link role and link it came from, so a wrong link can
be found and fixed on the person or the property. Nothing is stored: click **Reload saved files** on
the panel to refresh the table after you fix a link.

<!-- SCREENSHOT NEEDED: The Linked objects of an owner file window showing the head's parcels and one controlled business with its parcels. -->

## Add a property to a parcel group

An owner's property is sometimes not in the group you work from, for example **Rental Property**.

1. Expand the file's row, find the property in the **Parcels** table (its **In group** column says
   **not in group**), and click **add to group** in its **Groups** column. The column also shows a
   chip for every group the property is already in.
2. Choose the group (the municipality's reference group is preselected when the property is not in it)
   and click **Add to group**. This adds the property to the group **for everyone**, not only in this
   file, and logs it on the file. The row stays open and the new group appears as a chip.

<!-- SCREENSHOT NEEDED: The Add parcel to a group dialog. -->

## Retire a file

Use this for a file you no longer need, for example one marked **No current parcels** after its owner
sold everything or was merged into another person.

1. In the file's row open **Actions** and choose **Retire file**.
2. Optionally type a reason. It is kept in the file's log.
3. Click **Retire file**.

A retired file is deactivated, never deleted, and its File number is not reused. The person can be
given a new file later.
