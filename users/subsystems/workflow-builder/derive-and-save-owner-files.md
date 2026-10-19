---
title: Derive and Save Owner Files
description: Seed many owner files at once from a parcel group, read the flags, and save the proposals
published: false
date: 2026-10-16T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-15T12:00:00.000Z
---

# Derive and Save Owner Files

New to owner files? Start with [Owner Files](/users/subsystems/workflow-builder/owner-files).

**Seeding** creates many owner files at once: it reads the owners of one parcel group and proposes a
file for each. It is for the occasional bulk start, for example the first time a municipality sets up
its rental owners. For one file at a time, use
[Add an owner file](/users/subsystems/workflow-builder/add-an-owner-file). The saved files you already
have are always on the Owner Files panel itself; seeding only adds to them.

## Derive the proposals

1. Open **muni tools**, click **rental registry manager**, and find the **Owner Files** panel.
2. Click **Seed more files from a parcel group**. A window opens.
3. In **Seed parcel group**, choose the group whose owners should get files. **Rental Property** is
   selected for you when your municipality has it.
4. Click **Derive from links**.

Deriving reads your data and writes nothing. You can do it as often as you like.

<!-- SCREENSHOT NEEDED: The Seed owner files from a parcel group window after Derive from links, showing the summary cards and the unsaved proposals table. -->

## Read the result

- The **summary cards** count the group's properties, the owners and files, how mailing addresses
  were found, and how many files share an address with another file.
- Any **setup problems** appear in red above the cards. Fix those first.
- **Unsaved proposals** lists each file that does not exist yet. Click the arrow at the left of a row
  to see its mailing address choices, flags, folded businesses and properties.
- People who already head a saved file are not proposed again; a group whose owners all have files
  says "No unsaved proposals".
- **Seed group parcels with no owner link** are listed under the table. They cannot be mailed until
  an owner is linked to them.

> **Tip:** Merge duplicate owner records (the same person or company entered twice) **before** you
> save. A file belongs to its head person, so duplicates become separate files. The
> **Same address as another file** flag points them out.

## Save the proposals

1. Click **Save N proposed files** at the top of the window.
2. Read the confirmation, then click **Save files**.

Each proposal gets a permanent **File number** and a log row recording that it was proposed. The
title is the head person's name as it is today. The window closes and the new files appear in the
panel's list. Saving again writes nothing, because every file is already saved, and the button is
disabled when there is nothing to save.

<!-- SCREENSHOT NEEDED: The Owner Files panel list after saving, with the new File numbers in the by-owner-file table. -->

## Retire a file

Retiring is covered in [Edit an owner file](/users/subsystems/workflow-builder/edit-an-owner-file).
