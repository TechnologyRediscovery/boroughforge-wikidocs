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

## 2026-07-21

- **21:20h** — Flagged `system/releases/release_notes.xhtml` as redundant now that its content lives in `releasenotes.md` / `releasenotes-archive.md`; queued for manual deletion.
- **21:20h** — Converted `system/releases/release_notes.xhtml` (PrimeFaces accordion, ~171 tabs) into markdown: `releasenotes.md` now holds only the current release (4.8.8), and `releasenotes-archive.md` holds the full historical archive (170 releases).
- **21:20h** — Manually deleted stale draft files/folders (migrated `drafts/gitlabrepo/` content and the disconnected `docs/userfacing` mirror artifact) after their content was relocated into this repo.
- **21:20h** — Created `users/workflows.md` (Workflow Builder Essentials guide), migrated from `drafts/gitlabrepo/lsa7-workflowimpl/workflow-builder-essentials.md`.
- **21:20h** — Created `admin/westmc-data-exchange.md` (WestMC Data Exchange System Administrator Operations Guide), migrated from `codenforce/docs/userfacing/westmc-data-exchange-admin-guide.md`.
- **21:20h** — Reviewed `docs-flow-architecture.md` and the GitLab CI `mirror_wikijs_drafts_to_github` job; decided to leave the CI mirror pipeline as-is, and to migrate content out of `docs/userfacing` (a disconnected folder, not the actual CI-mirrored `docs/wikijs-drafts` source) directly into this repo.

---

For outstanding/pending work, see the [Documentation backlog](/system/docbacklog).
