---
title: Subsystem registry
description: The canonical list of CodeNforce's subsystems
published: true
date: 2026-07-21T21:20:00.000Z
tags: 
editor: markdown
dateCreated: 2026-07-21T21:20:00.000Z
---

# CodeNforce Subsystem Registry

This is the canonical list of subsystems for the `boroughforge-wikidocs` site. Every
top-level subsystem folder under `dev/`, `admin/`, `users/`, and `public/` must correspond to
a `slug` in this table — see
[dev/architecture/docs-overhaul-aug26.md](/dev/architecture/docs-overhaul-aug26) §2 for the
rationale, and §9 for the sign-off that established this file.

**Numbering:** plain arabic numbers, one flat sequence across all categories (categories are
just for readability, not separate number ranges). This replaces the old Roman-numeral
subsystem IDs (`N_USER`, `I_MUNICIPALITY`, `VIII_CEACTIONREQUEST`, etc.) used in the
codenforce Java repo — those were a 2017-era convention and are not carried forward here, and
this registry does not try to preserve their ordering. The `Legacy ID` column exists only to
help cross-reference old material during migration; it is not part of the naming going
forward.

**Branch convention:** there is no per-subsystem "which branches" column anymore. Every
subsystem in this table gets a subdirectory in `dev/`, `admin/`, and `users/` — full stop, even
if a given branch's folder starts out thin. Every subsystem is potentially relevant to every
logged-in audience (e.g. end users legitimately need to know about supported file types,
batch upload limits, naming/metadata rules for the `files` subsystem — that's not a dev-only
concern just because it sounds technical). Carving out per-subsystem branch exceptions invites
exactly the sloppy, inconsistent setup this registry exists to prevent. The **only** exception
is `public/`: a subsystem gets a `public/` folder **only if it's listed under "Public-facing
subsystems" below.** The X-series entries at the bottom are the other exception — they are
dev-only backend infrastructure concerns and never get `admin/`, `users/`, or `public/` folders.

**X-series (dev-only infrastructure):** some engineering concerns are real enough to deserve
their own dev-branch documentation but aren't customer-facing subsystems — no code officer or
muni admin ever browses to them by name. These get an `X` + sequence number instead of an
arabic number (`X1`, `X2`, ...) so they're never confused with the numbered list above and
never imply a claim on `admin/`/`users/`/`public/` folders. `X` was picked because this
codebase already uses it to mean "cross-cutting" (`xmuni`, `xarchive`,
`system-general-xsubsystem`) — not because it's a separate numeric register or a countdown
from `Z`. Graduation is cheap and one-directional: if an X-series concern grows a real
admin-facing UI (e.g. a session-configuration screen), delete its row here and add it to the
numbered list above with a fresh arabic number — the two sequences never renumber each other.

Adding a new subsystem: add a row here first, then create the folders. Don't create a new
top-level subsystem folder in any branch without a corresponding row.

## Core entities

| # | Slug | Display name | Legacy ID | CNF source dir |
|---|---|---|---|---|
| 1 | `accounts` | User Accounts | `N_USER` | `n_user` |
| 2 | `municipality` | Municipality Configuration | `I_MUNICIPALITY` | `i_municipality` |
| 3 | `codebook` | Codebook (Ordinances) | `II_CODEBOOK` | `ii_codebook` |
| 4 | `property` | Property | `III_PROPERTY` | `iii_property` |
| 5 | `person` | Person | `IV_PERSON` | `iv_person` |
| 6 | `event` | Events / Calendar | `V_EVENT` | `v_event` |

## Occupancy & code enforcement workflow

| # | Slug | Display name | Legacy ID | CNF source dir | Notes |
|---|---|---|---|---|---|
| 7 | `occupancy` | Occupancy Periods | `VI_OCCPERIOD` | `vi_occperiod` | Occ periods = permit files in the UI; contain statuses, have a manager and type. |
| 8 | `permitting` | Permitting | *(none)* | `permitting` | Distinct subsystem — permit files live on the occupancy side of CNF (as opposed to the code-enforcement/violation side), but permitting is significant and critical enough to stand on its own rather than being folded into `occupancy`. |
| 9 | `inspections` | Inspections | *(none)* | `inspections` | Objects span both `occupancy` and `cecase` — inspections are not exclusive to either. Kept as its own subsystem rather than being split or nested under one parent. |
| 10 | `cecase` | Code Enforcement Cases | `VII_CECASE` | `vii_cecase` | |
| 11 | `evaluations` | Evaluations | *(none)* | `evaluations` | |

## Supporting subsystems

| # | Slug | Display name | Legacy ID | CNF source dir | Notes |
|---|---|---|---|---|---|
| 12 | `letters` | Letters & Emailing | *(none — spans cecase/cear)* | `letters+emailing` | Letter content authoring, templates, addressee/signer logic. See `communication` below for the transport layer. |
| 13 | `payment` | Payment Processing | `X_PAYMENT` | `x_payment` | |
| 14 | `reporting` | Reporting | *(none)* | `xi_report` | |
| 15 | `files` | File / Blob Storage | `XII_BLOB` | `xii_blob` | |
| 16 | `mapping` | Spatial / GIS Mapping | *(none)* | `xiv_spatial` | |
| 17 | `communication` | Communication | *(none)* | *(none)* | Emailing infrastructure plus planned SMS support. Overlaps in name with `letters` (which owns letter *content/template authoring*) — `communication` is meant as the delivery/transport layer. Flag for a future pass on whether these two should merge once both have real content. |
| 18 | `workflow-builder` | Workflow Builder | *(none)* | `workflows` | The Workflow Builder *engine/feature* itself — do not confuse with cross-subsystem business-process guides, which live under each branch's `best-practices/` folder instead (see overhaul plan §5). |
| 19 | `search` | Search | *(none)* | *(none)* | Cross-subsystem search infrastructure (`SearchParams`, `QueryEnum`, per-entity search UI). Touches nearly every domain subsystem's data model. |

## Public-facing subsystems

| # | Slug | Display name | Legacy ID | CNF source dir | Notes |
|---|---|---|---|---|---|
| 20 | `cear` | Code Enforcement Action Requests (CEAR) | `VIII_CEACTIONREQUEST` | `viii_ceactionreq` | Covers CEAR creation/review for logged-in users as well as the public submission portal and public status-lookup page. Absorbs the former separate `public-info` slug: CNF has no generalized public-info lookup beyond CEAR status, so a standalone "public info" subsystem was redundant. |
| 21 | `public-applications` | Public Applications | *(none)* | `viv_occapp_publicforms` | Renamed from `permit-applications`. Covers all public-facing application intake: rental registration applications, permit applications, inspection requests, and zoning applications. |
| 24 | `documentation` | Documentation & Help Systems | *(none)* | *(spans repos — see Notes)* | The Wiki.js docs site itself (fully public, no login wall) plus the static-link redirect layer: in-app `/help/{id}` links (serving dev/admin/users audiences) and the QR-code `/report` redirect for citizens scanning vehicle decals. Placed here rather than the X-series because real citizens hit it directly — unlike the X-series' "no code officer or muni admin ever browses to this by name" test. **Numbered #24** (the next available flat number) rather than backfilled to #23, which `import-export` already holds — this registry's numbering is append-only and existing rows are never renumbered. Home docs today: `dev/architecture/` (this registry, `docs-overhaul-aug26`, `constitution.md`) and `dev/wiki.js/` (`static-link-redirect-architecture.md`); the codenforce-side counterparts are the editor-only `docs/worklog.md` + `docs/subsystem-status.md` organs, plus a dedicated per-subsystem dev index created 2026-08-14 at `docs/subsystems/documentation/` (`documentation-feature-index.md` + the `SL-1-nginx-tls-vps.md` runbook), split out of the former joint `system-general-xsubsystem/xsubsystem-feature-index.md` now that this subsystem outgrew sharing a folder with the unrelated `FC`/`ui-mobile` callouts work. No dedicated wikidocs-side `documentation/` branch folder exists yet — create one only if/when it outgrows `dev/architecture/`+`dev/wiki.js/`, per the registry's own incremental-creation discipline. |

## Integration & platform

| # | Slug | Display name | Legacy ID | CNF source dir | Notes |
|---|---|---|---|---|---|
| 22 | `data-exchange` | Data Exchange (WestMoreland County) | *(none)* | `data_exchange` | Tens of thousands of lines of integration code and complex admin config pages for reviewing, enabling, and monitoring regular data exchanges with Westmoreland County. One of the most admin-critical pathways in the system. |
| 23 | `import-export` | Import / Export | *(none)* | *(none)* | General-purpose bulk data import/export tooling — distinct from `data-exchange`, which is the Westmoreland-County-specific integration pathway. |

## X-series: dev-only infrastructure subsystems

These are engineering concerns, not subsystems a code officer or muni admin would ever browse
to by name. They live in `dev/` only and never get a `users/`, `admin/`, or `public/` folder —
the one deliberate exception to the branch convention above. See the X-series explanation
above for the naming rationale and graduation path.

| X# | Slug | Display name | CNF source dir | Notes |
|---|---|---|---|---|
| X1 | `session` | Session State & Sync | `session` | `SessionBean` plus the `Session*Conductor` fleet (CECase, Event, Inspection, Muni, Payment, Person, Property, User, Code), the `navigateToPageCorrespondingToObject` cross-object sync router, and cross-muni view mode. Graduates out of the X-series the moment a real session-configuration admin UI exists. |
| X2 | `caching` | Caching | *(tbd)* | Flagged as a known upcoming concern; no dedicated source dir identified yet. |
| X3 | `security` | Security | *(tbd)* | Backend auth/session-security enforcement — distinct from the admin-configurable permission *profiles* documented under `municipality`. |
| X4 | `db` | Database & Patching | `database/patches` | Schema conventions and the `dbpatch_betaN.sql` patch workflow. |
| X5 | `server-architecture` | Server Architecture | `system` | WildFly/Undertow deployment topology, logging, streams. Split out of the former generic `system` bucket. |
| X6 | `ui-mobile` | Cross-cutting UI / Mobile-Responsiveness | `system-general-xsubsystem` | Formerly listed as an unnumbered cross-cutting entry; folded into the X-series for consistency. |

---

## Follow-up (out of scope for this docs repo)

Once this registry is stable, propose a matching update to the codenforce Java repo's
`.github/copilot-instructions.md` subsystem list so the two repos converge on the same names —
tracked as a separate cross-repo task, not part of this docs reorganization.
