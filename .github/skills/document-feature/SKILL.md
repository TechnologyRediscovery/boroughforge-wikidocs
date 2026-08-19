---
name: document-feature
description: 'Standardized end-to-end flow for documenting a CodeNforce component or subsystem: write the wikidocs page(s) in boroughforge-wikidocs, register a stable-ID redirect in helpmap/_redirects, and wire the matching help icon (`<tt:helpLinkCC helpId="..."/>`) into the corresponding XHTML in the sibling codenforce repo. Use when asked to "document this feature/page/component", "add help docs for X", "write a wiki page and link it from the app", "add a help icon/link to this XHTML", or "implement the static-link howto for X". Implements dev/architecture/static-link-howto.md end-to-end (page + redirect + in-app icon) rather than just one piece of it.'
argument-hint: 'the component/subsystem to document (e.g. "occupancy permit files", a subsystem slug, or a path to the XHTML file(s))'
---

# Document a CodeNforce Feature (page + redirect + help icon)

Three-step flow, always done together for one component: **write the docs page(s)** (this
repo) → **register its stable ID** (`helpmap/_redirects`, this repo) → **wire the help icon**
into the component's XHTML (sibling `codenforce` repo). This is the practical, repeatable
version of [static-link-howto.md](../../../dev/architecture/static-link-howto.md) — read that
file if any step below is ambiguous, it's the source of truth for the redirect mechanics.

Assumes `codenforce` and `boroughforge-wikidocs` are sibling checkouts (the normal layout in
this workspace) — cross-repo links below use `../codenforce/...`-style relative paths the same
way the codenforce docs already link back into this repo.

**Git policy (both repos, all steps):** never run `git add`/`commit`/`push`/`fetch`/`pull`/
`merge` — the user handles all git and server administration personally. Read-only git
interrogation (`status`/`log`/`diff`/`show`) is fine. When file edits are done, just state
that they're ready to commit/push and stop there.

## Step 0 — Identify scope

1. Find the subsystem slug in [subsystem-registry.md](../../../system/subsystem-registry.md).
   Do not invent a new top-level folder or slug — if genuinely new, stop and add a registry row
   first (see that file's Conventions section), don't silently freelance one.
2. Find the XHTML file(s) in `codenforce` for this component (`grep_search` under
   `src/main/webapp/**` for the page name or a distinctive label/id). Note whether it's a full
   page or a `resources/components/*CC.xhtml` composite (both may need the icon — check for
   duplicates, a common gap historically, see SL.0/SL.4 in the documentation subsystem index).
3. Decide the page type/branch per the taxonomy in
   [docs-overhaul-aug26.md §5](../../../dev/architecture/docs-overhaul-aug26.md): concept/
   `overview.md`, task/click-by-click (verb-first filename), reference, or admin runbook.
   Branch is `users/`, `admin/`, `dev/`, or `public/` depending on audience — split into
   separate pages per audience rather than collapsible sections unless the feature is trivial.

## Step 1 — Write the wikidocs page(s)

Path: `<branch>/subsystems/<slug>/<page-slug>.md` (e.g. `users/subsystems/occupancy/scheduling-an-inspection.md`).

Frontmatter (match existing pages exactly, e.g.
[property-groups.md](../../../users/subsystems/property/property-groups.md)):

```yaml
---
title: <Title Case Name>
description: <one sentence, shows in search results>
published: true
date: <today, ISO8601>
tags: subsystem:<slug>, audience:<dev|admin|officer|staff|viewer|public>, type:<hub|overview|howto|reference|best-practice|architecture|runbook|faq>
editor: markdown
---
```

Body conventions:
- Numbered steps, **bold** for UI labels/buttons, `> **Tip:**` / `> **Officer authority
  required.**` callouts for role-gated steps (don't fork a whole page just for a gated button).
- Screenshots: sibling `img/` folder, flat until a page needs 3+ images then nest
  `img/<page-slug>/`. Relative links only (`img/file.png`), never absolute Wiki.js paths.
- **Always flag screenshot injection sites, even when no screenshot exists yet.** Every page
  written or revised by this skill gets an HTML comment at each spot a screenshot belongs,
  using this exact marker so it's greppable and invisible on the published page:
  `<!-- SCREENSHOT NEEDED: <one sentence describing exactly what the screenshot should
  capture> -->`. Do this on first write, not as a follow-up pass — don't wait for a real image
  to be available before marking where it goes. Once a real screenshot is added, replace the
  comment with the actual `![alt](img/file.png)` embed in the same spot.
- If a page not yet ready for publication, set `published: false` — it still gets a stub file
  and (per Step 2) a `# TODO` redirect line, never a live one.
- Cross-link the new page from its subsystem's `overview.md`/hub page. Never link to a page
  that doesn't exist yet — mention upcoming/GAP pages as plain text (e.g. "*(coming soon)*"),
  not as a markdown link, until the target file is actually created.
- **Cross-page links must always be absolute paths** (`/branch/subsystems/slug/page-slug`) —
  never a bare relative filename like `[text](other-page)`. Confirmed 2026-08-19: Wiki.js
  resolves a bare relative link against the *current page's own full path* (treating it as a
  directory), not against its containing folder — `[X](sibling-page)` written on
  `users/subsystems/letters/overview` renders as `.../letters/overview/sibling-page` (404)
  instead of `.../letters/sibling-page`. This silently broke an entire subsystem's
  Topics/See-also links even though every target file existed. Same-page `#anchor` links are
  unaffected (no routing involved). Always use the full absolute path for any link to a
  different page, full stop.

## Step 2 — Register the stable-ID redirect

Add one line to [helpmap/_redirects](../../../helpmap/_redirects). Full rules live in
[static-link-howto.md](../../../dev/architecture/static-link-howto.md); the essentials:

- **Stable ID naming — mechanical convention by default** (per
  [audit-users-coverage.sh](../../../helpmap/audit-users-coverage.sh)): `<slug>-<page-slug>`,
  dropping a duplicate prefix if the page slug already starts with the subsystem slug
  (`property/property-groups.md` → `property-groups`, not `property-property-groups`). Only
  use an older thematic-style ID if you're retargeting one of the pre-existing "original 12" /
  "9 newly discovered" IDs at the top of the file — don't invent new thematic names.
- **Published page:** live line — `stable-id   /branch/subsystems/slug/page-slug` (append
  `#anchor` in the target column if linking a section, not a separate field).
- **Not yet published:** `# TODO stable-id   (candidate page — not yet published)` — never
  guess a live target for an unpublished/unwritten page.
- Stable IDs are **permanent** once written — never rename or delete a line, only edit its
  target path.
- Deploy is automatic on push to `main` (GitHub Actions → docs VPS Nginx reload, no downtime).
  **Never run `git add`/`commit`/`push`/`fetch`/`pull`/`merge` yourself** — the user does all
  git and server administration personally. Once the file edits are ready, just say so
  ("`_redirects` updated, ready to commit/push") and stop; read-only git interrogation
  (`status`/`log`/`diff`/`show`) is fine if you need to check repo state.

## Step 3 — Wire the help icon into the XHTML (codenforce repo)

Use the composite component — never hardcode `docs.codenforce.org` in XHTML:

```xml
<tt:helpLinkCC helpId="stable-id" />
```

- **Verify the namespace alias first.** Check the file's own top-level `xmlns:` declarations
  for whichever prefix maps to `http://xmlns.jcp.org/jsf/composite/components` (usually `tt`,
  but not guaranteed — a copy-pasted wrong alias caused a real deploy-time
  `FaceletException: ... is not bound` bug, see codenforce `docs/worklog.md` 2026-08-16). Don't
  assume `tt:` without checking.
- Icon-only by design (ECD decision 2026-08-16, see
  [helpLinkCC.xhtml](../../../../codenforce/src/main/webapp/resources/components/helpLinkCC.xhtml)) —
  no visible text label, unlike every other link/button convention in this app.
- Placement: drop it as a standalone element alongside other action links/buttons in the same
  container (see existing usages — `grep_search` for `helpLinkCC` in `codenforce/src/main/webapp`
  for a placement example in a similar component), no extra wrapper div needed — the component
  supplies its own.
- **Where exactly, when there's both a full XHTML page and a `resources/components/*CC.xhtml`
  composite for the same feature:** default heuristic — if the feature has its own custom
  composite component (`*CC.xhtml`), the icon goes there; only if the feature isn't wrapped in
  its own CC does it go on the "root" XHTML page. Treat this as a default, not a rule — confirm
  placement with the user for each feature during the actual documentation pass, since the
  right spot depends on that feature's specific markup.

## Step 4 — Verify

- `mvn package -DskipTests` in `codenforce` (never pipe through grep/tail per that repo's
  build rule) — confirms the XHTML/namespace change compiles and deploys.
- After the redirect deploys: `curl -I https://docs.codenforce.org/help/<stable-id>` — expect
  `302` to the real page (or to the homepage if still `# TODO`).
- If this closes an item in a subsystem's feature index / dev-index, follow codenforce's
  always-on Progress Tracking and Dev↔Docs Definition of Done rules (already in that repo's
  `copilot-instructions.md` — not repeated here) rather than treating this skill as the full
  closure checklist.

## Checklist

- [ ] Slug matches a row in `subsystem-registry.md`
- [ ] Page frontmatter complete (title/description/published/date/tags/editor)
- [ ] Every screenshot spot has either a real `![alt](img/file.png)` embed or a
      `<!-- SCREENSHOT NEEDED: ... -->` marker — never left bare with no note
- [ ] Stable ID added to `_redirects` — live line only if page is `published: true`
- [ ] `<tt:helpLinkCC helpId="..."/>` added with the file's *actual* composite-component
      namespace alias verified, placed where confirmed with the user (CC vs. root page)
- [ ] No hardcoded `docs.codenforce.org/help/...` links left in XHTML
- [ ] `mvn package -DskipTests` clean; git add/commit/push left entirely to the user — skill
      only reports readiness

## References

- [static-link-howto.md](../../../dev/architecture/static-link-howto.md) — day-to-day redirect usage (this skill's core source)
- [static-link-redirect-architecture.md](../../../dev/wiki.js/static-link-redirect-architecture.md) — full design/rationale
- [docs-overhaul-aug26.md](../../../dev/architecture/docs-overhaul-aug26.md) — page taxonomy, tags, image conventions
- [subsystem-registry.md](../../../system/subsystem-registry.md) — canonical slugs
- [helpmap/_redirects](../../../helpmap/_redirects), [audit-users-coverage.sh](../../../helpmap/audit-users-coverage.sh)
- codenforce: `src/main/webapp/resources/components/helpLinkCC.xhtml`, `docs/subsystems/documentation/documentation-feature-index.md`
