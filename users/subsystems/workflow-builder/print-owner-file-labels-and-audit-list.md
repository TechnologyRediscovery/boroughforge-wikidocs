---
title: Print the Audit List, Mailing Labels and CSV
description: Print the audit list for clerks to check, build Avery 5160 mailing labels, calibrate your printer, and export the roster
published: false
date: 2026-10-16T12:00:00.000Z
tags: subsystem:workflow-builder, audience:staff, type:howto
editor: markdown
dateCreated: 2026-10-15T12:00:00.000Z
---

# Print the Audit List, Mailing Labels and CSV

Everything here works on the **saved** owner files in the list, in title order, one entry per file.
New to owner files? Start with [Owner Files](/users/subsystems/workflow-builder/owner-files). Add or
seed files first if the list is empty.

All four tools are in the **Print and export** box of the Owner Files panel. Start by filling in the
box:

- **Rental cycle**: for example `2026-2029`. Required for the audit list, the labels and the CSV. It
  is also the cycle a [lock](/users/subsystems/workflow-builder/lock-and-review-owner-files) applies to.
- **Labels already used on the first sheet**: how many labels of a part-used sheet to skip.
- **Printer offset across** and **Printer offset up** (inches): see Calibrate your printer below.

<!-- SCREENSHOT NEEDED: The Print and export box with the cycle, skip and offset fields and the four buttons. -->

## Audit list

1. Click **Audit list (HTML)**. A printable page opens in a new window.
2. Click **Print this list** and print on letter paper.

There is one block per file with the mailing name and address, the address choices as check boxes, the
flags, the properties, and a **Clerk check against the paper file** section with boxes such as
**Correct as printed** and **Change mail-to address to**. The number printed on each block is the file's
File number, so a marked-up sheet can be handed to a clerk and matched back to the file. Files with no
address are listed again in an appendix.

Opening the page is **not** recorded in the owner file logs, and reloading it changes nothing. (Printing
labels is still recorded, below.)

## Calibrate your printer

Avery 5160 sheets are 30 labels, 3 across and 10 down. A printer rarely prints exactly where the sheet
expects, so check before you print real labels.

1. Click **Calibration page (PDF)**.
2. Print it on **plain paper at actual size** (no "fit to page" or scaling).
3. Hold it over a real Avery 5160 sheet against a light. The outlines should sit on the labels.
4. If the text prints too far left, increase **Printer offset across**. If it prints too low, increase
   **Printer offset up**. Print the calibration page again to check.

> **Note:** CodeNforce marks the Avery 5160 layout as **UNVERIFIED** until someone records a paper
> check of it, and the labels window repeats that reminder. It is a reminder to do the calibration step,
> not an error.

## Mailing labels

1. Click **Build labels (PDF)**. A window opens with the label run.
2. Read the **Exception report**: files that are not on a label and why (for example, no address, a name
   or line too wide for a label, or a character that cannot be printed). Fix those files and build
   again, or print them by hand.
3. Click **Download PDF**. When there are exceptions the button reads **I have reviewed the exceptions:
   download PDF**.

One label per file, sorted by title. The first line is the mailing name, then **ATTN:** when the
address says to use it, then the street line or **PO BOX**, then city, state and zip. A very long name
is split over two lines. The File number is not printed on the label.

Downloading writes one log row per saved file on a label (**Mailing label generated**), once per run:
the sheet, the slot and the exact lines printed. Downloading the same run again writes nothing. Building
labels again after a change starts a new run.

<!-- SCREENSHOT NEEDED: The Mailing labels dialog showing the label count and the exception report. -->

## CSV roster

Click **CSV roster**. The file has one row per saved file, in the same order as the labels, with the
address split into its parts, the flags, the paper reference, and the label **page** and **slot** (blank
for a file that is not on a label). It is a complete roster: a file with no label still has a row.
