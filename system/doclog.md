---
title: Documentation change log
description: Reverse-chronological log of structural changes to this wiki repo
published: true
date: 2026-07-21T21:20:00.000Z
tags: 
editor: markdown
dateCreated: 2026-07-21T21:20:00.000Z
---

# Documentation change log

Reverse-chronological log of structural changes made to this doc repo (file moves, conversions, deletions). For product release notes, see [Release notes](/system/releases/releasenotes).

## 2026-08-07

- Created [dev/architecture/docs-overhaul-aug26.md](/dev/architecture/docs-overhaul-aug26) \u2014
  a full proposal for the directory structure, subsystem registry, and page-type taxonomy
  needed before the doc site scales to hundreds of pages. Answers the three open items in
  `docbacklog.md` and amends the four-branch plan to five (`public` split out of `users`).
- **Signed off** the five-branch model, `accounts` slug, `permitting`/`occupancy`/
  `inspections` staying separate subsystems, `data-exchange` needing full `admin/` content,
  `best-practices/` (not `playbooks/`) naming, and `cecase` as the migration pilot.
- Deleted `occPermitApplicationUnitList.xhtml` (stray raw JSF source file, accidental).
- Renamed `users/Basics/` → `users/basics/` for casing consistency (`git mv`); fixed
  `home.html`'s `/users/hardware` link (was also missing the `basics` path segment) to
  `/users/basics/hardware`.
- Audited all 17 images in the root-level `/cecases/`, `/inspections/`, `/permitting/`,
  `/properties/` folders by grepping every filename against the whole repo. Only 2 were
  unreferenced (`properties/propgroups.png`, `inspections/addspacebytype.png`) — moved both
  to a new root `xarchive/` folder (mirrors the `xarchive/` convention already used in the
  codenforce Java repo for material not worth sorting). The remaining 15 are live and stay
  put until each subsystem's own migration pass folds them into a proper `img/` folder.
- Created [system/subsystem-registry.md](/system/subsystem-registry) — the canonical,
  arabic-numbered subsystem list (21 subsystems across 5 categories, plus 2 unnumbered
  cross-cutting/infra concerns), replacing the old Roman-numeral convention.

## 2026-07-21

- **21:20h** — Flagged `system/releases/release_notes.xhtml` as redundant now that its content lives in `releasenotes.md` / `releasenotes-archive.md`; queued for manual deletion.
- **21:20h** — Converted `system/releases/release_notes.xhtml` (PrimeFaces accordion, ~171 tabs) into markdown: `releasenotes.md` now holds only the current release (4.8.8), and `releasenotes-archive.md` holds the full historical archive (170 releases).
- **21:20h** — Manually deleted stale draft files/folders (migrated `drafts/gitlabrepo/` content and the disconnected `docs/userfacing` mirror artifact) after their content was relocated into this repo.
- **21:20h** — Created `users/workflows.md` (Workflow Builder Essentials guide), migrated from `drafts/gitlabrepo/lsa7-workflowimpl/workflow-builder-essentials.md`.
- **21:20h** — Created `admin/westmc-data-exchange.md` (WestMC Data Exchange System Administrator Operations Guide), migrated from `codenforce/docs/userfacing/westmc-data-exchange-admin-guide.md`.
- **21:20h** — Reviewed `docs-flow-architecture.md` and the GitLab CI `mirror_wikijs_drafts_to_github` job; decided to leave the CI mirror pipeline as-is, and to migrate content out of `docs/userfacing` (a disconnected folder, not the actual CI-mirrored `docs/wikijs-drafts` source) directly into this repo.

---

For outstanding/pending work, see the [Documentation backlog](/system/docbacklog).
