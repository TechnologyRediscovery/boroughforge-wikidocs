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

## 2026-08-16

- **Refactored [subsystem-registry.md](/system/subsystem-registry):** the four big
  explanatory blocks that used to sit at the top of the page (Numbering, Branch convention,
  X-series naming/graduation, Adding a new subsystem) were moved into a new **Conventions**
  section below all the subsystem tables, so the page opens with tables instead of a wall of
  prose. Every row across the Core/Occupancy/Supporting/Public-facing/Integration tables now
  links its slug straight to that subsystem's hub page under `system/subsystems/` (the
  X-series rows are left unlinked — their `dev/subsystems/<slug>/overview.md` stubs are still
  `published: false`, so there's no live page to point at yet).
- **Migrated the `documentation` (#24) row's notes out of the registry table** into this
  changelog and a new hub page, [system/subsystems/documentation.md](/system/subsystems/documentation)
  (the registry didn't have one before — it's the only numbered subsystem missing its hub
  page until now). The full text that used to live in the registry's Notes cell, preserved
  here for the record:

  > The Wiki.js docs site itself (fully public, no login wall) plus the static-link redirect
  > layer: in-app `/help/{id}` links (serving dev/admin/users audiences) and the QR-code
  > `/report` redirect for citizens scanning vehicle decals. Placed under Public-facing
  > subsystems rather than the X-series because real citizens hit it directly — unlike the
  > X-series' "no code officer or muni admin ever browses to this by name" test. Numbered
  > **#24** (the next available flat number) rather than backfilled to #23, which
  > `import-export` already holds — this registry's numbering is append-only and existing
  > rows are never renumbered. Home docs: `dev/architecture/` (this registry,
  > `docs-overhaul-aug26`, `constitution.md`) and `dev/wiki.js/`
  > (`static-link-redirect-architecture.md`, `wikijs-vps-reference.md`); the codenforce-side
  > counterparts are the editor-only `docs/worklog.md` + `docs/subsystem-status.md` organs,
  > plus a dedicated per-subsystem dev index at `docs/subsystems/documentation/`
  > (`documentation-feature-index.md` + the `SL-1-nginx-tls-vps.md` runbook), split out of the
  > former joint `system-general-xsubsystem/xsubsystem-feature-index.md` once this subsystem
  > outgrew sharing a folder with the unrelated `FC`/`ui-mobile` callouts work. No dedicated
  > wikidocs-side `documentation/` branch folder exists — it never outgrew `dev/architecture/`
  > + `dev/wiki.js/`, so per the registry's own incremental-creation discipline none was
  > created.

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
- Revised the registry per a second round of tweaks: collapsed `public-info` into `cear`
  (moved to Public-facing), renamed `permit-applications` → `public-applications` (now
  covers rental/permit/inspection/zoning intake), added `communication` and `search`,
  moved `workflow-builder` into Supporting subsystems, added `import-export` to
  Integration & Platform, and dropped the per-row `Branches` column in favor of one
  explanatory paragraph (every subsystem gets `dev/`/`admin/`/`users/`; only
  Public-facing subsystems also get `public/`). Renumbered everything into one flat
  23-item arabic sequence.
- Added an **X-series** convention for dev-only backend infrastructure concerns that
  aren't customer-facing subsystems (`X1 session`, `X2 caching`, `X3 security`, `X4 db`,
  `X5 server-architecture`, `X6 ui-mobile`) — folds in the two previously-unnumbered
  cross-cutting rows and adds `session` (`SessionBean` + the `Session*Conductor` fleet +
  the `navigateToPageCorrespondingToObject` sync router), `caching`, and `security`.
  X-series entries graduate to the numbered list if they ever grow real admin-facing UI.
- Wrote all 23 per-subsystem **hub pages** at `system/subsystems/<slug>.md`, each linking
  out to its `dev/`/`admin/`/`users/`(`/public/`) spoke pages.
- **Corrected course same day:** since the Wiki.js browser editor is never used for normal
  editing (all content is authored via git), spoke pages can't be "created on demand" through
  a Wiki.js prompt as first proposed — scaffolded all **77 spoke stub pages** instead
  (`dev/subsystems/<slug>/overview.md`, `admin/...`, `users/...`, `public/...` for the 2
  public-facing subsystems, plus 6 dev-only X-series stubs), each `published: false` and
  marked `🚧 Stub`. `data-exchange`'s admin stub points at the already-migrated
  `admin/westmc-data-exchange.md` instead of duplicating it. Documented the image-resource
  convention (`img/` colocated per subsystem folder, relative links, nest `img/<page-slug>/`
  past 3 images) as overhaul plan §8a.

## 2026-07-21

- **21:20h** — Flagged `system/releases/release_notes.xhtml` as redundant now that its content lives in `releasenotes.md` / `releasenotes-archive.md`; queued for manual deletion.
- **21:20h** — Converted `system/releases/release_notes.xhtml` (PrimeFaces accordion, ~171 tabs) into markdown: `releasenotes.md` now holds only the current release (4.8.8), and `releasenotes-archive.md` holds the full historical archive (170 releases).
- **21:20h** — Manually deleted stale draft files/folders (migrated `drafts/gitlabrepo/` content and the disconnected `docs/userfacing` mirror artifact) after their content was relocated into this repo.
- **21:20h** — Created `users/workflows.md` (Workflow Builder Essentials guide), migrated from `drafts/gitlabrepo/lsa7-workflowimpl/workflow-builder-essentials.md`.
- **21:20h** — Created `admin/westmc-data-exchange.md` (WestMC Data Exchange System Administrator Operations Guide), migrated from `codenforce/docs/userfacing/westmc-data-exchange-admin-guide.md`.
- **21:20h** — Reviewed `docs-flow-architecture.md` and the GitLab CI `mirror_wikijs_drafts_to_github` job; decided to leave the CI mirror pipeline as-is, and to migrate content out of `docs/userfacing` (a disconnected folder, not the actual CI-mirrored `docs/wikijs-drafts` source) directly into this repo.

---

For outstanding/pending work, see the [Documentation backlog](/system/docbacklog).
