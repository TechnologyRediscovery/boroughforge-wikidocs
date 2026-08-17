---
title: Documentation backlog
description: Forward-looking list of documentation reorganization work
published: true
date: 2026-07-21T21:20:00.000Z
tags: 
editor: markdown
dateCreated: 2026-07-21T21:20:00.000Z
---

# Documentation backlog

Forward-looking list of doc-repo work. For a log of what's already been done, see [Doc change log](/system/doclog).

## Carried over

- Wire navigation links to `admin/westmc-data-exchange.md` from `admin.html` and `dev/data.md`.
- Manually delete `system/releases/release_notes.xhtml` (superseded by `releasenotes.md` / `releasenotes-archive.md`).
- **Write the 12 orphaned help-topic pages** left by the SL.4 static-link migration
  (2026-08-16) — real content never existed for these, so their in-app help icons were removed
  rather than left pointing at a permanent homepage fallback. Full topic-by-topic list, legacy
  anchor context, and re-linking steps: [static-link-orphaned-topics.md](/system/static-link-orphaned-topics).

## Next big topics

See [dev/architecture/docs-overhaul-aug26.md](/dev/architecture/docs-overhaul-aug26) —
**signed off 2026-08-07**. The five-branch model, subsystem registry, and page-type
conventions are approved; migration is starting with `cecase` as the pilot subsystem.

1. **Consolidate down to five main branches** — `system`, `dev`, `admin`, `users`, `public`
   (amended from four: `public` split out of `users` as its own security boundary — see
   the overhaul plan §3). **Approved.**
2. **Build a subsystem overview listing in `system/`** — **done**, see
   [system/subsystem-registry.md](/system/subsystem-registry). All 23 per-subsystem hub pages
   (`system/subsystems/<slug>.md`) are **written 2026-08-07** — one flat batch, ahead of any
   branch content existing.
3. **Develop a template + plan for organizing subsystem docs within each branch** — decided
   in the overhaul plan §§4–7. **Done 2026-08-07:** all 77 spoke stubs
   (`<branch>/subsystems/<slug>/overview.md`) written in one batch — `published: false`,
   marked `🚧 Stub`, ready to be filled in and flipped to `published: true` as real content is
   written. (Correction from the same-day earlier note: since the Wiki.js browser editor is
   never used for normal editing, "create the page on demand" isn't a real option here — the
   file has to already exist in git. See overhaul plan §8b.) Full migration of *existing*
   scattered content (see hygiene items below) is intentionally still backlogged and does not
   block writing into these stubs for new features.

## Immediate hygiene items found during the Aug 2026 review

- ~~Stray raw JSF source file at repo root: `occPermitApplicationUnitList.xhtml`~~ **Deleted
  2026-08-07.**
- ~~Orphaned root-level image folders~~ **Corrected & resolved 2026-08-07.** Only 2 of 17
  images were actually unreferenced (`properties/propgroups.png`,
  `inspections/addspacebytype.png`) — moved to a new root `xarchive/` folder. The rest of
  `/cecases/`, `/permitting/`, and `/inspections/` are live, actively-referenced image
  folders (absolute Wiki.js paths from real pages) and will be folded into each subsystem's
  own `img/` folder during that subsystem's migration pass, not deleted.
- 22 remaining CKEditor `.html` pages still need the markdown conversion already done for
  `release_notes.xhtml`.
- ~~`users/Basics/` is the only capitalized folder in the tree~~ **Renamed to `users/basics/`
  2026-08-07**, including the fix to `home.html`'s broken `/users/hardware` link.
- `tags:` frontmatter is empty on every page — unused navigational axis, see overhaul plan §6.
