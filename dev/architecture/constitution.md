---
title: CodeNforce system constitution
description: The load-bearing rules for how the two repos, the registry, the tracking organs, and the release machinery fit together
published: true
date: 2026-08-12T00:00:00.000Z
tags: architecture, governance, meta
editor: markdown
dateCreated: 2026-08-12T00:00:00.000Z
---

# CodeNforce System Constitution

> **What this is.** The small set of rarely-changing, load-bearing rules about *what the big
> pieces are and how they relate* — the two repos, the subsystem registry, the tracking organs,
> git/commit conventions, the DB-patch and release machinery, and the dev↔docs correlation
> policy. It is deliberately short and stable.
>
> **What this is not.** It is **not** a code-review checklist. Line-level "how do I write a
> correct Backing Bean / Coordinator / XHTML" rules live in the codenforce
> **[cnf-style-guide.md](https://github.com/)** (`docs/reference/cnf-style-guide.md`) and the
> `.github/copilot-instructions.md` quick-rules. When those and this document seem to overlap,
> this document governs *structure and invariants*; the style guide governs *code*.
>
> **The one meta-principle** everything below is an instance of: **single source of truth + link,
> never duplicate.** Each fact (a subsystem's canonical name, a feature's status, a page's
> published-ness, a schema patch number) has exactly one home; every other surface *links* to it.

---

## 1. The two repositories

| Repo | Role | Published? | Owns |
|---|---|---|---|
| **codenforce** | The Java/JSF engineering repo (Jakarta EE 9.1, PrimeFaces, WildFly, PostgreSQL) | No — `docs/` is editor-only | Source code; per-subsystem **dev indexes** + specs; the two tracking **organs**; DB patches |
| **boroughforge-wikidocs** | The Wiki.js documentation site, five branches: `dev/ admin/ users/ public/ system/` | Yes (per-page `published:` flag) | Canonical **registry**; all published user/admin/dev/public content; **release notes**; this constitution |

The asymmetry is intentional. codenforce `docs/` holds *volatile, not-yet-shipped, cross-repo
tracking state* that must never appear on the public docs site; wikidocs holds *canonical naming
and everything the audiences are allowed to see*. Because both repos are always checked out as
workspace siblings, codenforce editor-only files may use workspace-relative cross-repo links
freely; published wikidocs pages must not link into codenforce.

## 2. The subsystem registry — the join key

The canonical list of subsystems is the wikidocs
**[subsystem-registry](/system/subsystem-registry)**. It is the single source of truth for the
`slug ↔ number ↔ display name ↔ legacy Roman ID ↔ codenforce source dir` mapping, and it is the
**join key** that lets the two repos refer to the same subsystem unambiguously.

Invariants:

- **Arabic-numeral slugs** (`accounts`, `cecase`, `letters`, …) are the naming going forward.
  The 2017-era Roman IDs (`N_USER`, `VII_CECASE`) survive only as a cross-reference column.
- **X-series** (`X1 session`, `X4 db`, `X6 ui-mobile`, …) are dev-only infrastructure concerns —
  they get a `dev/` folder only, never `admin/`/`users/`/`public/`.
- **Birth of a subsystem:** add the registry row **first**, then create folders. No top-level
  subsystem folder exists in any branch (or in codenforce `docs/subsystems/`) without a
  registry row.
- **codenforce dir alignment is incremental.** The codenforce `docs/subsystems/` tree still uses
  legacy dirs (`vii_cecase`, `letters+emailing`); the registry's "CNF source dir" column is the
  crosswalk. Rename a dir to its slug only when that subsystem is *already being worked*
  (`git mv` + fix every inbound link in the same commit). New dirs use the slug from day one.
  See [docs-overhaul-aug26 §12.5](/dev/architecture/docs-overhaul-aug26).

## 3. The three tracking organs

The governance layer above the per-subsystem dev indexes. Full rationale:
[docs-overhaul-aug26 §12](/dev/architecture/docs-overhaul-aug26). Two organs live in codenforce
(editor-only); the third is a policy encoded in both repos.

| Organ | Home | Owns (SSOT for) |
|---|---|---|
| **1 — Worklog** | codenforce `docs/worklog.md` | reverse-chrono work steps + the git-branch ledger |
| **2 — Status dashboard** | codenforce `docs/subsystem-status.md` | per-subsystem *last-worked* date + one-phrase state + index links |
| **3 — Correlation policy** | codenforce `.github/copilot-instructions.md` + this §5/§6 | the implemented→published gate + Definition of Done |

- **Worklog** — one `##` heading per day, newest on top, bullets grouped by subsystem slug, the
  git branch noted on every line, docs-repo work tagged `[wikidocs]`. Append/extend the current
  day's entry **every turn**.
- **Dashboard** — one row per registry subsystem; bump the touched subsystem's *last-worked* date
  **every turn**. It *references* the registry (never redefines slugs) and *summarizes* each dev
  index in one phrase (never restates per-item state).
- Both are **never published**. The per-item authority remains each subsystem's dev index; the
  canonical-naming authority remains the registry.

## 4. Git & commit conventions

- **Branches are short-lived and task-named:** `<type>/<slug>-<itemID>-<kebab>`.
  - `type ∈ feat | fix | docs | chore | refactor` (Conventional-Commits vocabulary).
  - `slug` = registry slug (`xsub` short-slug for `system-general-xsubsystem`).
  - `itemID` = the dev index's stable item id where one exists (`III-H`, `FC-0`, `SL-2`).
  - Example: `feat/letters-III-H-compression`.
- **Commit subjects reference the item id** (`feat(letters): III.H parallelize compression`) so
  `git log --oneline | grep III.H` reconstructs one item's history across days.
- **The worklog records which branch each thread lived on.** Merge/delete a branch when its dev
  index item reaches `DONE`; the worklog line is the durable record after the branch is gone.

## 5. Database patches & releases

### 5.1 Schema patches

- New schema changes ship as `codeconnect/database/patches/dbpatch_betaN.sql` where **N = highest
  existing N + 1**. Numbers are **monotonic — never reused or skipped**. (Registry X-series `X4 db`
  owns the patch-workflow docs.)
- When a patch inserts a row whose ID the application must reference (a seeded role, an event
  category), record that ID as a new key in
  `src/main/webapp/WEB-INF/classes/dbFixedValueLookup.properties` **in the same PR** — the patch
  and the properties entry ship together. IDs are never hard-coded in Java (see style guide §4).

### 5.2 Release notes

- **Home:** the published, running page wikidocs
  **[system/releases/releasenotes.md](/system/releases/releasenotes)**, newest release on top,
  one `## Release X.Y.Z on <date>` section each. When it grows long, older sections move to
  **[releasenotes-archive.md](/system/releases/releasenotes-archive)**. This is a *running page*,
  not per-release pages.
- Release-note bullets are **user-facing**: they describe the shipped feature in the audience's
  language and may deep-link the published user/admin doc page for that feature. They are keyed by
  the customer-visible feature/grant label (e.g. `LSA7-H`), which is distinct from the internal
  dev-index item id (`VII-H`) — the worklog line is where the two correlate.
- A release is the natural batch point for the **Definition of Done** (§6): everything a release
  advertises must already be `published:true` in wikidocs.

## 6. The Dev↔Docs correlation policy

The codenforce dev index owns not-yet-shipped state; the published docs site only advertises
shipped features.

- **Only *implemented* features get *published* wikidocs pages.** A `PLANNING` / `LOCKED` /
  `IN-PROGRESS` dev-index item gets at most a `published:false` stub — never a live user/admin
  page. The public site never advertises vaporware as if it exists.
- **Exception — marked planned-references.** A published page for an *existing* feature MAY
  mention a planned one inline, clearly marked and never as its own page:

  ```markdown
  > 📅 **Planned — Fall 2026.** Linking a CE case directly to a permit file is on the roadmap;
  > today, use the property record as the bridge. (Tracked: cecase index item VII-x.)
  ```

  Tag such a page `status:has-planned-ref` so the note is greppable and can be closed the moment
  the feature ships.
- **Definition of Done** (fires when a dev-index item → `DONE`):
  1. Impl file linked in the subsystem's dev index.
  2. wikidocs page written + `published:true` (or a dated deferral noted in the worklog).
  3. `/help/{id}` stable id registered in `helpmap/_redirects` if the feature has an in-app help link.
  4. Any `📅 Planned` reference to the feature removed/replaced.
  5. Dashboard *Docs* column updated; worklog line written; release-notes bullet added when it ships.

## 7. Doc-type taxonomy

Published pages follow **Diátaxis** — tutorial / how-to / reference / explanation — as adopted in
[docs-overhaul-aug26 §5](/dev/architecture/docs-overhaul-aug26). Architecture decisions (like this
file and the `*-architecture.md` pages) are **ADRs**: dated, with the options weighed and the
verdict recorded.

---

## Amending this constitution

This document changes rarely and deliberately. An amendment is itself an ADR: date it, state what
changed and why, and update any organ or policy it touches in the same pass. When a rule here and a
rule elsewhere conflict, this document governs *structure/invariants* and the style guide governs
*code* — if that boundary itself is unclear, that ambiguity is the bug to fix here.
