---
title: Static-link orphaned topics (content backlog)
description: Stable help-link IDs unlinked from the app during SL.4 because no real content exists yet
published: true
date: 2026-08-16T00:00:00.000Z
tags: 
editor: markdown
dateCreated: 2026-08-16T00:00:00.000Z
---

# Static-link orphaned topics

During the SL.4 migration pass (2026-08-16 — see
[static-link-redirect-architecture.md §Migration Plan](/dev/wiki.js/static-link-redirect-architecture)
and the codenforce repo's `docs/worklog.md`), every hardcoded `technologyrediscovery.github.io`
help link in the codenforce WAR was swept: 28 files, 54 link occurrences. **No untracked/orphan
links were found** — every single occurrence mapped cleanly to one of the 21 stable IDs already
registered in `helpmap/_redirects` from SL.0's re-inventory. What this page actually tracks
instead: the **12 of those 21 IDs that still have no real content anywhere** in the `users/`
tree after a fresh look. Their hardcoded link markup was removed from the app entirely (a
permanent redirect-to-homepage icon is worse than no icon at all), but the stable ID itself is
kept reserved in `_redirects` — write the page, then follow the "Re-adding a link" steps below.

This is a content-authoring backlog, not an engineering one — SL.4 (the redirect/component
engineering) is done; what's below is real writing work for whoever picks up each subsystem
next.

## How to use this list

For each topic: write the real `users/` page (or add a section to an existing one), then:

1. Uncomment/fix the matching line in `helpmap/_redirects` (change `# TODO <id> ...` to a real
   `<id>  /users/...` line).
2. Add `<tt:helpLinkCC helpId="<id>" />` back at each file/location listed below (the markup was
   removed, not just commented out, so this is a small manual re-add, not an uncomment).
3. Push both — `_redirects`' CI deploys automatically; the XHTML change needs one WAR deploy
   (can be batched with other unrelated changes, no rush).

## Help links that 302 to the docs home
May or may not be in the orphan list. Discovered by ECD during manual checking
* Header of occupancy certs
* CeCase priority column header


## Orphaned topics

### `cecase-cross-muni` — cross-municipality case/person handling

**Legacy anchor:** `case/crossmuni.html` (a whole dedicated legacy page, not a page section).
**Locations removed:** `restricted/navContainer_restricted.xhtml` (top nav, cross-muni banner),
`restricted/cogstaff/person/compositions/personTools.xhtml` (×2 — person-connections panel
header, and a per-row cross-muni indicator in the person-links table).
**Content needed:** what "cross-muni view mode" is, how a case/person can be linked across
municipality boundaries, and what a code officer sees differently in that mode.

### `cecase-cears-internal` — internal CEAR management tools

**Legacy anchor:** `public/cears.html#internal-cear-management-tools`.
**Locations removed:** `resources/components/propCEARSCC.xhtml`,
`restricted/cogstaff/ce/compositions/ceCaseCEARPanel.xhtml`,
`restricted/cogstaff/prop/compositions/propCEARS.xhtml`.
**Content needed:** the logged-in-staff side of CEAR review/processing (as opposed to the
public CEAR submission flow, which `cear` subsystem docs already partially cover). The `cear`
subsystem's `users/subsystems/cear/overview.md` is still an unpublished stub — this topic
likely belongs there once written.

### `cecase-events-add` — logging an event on a case

**Legacy anchor:** `case/casescreen#log-an-event`.
**Locations removed:** `resources/components/eventListPanelCC.xhtml` (×2),
`restricted/cogstaff/event/compositions/eventListPanel.xhtml` (×2).
**Content needed:** logging an event directly from a CE case screen. Note:
`users/subsystems/property/add-an-event.md` already documents the *property*-side version of
this same dialog — worth reusing as a template/reference, but confirmed (2026-08-16) to be
property-specific in its click path, not a valid substitute as-is.

### `code-enter-ordinance` — entering an ordinance into CodeNforce

**Legacy anchor:** `code/fullcodemodule#enter-an-ordinance-into-codenforce`.
**Locations removed:** `restricted/cogstaff/code/codeElementManage.xhtml` (×2).
**Content needed:** `users/subsystems/codebook/overview.md` is still an unpublished stub with
only a link to the text-block manager — this is core missing codebook content.

### `code-add-to-codebook` — adding an ordinance to a code book

**Legacy anchor:** `code/fullcodemodule#add-an-ordinance-to-a-code-book`.
**Locations removed:** `restricted/cogstaff/code/codeSetManage.xhtml` (×2).
**Content needed:** same codebook-overview gap as above — likely the same page, different
section.

### `code-create-checklist` — creating an inspection checklist

**Legacy anchor:** `code/fullcodemodule#create-a-checklist`.
**Locations removed:** `restricted/cogstaff/occ/inspectionChecklistTools.xhtml`.
**Content needed:** unclear whether this is a `users/` or `admin/` topic — the in-app text next
to this link ("checklists can be set up with the admin") suggests it may actually belong under
`admin/subsystems/`, not `users/subsystems/codebook/` or `users/subsystems/inspections/`. Worth
a scope decision before writing.

### `cecase-upload-files` — uploading files and photos

**Legacy anchor:** `case/casescreen#upload-files-and-photos`.
**Locations removed:** `restricted/cogstaff/ce/compositions/ceCaseBlobs.xhtml` (×2),
`restricted/cogstaff/occ/compositions/occPeriodBlobs.xhtml` (×2). Same topic, two parent
object types (CE case and occ period) — one page can likely cover both.
**Content needed:** the `files` subsystem (#15) has no `users/` content at all yet
(`files-overview` is still a `# TODO` stub per the full tree-coverage pass) — this is a bigger
gap than just this one topic.

### `cecase-add-violation` — adding a code violation to a case

**Legacy anchor:** `case/casescreen#add-a-violation`.
**Locations removed:** `restricted/cogstaff/ce/compositions/ceCaseCodeViolations.xhtml` (×2).
**Content needed:** core case-workflow content, currently missing from `cecase`'s 2 real pages
(`overview.md`, `caseload-manager.md`).

### `cecase-nov-prepare` — starting/preparing a Notice of Violation

**Legacy anchor:** `case/casescreen#prepare-a-notice-of-violation`.
**Locations removed:** `restricted/cogstaff/ce/compositions/ceCaseNoticesOfViolation.xhtml`
(the "New Letter" NOV button).
**Content needed:** the whole NOV authoring flow — see also the next two entries, all from the
same file/feature.

### `cecase-nov-add-person` — adding a new person while creating an NOV

**Legacy anchor:** `case/casescreen#add-a-new-person-when-creating-an-nov`.
**Locations removed:** `restricted/cogstaff/ce/compositions/ceCaseNoticesOfViolation.xhtml` (×2).

### `cecase-nov-add-address` — linking a new address while creating an NOV

**Legacy anchor:** `case/casescreen#link-a-new-address-when-creating-an-nov`.
**Locations removed:** `restricted/cogstaff/ce/compositions/ceCaseNoticesOfViolation.xhtml` (×2).
**Note:** these 3 NOV entries are all sub-steps of one bigger workflow — likely best written as
one page (or one section of the `letters` subsystem's docs, since NOVs are a letter type) with
3 internal anchors, rather than 3 separate pages.

### `property-link-multiple-people` — linking several people to a property/case at once

**Legacy anchor:** `property/personslinking#link-multiple-people-to-a-property-or-case-at-once`.
**Locations removed:** `restricted/cogstaff/person/compositions/personTools.xhtml` (×2 — the
"Selected persons for linking" batch panel).
**Note:** reviewed both `users/subsystems/person/connecting-people-to-properties.md` and
`updating-person-property-links.md` on 2026-08-16 — neither documents a multi-select/batch
link operation, so this is a genuine content gap, not a mis-filed duplicate (the earlier
"likely duplicate" flag from SL.2 is resolved — see `_redirects`' comments on
`property-persons-link` / `property-link-mailing-address` for the corrected picture).

See also: [subsystem registry](/system/subsystem-registry), [documentation change
log](/system/doclog), and [docbacklog](/system/docbacklog).
