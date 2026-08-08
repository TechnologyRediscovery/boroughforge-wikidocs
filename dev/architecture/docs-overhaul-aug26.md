# Documentation Site Overhaul — Directory Structure & Taxonomy Plan (Aug 2026)

## Status: APPROVED 2026-08-07 — see §9 for sign-off. Root cleanup done; canonical registry
finalized (23 subsystems + X-series); all 23 hub pages written. Remaining work is deliberately
deferred and non-blocking: the deeper `cecase` migration pilot (existing content/images), and
writing spoke pages as new features actually need them.

This plan answers the open organizational questions carried over in
[docbacklog.md](/system/docbacklog) ("Consolidate down to four main branches", "Build a
subsystem overview listing", "Develop a template + plan for organizing subsystem docs") and
supersedes that backlog entry with a concrete structure. See
[docs-flow-architecture.md](docs-flow-architecture.md) for how content *arrives* in this repo
(GitLab drafting → GitHub canonical → Wiki.js sync) — this document is about how content is
*organized* once it's here.

The canonical subsystem list now lives at
[system/subsystem-registry.md](/system/subsystem-registry) — that file, not the table in §2
below, is the source of truth going forward. §2 is kept for its rationale/history.

---

## 0. Current state (why this is urgent)

A quick inventory of the tracked repo today:

| Metric | Count |
|---|---|
| Total tracked files | 106 |
| Markdown pages (`.md`) | 45 |
| Legacy CKEditor pages (`.html`) | 22 |
| Images (`.png`/`.jpg`) | 37 |
| Misc (`.xhtml`, `.pdf`) | 2 |

67 pages already, with no subsystem registry, no page-type convention, and three different
top-level shapes competing (`users/<Basics|cecases|...>/`, `admin/<user|...>/`, plus a set of
root-level `cecases/`, `inspections/`, `permitting/`, `properties/` image folders). Concretely
broken things found during this review, **now resolved** (see §10):

- **A raw JSF source file was sitting in the repo root**: `occPermitApplicationUnitList.xhtml`
  — actual application code (`<h:body>`, `<p:panel>`, PrimeFaces tags), almost certainly an
  accidental copy-paste from the codenforce repo into the wrong clone. **Deleted 2026-08-07.**
- **Root-level image folders — correction after verification.** These were initially assumed
  to be fully orphaned. A grep of every filename against the whole repo showed that's only
  true for **2 of the 17 images**: `properties/propgroups.png` and
  `inspections/addspacebytype.png` had zero references anywhere and have been moved to a new
  `xarchive/` root folder (2026-08-07) — this repo's equivalent of the `xarchive/` convention
  already used in the codenforce Java repo for material nobody wants to spend time sorting.
  The remaining 15 images (all of `cecases/`, `permitting/`, and 3 of 4 in `inspections/`) are
  **actively referenced** by real pages using absolute Wiki.js paths, e.g.
  `![actiondate.png](/cecases/actiondate.png)` from `users/cecases/finetracking.md`. This is a
  real, live (if inconsistent-with-the-newer-convention) pattern — root-level absolute-path
  image folders alongside the newer per-page `img/` colocation convention seen in
  `users/cecases/img/` and `users/permitting/img/`. **Do not delete or bulk-move these** —
  fold each subsystem's root-level image folder into that subsystem's own `img/` folder (and
  update the referencing pages in the same commit) as part of that subsystem's migration pass
  in §10, not as a separate blind sweep.
- **Two competing editors**: 22 `.html` pages use the Wiki.js CKEditor format
  (`admin.html`, `home.html`, most of `users/**`), while newer content uses
  `editor: markdown`. `doclog.md` already documents converting `release_notes.xhtml` for
  this exact reason — the rest of the CKEditor pages need the same treatment.
- **Link rot from prior reorganizations**: `home.html` linked to `/users/hardware`, but the
  file actually lives at `users/basics/hardware.md`. **Fixed 2026-08-07** along with the
  casing rename below. `admin.html` still links to `/admin/user` (no `.html`/`.md` — relies
  on Wiki.js path resolution) alongside plain text "Muni config" with no link at all — left
  for the full link-check pass in §10.
- **Inconsistent casing**: `users/Basics/` was the only capitalized folder in the tree.
  **Renamed to `users/basics/` 2026-08-07** (`git mv`, history preserved).
- **Frontmatter `tags:` is empty on every page.** Wiki.js's tag-browse feature is completely
  unused — a free navigational axis is sitting idle (see §5).
- **The subsystem list itself was a hodgepodge**, split across two repos with no single
  canonical source. **Resolved 2026-08-07** — see `system/subsystem-registry.md`.

None of this is a criticism of past work — it's the natural result of a fast-moving one- or
two-person doc effort with no registry to check new folders against. The fix is structural,
not a one-time cleanup, or the mess reappears in six months at 10x the page count.

---

## 1. Reader domains (the audience model this plan is built around)

| Domain | Who | Wants |
|---|---|---|
| **Backend developers** | Contributors to the codenforce Java/JSF codebase | Architecture, schema, subsystem internals, build/deploy |
| **Municipal system admins** | Configure users, munis, data flows, payment processing, canned comments, cert types | Admin runbooks, config reference |
| **Code officers** | Logged-in end users who make case-state legal judgments | Task how-tos, authority-gated actions |
| **Municipal staff** | Logged-in end users, no legal judgment authority | Task how-tos (subset of officer's) |
| **Read-only / viewer users** | Logged-in, view case state only | Task how-tos (further subset) |
| **Public users** | Unauthenticated — submitting CEAR forms, permit applications, status lookups | Plain-language forms guidance, no internal workflow exposure |

The last three are grouped as **"logged-in end users"** for structural purposes (§3) because
they share the same screens and mostly differ by *authority level*, not by *content type* —
this distinction drives the recommendation below. Public users are pulled out entirely because
they differ by *security boundary*, not just authority: nothing behind the login should ever
leak into public-facing pages.

---

## 2. Building the canonical subsystem registry

The codenforce repo's `docs/subsystems/` is dev-facing engineering scratch space (feature
plans, implementation summaries, upgrade backlogs) — it is **not** end-user documentation and
was never meant to be a registry. But it's the best available census of what subsystems
actually exist, and it's more complete than the "official" list in codenforce's own
`.github/copilot-instructions.md`, which only names 11 subsystems
(`N_USER, I_MUNICIPALITY, II_CODEBOOK, III_PROPERTY, IV_PERSON, V_EVENT, VI_OCCPERIOD,
VII_CECASE, VIII_CEACTIONREQUEST, X_PAYMENT, XII_BLOB`). The `docs/subsystems/` folder on
disk has **23 directories**, including several with real content and no Roman-numeral home
(`XI`, `XIII`, `XIV` exist as folders but aren't in the instructions list at all; `permitting`,
`inspections`, `letters+emailing`, `data_exchange`, `evaluations`, `workflows` have no numeral
at all).

**Recommendation:** this docs repo — not the Java repo — becomes the source of truth for the
subsystem registry, since it's the one place all audiences meet. Publish it as
`system/subsystem-registry.md`, one row per subsystem, and treat it as the only place new
top-level subsystem slugs get approved. Once stable, propose a matching update to codenforce's
`copilot-instructions.md` so the two lists converge (a follow-up cross-repo task, not part of
this plan).

Proposed registry (slug is the folder name used everywhere in this repo):

| Slug | Java subsystem | Kind | Source dir in codenforce | Branches needing content |
|---|---|---|---|---|
| `accounts` | `N_USER` | domain | `n_user` | dev, admin, users(basics) |
| `municipality` | `I_MUNICIPALITY` | domain | `i_municipality` | dev, admin |
| `codebook` | `II_CODEBOOK` | domain | `ii_codebook` | dev, admin, users |
| `property` | `III_PROPERTY` | domain | `iii_property` | dev, users, public |
| `person` | `IV_PERSON` | domain | `iv_person` | dev, users |
| `event` | `V_EVENT` | domain | `v_event` | dev, users |
| `occupancy` | `VI_OCCPERIOD` | domain | `vi_occperiod` | dev, users |
| `cecase` | `VII_CECASE` | domain | `vii_cecase` | dev, users |
| `cear` | `VIII_CEACTIONREQUEST` | domain | `viii_ceactionreq` | dev, users, public |
| `letters` | *(unlisted — spans VII/VIII)* | domain | `letters+emailing` | dev, admin, users |
| `payment` | `X_PAYMENT` | domain | `x_payment` | dev, admin, users, public |
| `reporting` | *(unlisted)* | domain | `xi_report` | dev, users |
| `files` | `XII_BLOB` | domain | `xii_blob` | dev only (infra-ish) |
| `public-info` | *(unlisted)* | domain | `xiii_publicinfo` | dev, public |
| `mapping` | *(unlisted)* | domain | `xiv_spatial` | dev, admin, users |
| `permit-applications` | *(unlisted)* | domain | `viv_occapp_publicforms` | dev, admin, users, public |
| `permitting` | *(nested conceptually under occupancy, kept distinct)* | domain | `permitting` | dev, users, admin |
| `inspections` | *(spans occupancy + cecase)* | domain | `inspections` | dev, users |
| `data-exchange` | *(unlisted — WestMC integration)* | domain (admin-critical integration) | `data_exchange` | dev, **admin** |
| `evaluations` | *(unlisted)* | domain | `evaluations` | dev, users |
| `workflow-builder` | *(unlisted — Workflow Builder engine)* | domain (technical) | `workflows` | dev, admin |
| — | — | infra (not a subsystem) | `system` | dev only |
| — | — | cross-cutting UI concern | `system-general-xsubsystem` | dev only |

**Correction after review (§9):** `data-exchange` is *not* dev-only — it's one of the most
admin-critical pathways in the system (tens of thousands of lines of WestMoreland County
integration code, with complex admin config pages for reviewing, enabling, and monitoring
regular data exchanges). Only the two `system*` folders are genuinely **cross-cutting/infra**
deliberately excluded from `users/`/`admin/` — engineering concerns a code officer or muni
admin will never browse to by subsystem name. `data-exchange` gets full `admin/` treatment
like any other domain subsystem.

This is a starting registry, not a locked one — it will grow. The point is that *every* new
top-level folder in `dev/`, `admin/`, or `users/` must correspond to a row in this table before
it's created, so the "which folder does this go in" question always has one answer.

---

## 3. Question 1 — domain-first or subsystem-first at the top level?

### Option A — subsystem-first (`subsystems/cecase/dev/`, `subsystems/cecase/users/`, …)

All content about one subsystem lives together. Good for a subsystem deep-dive, bad for
audience isolation: a code officer landing in `subsystems/cecase/` is one wrong click away
from `subsystems/cecase/dev/` full of JDBC and coordinator notation — exactly the mixing the
prompt worried about. Access control and the QR/stable-ID public-portal boundary (see
[static-link-redirect-architecture.md](../wiki.js/static-link-redirect-architecture.md)) also
get harder to reason about, since "everything public users may see" is scattered across one
subfolder inside every subsystem rather than one clean subtree.

### Option B — domain-first (`dev/`, `admin/`, `users/`, `public/`), subsystem-second

Matches the direction already chosen in `docbacklog.md`. A code officer's entire world is
under `users/`; nothing dev-only or public-only can leak in by accident. Maps cleanly onto:

- The existing GitLab → `drafts/gitlab-generated/` pipeline, which produces **dev-facing**,
  code-aware drafts almost by definition — they land in `dev/` and nowhere else without a
  human rewrite.
- The stable-ID redirect layer already designed for in-app help and QR codes — each audience's
  IDs get a clean namespace prefix (`/help/officer-...`, `/help/dev-...`).
- Any future Wiki.js path-based access rules, and the hard requirement that public-portal
  content never contains internal workflow detail.

The cost is real: the subsystem taxonomy is now duplicated as a folder name across up to four
branches, which can drift. That's exactly what §2's registry exists to prevent, and what the
hub page in §4 exists to stitch back together.

### Recommendation: **Option B**, with one amendment to the existing backlog plan

Confirm the domain-first direction, but use **five** branches, not four — split `public/` out
of `users/` rather than nesting it underneath:

```text
dev/            backend developers
admin/          municipal system admins
users/          logged-in end users (officers, staff, viewers)
public/         unauthenticated public (CEAR forms, permit applications, status lookup)
system/         meta: doc-site governance itself (registry, changelog, releases, architecture)
```

`public/` earns its own top-level branch because its boundary is a *security* boundary, not
just an audience preference — it's the one branch where "did anything internal leak in" is a
real risk, and QR codes on physical decals make its base path effectively permanent. Nesting
it inside `users/` would blur that line for no organizational benefit, since public users
never log in and share none of the officer/staff/viewer screens.

Within `users/`, do **not** create three parallel `officers/` / `staff/` / `viewers/`
subsystem trees — see §4 for why, and how role differences are handled without tripling every
page.

---

## 4. Question 2 — structuring a feature that touches every audience

**Recommendation: hub-and-spoke, full page separation across branches, in-page tagging
within `users/`.**

### The hub

Every subsystem gets exactly one short **hub page**, living at
`system/subsystems/<slug>.md`, that is *not* documentation of the feature itself — it's a
one-paragraph plain-English description plus links out:

```markdown
# CE Case Management (`cecase`)

Tracks code enforcement cases from opening through closure, including case status,
priority, and linked properties/persons.

- Developers: [dev/subsystems/cecase/](../../dev/subsystems/cecase/overview.md)
- Code officers & staff: [users/cecase/](../../users/cecase/overview.md)
- Public: not applicable — cases are not directly public-facing (see `cear` for the public
  submission side of this workflow)
```

This solves the "whole story" problem Option B creates: anyone who wants the full picture of
a subsystem starts at one page and fans out, instead of guessing which branch to check first.

### The spokes

**Do not** put multiple audiences' content in one page with collapsible sections, except for
genuinely tiny features. Reasons:

1. **Search noise.** Wiki.js indexes and returns whole pages; an officer searching "close a
   case" shouldn't land mid-scroll next to coordinator/JDBC notes.
2. **Depth conflict.** A page trying to satisfy both a developer and a code officer either
   stays too shallow to be useful to the developer or gets too jargon-heavy for the officer —
   there's no register that serves both well.
3. **Future permissioning.** If Wiki.js path/group-based access rules are ever introduced,
   section-level gating inside one page isn't possible — full page separation is the only
   structure that supports it later without a rewrite.
4. **Ownership.** A developer updates the dev page after a code change; someone else updates
   the officer page after a workflow/training change. Shared pages force both edits through
   the same file.

So: **yes, three (or four) pages minimum** for any substantial feature — one dev page, one
admin page (if applicable), one users page, one public page (if applicable) — tied together
by the single hub page above. Keep the same slug across branches
(`dev/subsystems/cecase/overview.md`, `users/cecase/overview.md`) so the mapping is obvious
without needing the hub to explain it.

**Exception:** a feature small enough that the admin-config paragraph and the end-user-usage
paragraph are each a few sentences can stay as one page with labeled `##` sections. The moment
either section needs its own screenshots or a click-by-click sequence, split it out — that's
the trigger, not a page-count rule of thumb.

### The one place page-splitting is *not* the answer: officer vs. staff vs. viewer

These three differ by **authority**, not by content type — the screens are identical, the
click-by-click is identical, only *who is allowed to do the last step* differs. Splitting
`users/cecase/` into three near-duplicate subtrees would triple maintenance for ~80% identical
content. Instead:

- Baseline task/how-to pages live directly under `users/<slug>/`, written for whichever role is
  the common denominator (usually "staff", since officers and viewers are supersets/subsets
  of what staff can see).
- Where authority actually gates a step, add an inline callout at that step, not a whole
  separate page:

  ```markdown
  > **Officer authority required.** Finalizing a violation is a legal determination and is
  > only available to users with the Code Officer role.
  ```

- Only create a role-specific page when the divergence is a genuinely separate workflow, not
  just a gated button (e.g., an officer-only "batch close cases" tool with its own multi-step
  UI gets its own page under `users/cecase/`, cross-linked from the shared overview, rather
  than being wedged into the shared page as a giant conditional section).
- Use `tags:` (see §6) to mark `audience:officer`, `audience:staff`, `audience:viewer` on
  pages/sections so Wiki.js's tag-browse view can filter by role even though the folder
  structure doesn't fork.

---

## 5. Question 3 — page type taxonomy

Formalize distinct page *types*, each with a clear purpose and naming convention. A page's
type should be obvious from its tags and roughly from its filename pattern:

| Type | Purpose | Where it lives | Naming pattern |
|---|---|---|---|
| **Hub / index** | One-paragraph subsystem landing page, links out to every branch's spoke | `system/subsystems/<slug>.md`, plus one curated `index.md` per branch/subsystem-folder | `index.md` or `overview.md` |
| **Concept / overview** | "What can the letter subsystem do?" — prose, index-like, scope & capability description | Top of each `<branch>/<slug>/` folder | `overview.md` |
| **Task / click-by-click** | Screenshot-heavy, numbered steps, minimal prose, one task per page | `<branch>/<slug>/` | verb-first: `add-an-event.md`, `close-a-case.md` |
| **Reference** | Dense factual tables — field lists, status codes, canned-comment catalogs, cert types, permission matrices | `<branch>/<slug>/reference/` or `reference.md` if small | `reference.md` or `<topic>-reference.md` |
| **Best-practice** | Cross-subsystem business-process guidance ("running your monthly rental inspection cycle") | **Not** inside any one subsystem folder — see below | `<branch>/best-practices/<topic>.md` |
| **Architecture / ADR** | Design decisions with options considered and a verdict (like this file) | `dev/architecture/` | `<topic>-architecture.md` or `<topic>-<month><year>.md` |
| **Admin runbook** | Step-by-step operational task for muni admins (create a muni, configure a payment processor) | `admin/<slug>/` | verb-first, same as task pages |
| **Release notes / changelog** | Already established | `system/releases/` | (unchanged) |
| **FAQ / troubleshooting** | Common errors and fixes | One `faq.md` per subsystem folder, or a single running `<branch>/faq.md` if sparse | `faq.md` |

### Where best-practice / cross-subsystem pages live

These pages deliberately span multiple subsystems (a rental-inspection cycle touches
`property`, `occupancy`, `event`, and `cecase` all at once), so they must **not** be forced
into any single subsystem folder. Give them a dedicated sibling folder at the same level as
the subsystem folders:

```text
users/best-practices/monthly-rental-inspection-cycle.md
admin/best-practices/onboarding-a-new-municipality.md
```

**Naming collision avoided:** don't call this folder `workflows/`. That name is already
taken by the *Workflow Builder* — a specific technical subsystem/engine
(`docs/subsystems/workflows` in the codenforce repo, `workflow-builder` slug in the registry)
— and reusing it for "general business best practices" would immediately recreate the
hodgepodge this plan is trying to fix. **Decided 2026-08-07: `best-practices/`**, not
`playbooks/` — settled in §9.

Cross-link liberally: each relevant subsystem's `overview.md` should have a "See also" line
pointing at any best-practice page that touches it, since these are the one place a reader
won't find their way to by folder-browsing alone.

---

## 6. Tags as the second navigational axis

Domain-first folders (§3) necessarily suppress the subsystem-first view as a *folder*
structure. Recover it without duplicating files by actually using Wiki.js's `tags:`
frontmatter field, currently empty on every page in this repo. Adopt a three-facet tagging
contract, enforced by convention (and spot-checked during migration, not by tooling initially
— this is a two-person doc team, not a CI pipeline problem yet):

```yaml
tags: subsystem:cecase, audience:officer, type:howto
```

- `subsystem:<slug>` — must match a row in the §2 registry.
- `audience:<dev|admin|officer|staff|viewer|public>` — matches §1.
- `type:<hub|overview|howto|reference|best-practice|architecture|runbook|faq>` — matches §5.

This gives Wiki.js's built-in tag browser a working cross-cutting index ("show me every
`cecase` page regardless of audience", "show me every officer-only howto") without touching
the folder-based primary navigation at all.

---

## 7. Illustrative target tree

Not exhaustive — enough to show the pattern across a few subsystems plus the cross-cutting
folders:

```text
boroughforge-wikidocs/
  system/
    subsystem-registry.md
    subsystems/
      cecase.md              # hub page
      cear.md
      letters.md
      payment.md
      ...
    doclog.md
    docbacklog.md
    releases/
  dev/
    architecture/
      docs-flow-architecture.md
      docs-overhaul-aug26.md   # this file
      static-link-redirect-architecture.md
      qr-redirects-guide.md
    subsystems/
      cecase/
        overview.md
        reference.md
      cear/
        overview.md
      letters/
        overview.md
      payment/
        overview.md
    db/
    jsf/
    java/
  admin/
    subsystems/
      municipality/
        overview.md
        onboarding-a-municipality.md
      payment/
        overview.md
        configure-a-payment-processor.md
      accounts/
        overview.md
        creating-a-user.md
    best-practices/
      onboarding-a-new-municipality.md
  users/
    basics/
      user-login.md
      dashboard-overview.md
    subsystems/
      cecase/
        overview.md
        add-an-event.md
        close-a-case.md          # officer-authority callout inline
      property/
        overview.md
        add-a-property.md
      letters/
        overview.md
        managing-letter-types.md
    best-practices/
      monthly-rental-inspection-cycle.md
  public/
    subsystems/
      cear/
        overview.md
        submitting-a-cear.md
      permit-applications/
        overview.md
        applying-for-an-occupancy-permit.md
```

Note `dev/`, `admin/`, and `users/` all gain a `subsystems/` layer beneath them (rather than
subsystem folders sitting directly at the branch root) — this keeps each branch's root free
for the branch's own cross-cutting folders (`best-practices/`, `basics/`, `architecture/`,
`db/`, etc.) without those competing visually with the subsystem list in the sidebar.

---

## 8. Other cleanup considerations (Question 4)

- ~~Delete or relocate the stray XHTML file~~ **Done 2026-08-07** —
  `occPermitApplicationUnitList.xhtml` confirmed accidental and removed via `git rm`.
- **Fold the root-level image folders into per-subsystem `img/` folders during migration**
  (not as a standalone sweep). Corrected finding: only 2 of 17 images were truly unreferenced
  (`properties/propgroups.png`, `inspections/addspacebytype.png`) — both moved to `xarchive/`
  **2026-08-07**. The other 15 (`cecases/`, `permitting/`, 3 of 4 in `inspections/`) are live
  and referenced via absolute Wiki.js paths from real pages; move each subsystem's folder into
  that subsystem's `img/` and fix the referencing pages together, in that subsystem's own
  migration commit (the `cecase` pilot in §9 will do this for `cecases/` first).
- **Convert the remaining 22 CKEditor `.html` pages to markdown**, following the precedent
  already set for `release_notes.xhtml` → `releasenotes.md` in `doclog.md`. Do this
  page-by-page as each is migrated into the new structure, not as a separate blanket pass —
  otherwise it's a second full-repo churn on top of the directory migration.
- ~~Fix `users/Basics/` casing~~ **Done 2026-08-07** — renamed to `users/basics/` via `git mv`
  (history preserved), and the one inbound link from `home.html` (which also pointed at the
  wrong path, `/users/hardware`) fixed to `/users/basics/hardware` in the same pass.
- **Run a link-check pass** after migration. Given the repo's small size, a simple script
  that greps all `.md`/`.html` files for internal links and checks each target exists is
  sufficient — no need for a hosted link-checker service.
- **Reuse the stable-ID redirect layer from day one.** [static-link-redirect-architecture.md](../wiki.js/static-link-redirect-architecture.md)
  already solves "in-app help links must never break when pages move." Every new page that
  might reasonably be linked from an in-app help icon should get a stable ID registered in
  that system at creation time, not retrofitted later once XHTML files already hardcode a
  path.
- **The GitLab draft pipeline should feed `dev/subsystems/**` primarily.** Code-aware
  generated drafts are backend-flavored almost by construction; the promotion step (§ in
  `docs-flow-architecture.md`) should default to landing promoted content in the `dev/`
  branch, with admin/user/public pages written by a human afterward in plain language rather
  than by promoting the same generated draft verbatim into multiple branches.
- **Curate, don't auto-generate, each branch's root index page.** With hundreds of pages
  incoming, the `dev/index`, `admin/index`, `users/index`, `public/index` pages become the
  single most important pages in the whole site for discoverability — treat them as living
  documents that get a line added every time a new subsystem folder is created, not
  something regenerated from a script.
- **Registry gatekeeping is a review habit, not tooling — for now.** With a two-person doc
  team, the fix for "don't invent new top-level folders" is: check §2's registry before
  creating one, and add the row if it's genuinely new. Revisit automated enforcement
  (a pre-commit check or CI lint) only if/when more contributors start touching this repo.

---

## 9. Decisions (resolved 2026-08-07)

1. Confirm the five-branch model (`dev/ admin/ users/ public/ system/`) and the `playbooks/`
   naming (vs. `best-practices/`) in §5.

ECD Response 7-AUG-2026: Let's go with your proposed 5 branches, with the hub pages for each subsystem in /system. We'll call the broader guides best-practices, not playbooks. Playbooks is a sports term, and sports will destroy and rot one's soul down to the bone.

2. Confirm `accounts` as the slug for `N_USER` (chosen to avoid colliding with the `users/`
   branch name — "user" would otherwise mean two different things in the same sentence).

ECD Response 7-AUG-2026: Confirmed: accounts. When we create the canonical subsystem list, we'll migrate away from roman numerals which is excessively pedantic and a relic of my 2017 self.

3. Confirm the `permitting` / `occupancy` / `inspections` boundary — these three overlap
   conceptually in the source subsystem list and need one clear line drawn before folders are
   created, or they'll collide the same way the current repo's stray directories do.

ECD Response 7-AUG-2026: These three are distinct subsystems, although permitting might technically be thought of as a nested sub-sub system since all permitting occurs on the "occupancy" side of the system. They should remain separate because Permitting is such a distinct and critical function within CNF that shouldn't be muddled with all its related infrastructure on the Occ period side (as opposed to code enforcement, the violation of statues side). Inspections are also a major subsystem whose objects live in both occ and ce. 

4. Decide whether `data-exchange` (WestMC) needs any `admin/` content at all beyond
   `westmc-data-exchange.md` (already migrated per `doclog.md`), or whether it's dev-only from
   here forward.

ECD Response 7-AUG-2026: Absolutely data exchange needs admin--perhaps the most admin critical pathway of reviewing, enabling, and monitoring regular data exchanges with westmoreland county. it's tens of thousands of lines of code with complex admin config pages.

5. Decide migration order — recommend starting with the subsystem that has the most existing
   scattered content (`cecase`, per current `users/cecases/` + `docs/subsystems/vii_cecase/`
   scope) as the pilot, since it will surface every edge case this plan didn't anticipate
   before the pattern is copied to 20 more subsystems.

ECD Response 7-AUG-2026: Migration order can certainly start with ce cases. 


## 10. Immediate action items (carried into `docbacklog.md`)

- [x] Get sign-off on §3 (five branches) and §5 (`best-practices/` naming) — resolved §9.
- [x] Create `system/subsystem-registry.md` from the §2 table (arabic numerals, not Roman).
- [x] Delete `occPermitApplicationUnitList.xhtml`.
- [x] Clear the two confirmed-dangling images into `xarchive/`; correct the record on the
      other 15 root-level images, which are live and get folded into per-subsystem `img/`
      folders during each subsystem's own migration pass instead.
- [x] Fix `users/Basics/` → `users/basics/` casing and its one broken inbound link.
- [x] Write all 23 per-subsystem hub pages at `system/subsystems/<slug>.md` (one flat batch,
      2026-08-07) — gives every subsystem a stable landing point and spoke links *before*
      any branch content exists, so new feature work always has an obvious place to land.
      Spoke pages are created on demand (clicking a hub's link to a not-yet-created spoke is
      Wiki.js's own "create this page" flow) rather than pre-scaffolded as empty stubs.
- [ ] Pilot the *full* branch/subsystem/hub pattern on `cecase` (confirmed in §9) — i.e. the
      deeper migration pass: folding `cecases/*.png` into `users/subsystems/cecase/img/` and
      updating `finetracking.md` / `letters.md` in the same pass. This is explicitly
      **not** a blocker for documenting new features — it's the deferred cleanup of
      *existing* scattered content, tracked separately from the hub-page scaffolding above.
