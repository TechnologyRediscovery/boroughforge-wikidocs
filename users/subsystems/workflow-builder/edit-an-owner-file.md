---
title: Edit an Owner File
description: Change a file's title, paper reference, mailing name and mailing address, read its linked objects, add one of its properties to a parcel group, and retire a file
published: false
date: 2026-10-16T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-15T12:00:00.000Z
---

# Edit an Owner File

Every saved file has two links in its row, **view / edit** and **linked objects**, and an **Actions**
menu. New to owner files? Start with [Owner Files](/users/subsystems/workflow-builder/owner-files).

## Edit the file

1. In the file's row, click **view / edit**.
2. Change the **Title** (labels and lists sort on it), the **Paper file reference**, or the
   **Mail-to name** (blank uses the head's name).
3. Under **Mail-to address**, pick one of the offered addresses (the head's, a folded business's, or a
   parcel owner-mailing address; each shows where it comes from and which one the data would choose),
   or the first choice to use whatever the data says.
4. Click **Save changes**. Only real changes are written; each is logged. Saving with no changes
   says "Nothing changed".
5. If the file shows **Declared address retired**, the address picked earlier was retired; saving
   without picking one clears the old declaration.

If the file is locked for the rental cycle in the **Rental cycle** box, the window says so. The lock is
advisory: you can still save, but what you change will differ from the snapshot taken when the file was
locked. See [Lock and review owner files](/users/subsystems/workflow-builder/lock-and-review-owner-files).

To link the file to a different head person, see
[Add an owner file](/users/subsystems/workflow-builder/add-an-owner-file).

<!-- SCREENSHOT NEEDED: The Owner file edit dialog with the title, paper reference, mail-to name and the address radio list. -->

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
