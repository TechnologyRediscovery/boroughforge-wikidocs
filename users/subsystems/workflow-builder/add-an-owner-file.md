---
title: Add an Owner File
description: Start one owner file by choosing its head person, read the person's linked properties and businesses before saving, and change a file's head person later
published: false
date: 2026-10-16T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-16T12:00:00.000Z
---

# Add an Owner File

Use this to start a single owner file, or to move an existing file to a different head person. To
create many files at once from a parcel group, see
[Derive and save owner files](/users/subsystems/workflow-builder/derive-and-save-owner-files). New to
owner files? Start with [Owner Files](/users/subsystems/workflow-builder/owner-files).

## What the head person decides

The **head** is the person whose name is on the folder tab. A file lists whatever the head owns in your
municipality, the businesses the head controls, and those businesses' properties, all read from the
property and person links. Choosing the head is therefore the whole job: you do not list properties by
hand. A person heads at most one file in a municipality.

## Add one file

1. On the **Owner Files** panel click **Add an owner file**.
2. Type at least three letters of the person's name in **Person's name (3 letters or more)** and click
   **Find person**. Typing several words narrows the list: every word has to appear in the name.
   County records usually put the last name first, for example `SMITH JOHN A`.
3. Read the list. Each row shows how many properties the person owns **here** (**Parcels owned here**),
   how many businesses they control (**Entities controlled**), and whether they **Already heads** a
   file. Where several records look like the same owner, the one with the most properties is listed
   first; pick the record that actually holds the links.
4. Click **choose** on the right person. A person who already heads a file cannot be chosen: open that
   file instead.
5. Optional: click **Read linked objects**. This reads the person's links and shows, before anything is
   saved:
   - the properties the person owns directly,
   - each business the person controls, and the properties each of those owns,
   - the flags and the mailing address the file would get.

   It writes nothing. If something is missing, fix the link on the person or the property and read
   again.
6. Change the **Title** if you want a different label sort name. It starts as the person's name exactly
   as recorded.
7. Click **Create file**.

The new file gets a permanent **File number** and a log row (**File created by a clerk**) that
records what it held when it was created. It appears in the panel's list straight away.

<!-- SCREENSHOT NEEDED: The Add an owner file window with the person list, one person chosen, and the Read linked objects result showing the person's parcels and a controlled business. -->

> **Tip:** If the same owner is recorded twice, merge the duplicate people first. A file belongs to its
> head person, so the duplicate would get a second file.

### What "read linked objects" follows

CodeNforce follows only the link roles listed in the panel's **Seed roles driving the derivation**
box: the role that means a person **owns** a property (and the **owner-occupant** role), and the
**Owner of Business** role from the person to the businesses they control. It goes one level down: the
person, the businesses they control, and those businesses' properties. A business that has two or more
controllers is not pulled into the file, and the head's file is flagged **Controls an entity it does
not hold**.

## Change a file's head person

Use this when a file was started on the wrong person record, for example a duplicate of the real owner.

1. In the file's row open the **Actions** menu and choose **Change head person**.
2. Find the new head person as above and click **choose**. A person who already heads another file
   cannot be chosen: merge the duplicate people, or retire the other file, first.
3. Optionally click **Read linked objects** to see what the file will hold under the new head.
4. Check **Title after the change**. It follows the new head's name only when the old title was still
   the old head's name; a title someone edited is kept.
5. Optionally type a **Reason**. It is kept on the file's log.
6. Click **Change head**.

The file keeps its File number, its declared mailing name and address, its paper reference and its
history. The log records the old and the new head, the reason, and any title change. Check the mailing
name and address afterwards: they were declared for the old head.

<!-- SCREENSHOT NEEDED: The Actions menu open on a file row, with Change head person highlighted. -->
