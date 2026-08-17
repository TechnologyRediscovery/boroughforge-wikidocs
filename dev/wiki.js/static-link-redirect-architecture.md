# Static Link Redirect Architecture

This document covers two distinct redirect use cases that share the same core principle:
stable URLs baked into either compiled code or physical materials must never need to change,
even as the underlying destination changes over time.

- **Part 1 — In-app help links**: stable IDs embedded in JSF/Facelets XHTML pages pointing to
  the BoroughForge Wiki.js documentation site.
- **Part 2 — QR code redirects**: stable URLs printed on physical materials (magnetized car
  decals) pointing to the public CEAR submission portal.

---

# Part 1: In-App Help Links — Stable-ID Redirect Layer

## Problem Statement

codeNforce JSF/Facelets pages embed contextual help links pointing users to the BoroughForge
documentation site. As of mid-2026, existing help links are hardcoded directly to
`https://technologyrediscovery.github.io/codenforce/` — a GitHub Pages site being superseded
by a Wiki.js instance on a dedicated DigitalOcean VPS.

> **SL.0 re-inventory (2026-08-14).** This document originally estimated the migration scope at
> 21 links across 13 files resolving to 12 unique targets. A full repo-wide re-scan ahead of
> starting the SL build found the real footprint is **56 link occurrences across 29 XHTML files,
> resolving to 21 unique stable-ID targets**. The undercount came from the original walk covering
> only full restricted pages — it missed the `resources/components/*CC.xhtml` composite-component
> duplicates that mirror several of those pages elsewhere (e.g. `propCasesCC.xhtml` alongside
> `propCases.xhtml`, `eventListPanelCC.xhtml` alongside `eventListPanel.xhtml`). The corrected
> tables below (§Initial ID Table, §Files to modify) reflect the real scope; the build (SL.1–SL.5)
> proceeds from these corrected numbers.

The naive replacement — swap one hardcoded base URL for another — reproduces the same structural
fragility:

> Any Wiki.js page rename, path restructure, or anchor change requires editing XHTML files,
> recompiling the Maven project, and redeploying the WAR to WildFly.

For a complex open-source project that may carry hundreds of help links across dozens of
subsystems, coupling documentation URLs to compiled application code is not acceptable.

This document defines the architecture for a **stable-ID redirect layer** that permanently
decouples application code from documentation paths.

---

## Requirements

1. A help URL embedded in XHTML must never change, even when Wiki.js pages are renamed or reorganised.
2. Changing where a help link points must require no WAR recompile and no application server restart.
3. The mapping between stable IDs and real wiki paths must be version-controlled in Git alongside the documentation source.
4. The mapping must be editable by documentation editors who do not work in Java.
5. The solution must scale cheaply to hundreds of links without per-link infrastructure work.
6. The approach must fit the existing docs workflow: GitHub `boroughforge-wikidocs` is canonical source; CI deploys changes.

---

## Approach Evaluation

### Option A — Hardcode wiki.js URLs directly in XHTML (status quo)

XHTML files contain `https://docs.codenforce.org/users/cecases/add-an-event`.

| Criterion | Assessment |
|---|---|
| WAR redeploy on path change | **Yes** — every rename requires a recompile |
| Version-controlled | Yes (embedded in source code) |
| Editable by non-Java developers | **No** |
| Scales | **Poor** — hundreds of files to audit on each wiki restructure |

**Verdict: rejected.** This is the status quo problem being solved.

---

### Option B — Wiki.js built-in page aliases / redirects

Wiki.js supports creating redirect pages or setting URL aliases in the page editor.

| Criterion | Assessment |
|---|---|
| WAR redeploy on path change | No |
| Version-controlled | **No** — managed inside the Wiki.js database |
| Editable by non-Java developers | Partially (requires Wiki.js browser UI) |
| Scales | **Poor** — managing 200+ redirect pages in a browser UI is operationally fragile |

**Verdict: rejected.** The docs workflow explicitly discourages using the Wiki.js browser editor
for normal work. Hundreds of redirect pages in the database are not auditable or reviewable as
diffs.

---

### Option C — Standalone redirect microservice (Node.js / Python)

A small HTTP service reads a JSON or YAML map and issues HTTP 302 responses.

| Criterion | Assessment |
|---|---|
| WAR redeploy on path change | No |
| Version-controlled | Yes |
| Editable by non-Java developers | Yes |
| Scales | Excellent |
| Operational overhead | **High** — another process to deploy, monitor, restart, and secure |

**Verdict: acceptable fallback**, but adds a failure mode for a problem a plain web server
already solves natively.

---

### Option D — Nginx `/help/` prefix with Git-managed redirect map ✓ Recommended

Nginx is added to the docs VPS as a TLS-terminating reverse proxy in front of the Wiki.js Docker
container (standard production practice). A separate `location` block handles the `/help/` prefix
and issues 302 redirects.

The redirect map lives as a plain text file in the `boroughforge-wikidocs` GitHub repository. A
GitHub Actions workflow deploys it to the VPS on every push, regenerates the Nginx include file,
and reloads Nginx — a zero-downtime operation completing in under two seconds.

| Criterion | Assessment |
|---|---|
| WAR redeploy on path change | **No** |
| Version-controlled | **Yes** — flat file in boroughforge-wikidocs repo |
| Editable by non-Java developers | **Yes** — plain text, one line per entry |
| Scales | **Excellent** — Nginx handles millions of redirects trivially |
| Operational overhead | Low — Nginx is the right tool to put in front of Wiki.js anyway |
| Diff/review friendly | Yes — Git history shows every link change with date and author |

**Verdict: recommended.**

---

## Architecture Overview

```
[XHTML help link]
  └─ https://docs.codenforce.org/help/cecase-events-add
        │
        ▼
[Nginx on docs VPS]
  ├─ /help/* → reads helplinks.conf (auto-generated) → HTTP 302 to real wiki path
  └─ /* → reverse proxy → Wiki.js Docker container (port 3000)
        │
        ▼
[Wiki.js page]
  /users/cecases/add-an-event
```

The XHTML file only ever knows the stable ID. The Nginx config on the VPS is the single source of
truth for what that ID currently resolves to.

---

## The Stable ID Namespace

Stable IDs live under `/help/` and follow a `{subsystem}-{feature-area}` slug convention.
They are chosen once and **never changed** — they are the permanent contract between the
application and the docs system.

### Naming rules

- All lowercase, hyphens only — no underscores, no dots
- Subsystem prefix mirrors codeNforce subsystem names: `cecase`, `occ`, `property`, `person`,
  `code`, `event`, `payment`, `user`, `muni`
- Feature area is a short descriptive phrase: `events-add`, `priority-colors`, `persons-link`
- Anchors within a page are captured in the stable ID name conceptually, but the Nginx target
  handles the actual anchor: the ID `cecase-events-add` points to the full URL including `#add`
  in `helpmap/_redirects`

### Initial ID table — full re-inventoried scope (56 link occurrences, 29 files, 21 unique targets)

Corrected 2026-08-14 (SL.0). `Occ.` = total link occurrences resolving to this ID; `Files` =
distinct XHTML files containing at least one occurrence. The first 12 rows are the original
design's IDs (unchanged); the following 9 rows are newly discovered by the re-inventory.

| Stable ID | Legacy GitHub Pages path | Occ. | Files | Target wiki.js path |
|---|---|---|---|---|
| `cecase-cross-muni` | `/case/crossmuni.html` | 3 | 2 | *(assign when wiki page published)* |
| `dashboard-case-priority` | `/dashboard/dashboard#case-priority-color-scheme` | 9 | 8 | *(assign when wiki page published)* |
| `dashboard-case-search` | `/dashboard/dashboard#case-search` | 2 | 1 | *(assign when wiki page published)* |
| `inspections-fins` | `/inspections/fins.html` | 2 | 1 | *(assign when wiki page published)* |
| `code-enter-ordinance` | `/code/fullcodemodule#enter-an-ordinance-into-codenforce` | 2 | 1 | *(assign when wiki page published)* |
| `code-add-to-codebook` | `/code/fullcodemodule#add-an-ordinance-to-a-code-book` | 2 | 1 | *(assign when wiki page published)* |
| `code-create-checklist` | `/code/fullcodemodule#create-a-checklist` | 1 | 1 | *(assign when wiki page published)* |
| `cecase-events-add` | `/case/casescreen#log-an-event` | 4 | 2 | *(assign when wiki page published)* |
| `property-persons-link` | `/property/personslinking#link-a-person-to-a-property-or-case` | 6 | 4 | *(assign when wiki page published)* |
| `cecase-cears-internal` | `/public/cears.html#internal-cear-management-tools` | 3 | 3 | *(assign when wiki page published)* |
| `occ-permit-files` | `/occ/User_documentation_ACT#permit-files` | 2 | 1 | *(assign when wiki page published)* |
| `occ-permit-generate` | `/occ/User_documentation_ACT#generate-an-occupancy-permit` | 2 | 1 | *(assign when wiki page published)* |
| `property-mark-abandoned` *(new)* | `/property/personslinking#mark-a-property-as-abandoned` | 2 | 1 | *(assign when wiki page published)* |
| `cecase-upload-files` *(new)* | `/case/casescreen#upload-files-and-photos` | 4 | 2 | *(assign when wiki page published)* |
| `cecase-add-violation` *(new)* | `/case/casescreen#add-a-violation` | 2 | 1 | *(assign when wiki page published)* |
| `cecase-nov-add-address` *(new)* | `/case/casescreen#link-a-new-address-when-creating-an-nov` | 2 | 1 | *(assign when wiki page published)* |
| `cecase-nov-prepare` *(new)* | `/case/casescreen#prepare-a-notice-of-violation` | 1 | 1 | *(assign when wiki page published)* |
| `cecase-nov-add-person` *(new)* | `/case/casescreen#add-a-new-person-when-creating-an-nov` | 2 | 1 | *(assign when wiki page published)* |
| `property-link-mailing-address` *(new)* | `/property/personslinking#link-a-person-to-a-mailing-address` | 1 | 1 | *(assign when wiki page published)* |
| `property-link-multiple-people` *(new)* | `/property/personslinking#link-multiple-people-to-a-property-or-case-at-once` | 2 | 1 | *(assign when wiki page published)* |
| `cecase-management-overview` *(new)* | `/case/casescreen#code-enforcement-case-management` | 2 | 1 | *(assign when wiki page published)* |

**Totals: 56 occurrences, 21 unique IDs.** (Per-file totals sum to 29 distinct files — see
§Files to modify for the file-by-file breakdown.)

---

## Infrastructure: Nginx on the Docs VPS

The docs VPS currently has no Nginx — Wiki.js Docker is exposed directly on a port. Nginx is
installed in front to handle TLS termination, serve the `/help/` redirect prefix, and proxy all
other traffic to Wiki.js.

### Nginx site config structure

Two blocks in the main server config:

```nginx
server {
    listen 443 ssl;
    server_name docs.codenforce.org;

    # TLS — managed by certbot
    ssl_certificate     /etc/letsencrypt/live/docs.codenforce.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/docs.codenforce.org/privkey.pem;

    # Block 1 — stable-ID redirects
    # Individual location lines are in a generated include file
    # NOTE: must be snippets/, not conf.d/ — conf.d/*.conf is auto-included at the http{}
    # context on Debian/Ubuntu, where bare `location` directives are illegal.
    include /etc/nginx/snippets/helplinks.conf;

    # Fallback for unknown /help/ IDs
    location /help/ {
        return 302 https://docs.codenforce.org/;
    }

    # Block 2 — proxy to Wiki.js
    location / {
        proxy_pass         http://localhost:3000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name docs.codenforce.org;
    return 301 https://$host$request_uri;
}
```

### Let's Encrypt / Certbot

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d docs.codenforce.org
```

Certbot installs a cron job for auto-renewal.

---

## The Redirect Map File

**Location in boroughforge-wikidocs repo**: `helpmap/_redirects`

Format — one entry per line, two columns, whitespace-separated. Lines beginning with `#`
are comments. Empty lines are ignored.

```
# codeNforce help link redirect map
# Format:  stable-id   target-path-on-wiki
# Rules:
#   - stable IDs are permanent — never rename or delete a line, only change target
#   - use # TODO if target wiki page is not yet published (redirect falls back to homepage)
#   - anchors belong in the target path column: occ-permit-files /users/permitting/permit-files#overview

cecase-events-add           /users/cecases/add-an-event
cecase-cross-muni           /users/cecases/cross-municipality
cecase-cears-internal       /users/cecases/cears-internal
dashboard-case-priority     /users/cecases/case-priority-color-scheme
dashboard-case-search       /users/cecases/case-search
inspections-fins            /inspections/fins
code-enter-ordinance        /dev/code/enter-ordinance
code-add-to-codebook        /dev/code/add-to-codebook
code-create-checklist       /dev/code/create-checklist
property-persons-link       /users/properties/connecting-people-to-properties
occ-permit-files            /users/permitting/permit-files
occ-permit-generate         /users/permitting/generate-permit
```

### Nginx config generator script

**Location in boroughforge-wikidocs repo**: `helpmap/generate-helplinks-nginx.sh`

```sh
#!/bin/sh
# generate-helplinks-nginx.sh
# Converts helpmap/_redirects into Nginx location directives.
# Run on the docs VPS after CI copies both files there.
# Usage: ./generate-helplinks-nginx.sh [redirects-file] [output-file]

REDIRECTS="${1:-helpmap/_redirects}"
OUTFILE="${2:-/etc/nginx/snippets/helplinks.conf}"
BASE="https://docs.codenforce.org"

printf '# Auto-generated by CI on %s — do not edit manually\n' "$(date -u)" > "$OUTFILE"

grep -v '^#' "$REDIRECTS" | grep -v '^[[:space:]]*$' | while read -r id target; do
    printf 'location = /help/%s { return 302 %s%s; }\n' "$id" "$BASE" "$target" >> "$OUTFILE"
done

nginx -t && systemctl reload nginx
```

---

## CI/CD: GitHub Actions Deployment

**File**: `.github/workflows/deploy-helplinks.yml` in `boroughforge-wikidocs`

```yaml
name: Deploy help link redirects

on:
  push:
    branches: [main]
    paths:
      - 'helpmap/_redirects'
      - 'helpmap/generate-helplinks-nginx.sh'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Copy files to VPS
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.DOCS_VPS_HOST }}
          username: ${{ secrets.DOCS_VPS_USER }}
          key: ${{ secrets.DOCS_VPS_SSH_KEY }}
          source: "helpmap/_redirects,helpmap/generate-helplinks-nginx.sh"
          target: "/home/${{ secrets.DOCS_VPS_USER }}/helpmap-deploy"

      - name: Generate Nginx config and reload
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.DOCS_VPS_HOST }}
          username: ${{ secrets.DOCS_VPS_USER }}
          key: ${{ secrets.DOCS_VPS_SSH_KEY }}
          script: |
            chmod +x ~/helpmap-deploy/helpmap/generate-helplinks-nginx.sh
            sudo ~/helpmap-deploy/helpmap/generate-helplinks-nginx.sh \
              ~/helpmap-deploy/helpmap/_redirects \
              /etc/nginx/snippets/helplinks.conf
```

**Required GitHub secrets**: `DOCS_VPS_HOST`, `DOCS_VPS_USER`, `DOCS_VPS_SSH_KEY`

The deploy user needs passwordless sudo for the generator script only. Add to `/etc/sudoers.d/`:

```
edarsow ALL=(ALL) NOPASSWD: /home/edarsow/helpmap-deploy/helpmap/generate-helplinks-nginx.sh
```

**Result**: A documentation editor changes a link target by editing one line in `_redirects`,
committing, and pushing. CI deploys in under 10 seconds. No Java, no Maven, no WildFly touched.

---

## JSF/XHTML Side: The `helpLinkCC` Composite Component

**Updated 2026-08-16 (SL.3 build) — corrected against real code.** All 56 existing link
occurrences use *some* variant of an icon + text pattern, but there's real legacy variance
(different text, some icon-only, some outlined buttons — years of spotty doc linking). Rather
than try to capture that variance, `helpLinkCC` collapses everything to one consistent,
**icon-only** link: a single outlined "?" (Material Icons `help_outline`). This is the one
deliberate exception to this codebase's "no icon-only links without visible text" rule — a
help "?" is universally understood, and skipping the text avoids cluttering pages that may
carry several of these.

**Component location**: `src/main/webapp/resources/components/helpLinkCC.xhtml`

```xml
<?xml version='1.0' encoding='UTF-8' ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:cc="http://xmlns.jcp.org/jsf/composite">

    <cc:interface>
        <cc:attribute name="helpId" required="true"
                      shortDescription="Stable help-link ID from helpmap/_redirects; resolves to https://docs.codenforce.org/help/{helpId}" />
    </cc:interface>

    <cc:implementation>
        <div class="restrict-main-contents-io-link link-button">
            <a href="https://docs.codenforce.org/help/#{cc.attrs.helpId}"
               target="_blank">
                <i class="material-icons material-icon-inline">help_outline</i>
            </a>
        </div>
    </cc:implementation>

</html>
```

Usage in any XHTML page — the `resources/components/` library is already imported repo-wide
(76 existing files) under the `tt` alias, **not** `cnf` as an earlier draft of this doc assumed;
no new namespace convention is being introduced, and most pages needing a help link likely
already declare it for some other component:

```xml
xmlns:tt="http://xmlns.jcp.org/jsf/composite/components"
```

```xml
<tt:helpLinkCC helpId="cecase-events-add" />
```

The base URL `https://docs.codenforce.org` appears in exactly one place. If the domain ever
changes: edit one file, recompile once — not 29 scattered XHTML files.

---


## Migration Plan for Existing Links

**DONE 2026-08-16 (SL.4).** All 28 remaining files (of the 29 below — `occPeriodWorkflow.xhtml`
was already done as SL.3's pilot) were swept. Of the 21 stable IDs, **9 got a real, verified
target** (confirmed against actual page content, not guessed) and their occurrences were
replaced with `<tt:helpLinkCC helpId="..." />`; **12 had no real content anywhere** in the
`users/` tree after a fresh look, so their hardcoded link markup was **removed from the XHTML
entirely** rather than left pointing at a permanent homepage-fallback dead end. The 12
removed links, with context for whoever eventually writes that content, are tracked in
[system/static-link-orphaned-topics.md](/system/static-link-orphaned-topics) (linked from
[docbacklog.md](/system/docbacklog)) — not restated here. `helpmap/_redirects` keeps a line for
all 21 IDs either way (stable IDs are never deleted, only re-targeted later if content shows
up). See the codenforce repo's `docs/worklog.md` 2026-08-16 entry for the full file-by-file
record.

**Resolved (9):** `dashboard-case-priority`, `dashboard-case-search`, `property-mark-abandoned`,
`property-persons-link`, `property-link-mailing-address`, `cecase-management-overview`,
`occ-permit-generate`, plus the 2 already confirmed in SL.2 (`inspections-fins`,
`occ-permit-files`).

**Removed pending future content (12):** `cecase-events-add`, `cecase-cross-muni`,
`cecase-cears-internal`, `code-enter-ordinance`, `code-add-to-codebook`, `code-create-checklist`,
`cecase-upload-files`, `cecase-add-violation`, `cecase-nov-add-address`, `cecase-nov-prepare`,
`cecase-nov-add-person`, `property-link-multiple-people`.

### Files to modify

**29 XHTML files** (corrected by SL.0, 2026-08-14 — see the re-inventory note above), all
under `src/main/webapp/`:

| File (relative to `src/main/webapp/`) | Link IDs to apply |
|---|---|
| `restricted/navContainer_restricted.xhtml` | `cecase-cross-muni` |
| `restricted/compositions/session/sessCECase.xhtml` | `dashboard-case-priority` |
| `restricted/compositions/inspectionTools.xhtml` | `inspections-fins` (×2), `dashboard-case-priority` |
| `restricted/compositions/missioncontrol/missConCECaseSearch.xhtml` | `dashboard-case-search` (×2), `dashboard-case-priority` |
| `restricted/cogstaff/code/codeElementManage.xhtml` | `code-enter-ordinance` (×2) |
| `restricted/cogstaff/code/codeSetManage.xhtml` | `code-add-to-codebook` (×2) |
| `restricted/cogstaff/event/compositions/eventListPanel.xhtml` | `cecase-events-add` (×2) |
| `restricted/cogstaff/prop/compositions/propPersons.xhtml` | `property-persons-link` |
| `restricted/cogstaff/prop/compositions/propCases.xhtml` | `dashboard-case-priority` |
| `restricted/cogstaff/prop/compositions/propCEARS.xhtml` | `cecase-cears-internal` |
| `restricted/cogstaff/occ/inspectionChecklistTools.xhtml` | `code-create-checklist` |
| `restricted/cogstaff/occ/occPeriodWorkflow.xhtml` | `occ-permit-files` (×2) |
| `restricted/cogstaff/occ/compositions/permitsPanel.xhtml` | `occ-permit-generate` (×2) |
| `resources/components/cecaseInfoColumns.xhtml` *(new)* | `dashboard-case-priority` |
| `resources/components/eventListPanelCC.xhtml` *(new)* | `cecase-events-add` (×2) |
| `resources/components/propCasesCC.xhtml` *(new)* | `dashboard-case-priority` |
| `resources/components/propCEARSCC.xhtml` *(new)* | `cecase-cears-internal` |
| `resources/components/propInfoCC.xhtml` *(new)* | `property-mark-abandoned` (×2) |
| `resources/components/propPersonsCC.xhtml` *(new)* | `property-persons-link` |
| `restricted/cogstaff/ce/ceActionRequests.xhtml` *(new)* | `property-persons-link` (×2), `dashboard-case-priority` |
| `restricted/cogstaff/ce/compositions/ceCaseBlobs.xhtml` *(new)* | `cecase-upload-files` (×2) |
| `restricted/cogstaff/ce/compositions/ceCaseCEARPanel.xhtml` *(new)* | `cecase-cears-internal` |
| `restricted/cogstaff/ce/compositions/ceCaseCodeViolations.xhtml` *(new)* | `cecase-add-violation` (×2) |
| `restricted/cogstaff/ce/compositions/ceCaseInfo.xhtml` *(new)* | `dashboard-case-priority` (×2) |
| `restricted/cogstaff/ce/compositions/ceCaseNoticesOfViolation.xhtml` *(new)* | `cecase-nov-add-address` (×2), `cecase-nov-prepare`, `cecase-nov-add-person` (×2) |
| `restricted/cogstaff/ce/compositions/ceCasePersonLinks.xhtml` *(new)* | `property-persons-link` (×2) |
| `restricted/cogstaff/ce/compositions/ceCaseQuickLinks.xhtml` *(new)* | `cecase-management-overview` (×2) |
| `restricted/cogstaff/occ/compositions/occPeriodBlobs.xhtml` *(new)* | `cecase-upload-files` (×2) |
| `restricted/cogstaff/person/compositions/personTools.xhtml` *(new)* | `property-link-mailing-address`, `cecase-cross-muni` (×2), `property-link-multiple-people` (×2) |

`*(new)*` marks files missed by the original 13-file inventory — all `resources/components/*CC.xhtml`
composite-component duplicates plus a handful of `ce/`-tree pages not walked the first time.

### Migration steps

1. Create `helpLinkCC.xhtml` composite component. **Done (SL.3)** — icon-only per an explicit
   exception to the no-icon-only-links rule (a universally-understood "?", no paired text link).
2. Add the 21 stable IDs to `helpmap/_redirects` with `# TODO` placeholders for target paths not
   yet published to wiki; each `# TODO` entry should fall back to the docs homepage. **Done.**
3. Replace each hardcoded help-link block in each of the 29 files with
   `<tt:helpLinkCC helpId="..." />` where a real target exists; **remove the block entirely**
   (no replacement) where no real target could be found. **Done (SL.4, 2026-08-16)** — see the
   resolved/removed lists above.
4. Build and deploy the WAR. This is the **one and only WAR deploy** required by this migration.
   `mvn clean package -DskipTests` is a clean `BUILD SUCCESS`; a real WildFly deploy + browser
   QA is still the repo owner's to run.
5. As wiki pages are published for the 12 removed topics, add the help link back
   (`<tt:helpLinkCC helpId="..." />`) in the file(s) noted in
   [system/static-link-orphaned-topics.md](/system/static-link-orphaned-topics), and update
   `_redirects`' matching line from `# TODO` to a real path. This is now a **small, targeted
   WAR deploy per topic**, not a repeat of the big sweep.

---

## Governance: Adding a New Help Link

When a developer adds a contextual help link to any new XHTML page:

1. **Choose or reuse a stable ID.** Check `helpmap/_redirects` in `boroughforge-wikidocs` for
   an existing ID covering the same topic.
2. **If new, add a line to `_redirects`** — commit and push to `boroughforge-wikidocs`. CI
   deploys the new redirect within seconds. If the target wiki page is not yet published, use
   the docs homepage as a temporary fallback and add a `# TODO` comment on the same line.
3. **Add the component to the XHTML file**: `<tt:helpLinkCC helpId="your-new-id" />`
4. Include the namespace declaration on the page if not already present.

The stable ID is permanent. The wiki target in `_redirects` can be changed as many times as
needed with zero application impact.

---

## Responsibility Matrix

| What changes | Who edits | WAR redeploy? | Nginx reload? |
|---|---|---|---|
| Where a link points (wiki path) | Docs editor edits `_redirects` | No | Auto via CI |
| Adding a new stable ID | Docs editor adds line to `_redirects` | No | Auto via CI |
| Adding a help link to a page | XHTML developer uses `<tt:helpLinkCC>` | **Yes** | No |
| Help link visual style | CSS developer edits `style.css` | **Yes** | No |
| Docs base domain | One line in `helpLinkCC.xhtml` | **Yes — once** | No |

---

# Part 2: QR Code Redirects for Physical Marketing Materials

## Use Case

A client request requires magnetized QR code decals affixed to code enforcement vehicles.
Scanning the QR code directs the public to the CEAR (Code Enforcement Action Request) public
submission portal hosted in codeNforce. The physical decals cannot be reprinted whenever the
application URL changes (e.g., servlet path refactor, domain migration, WAR context root
change). The QR code URL is therefore a **permanently printed physical artifact** — even more
immutable than a compiled WAR file.

---

## Key Differences from In-App Help Links

| Dimension | In-app help links | QR code decals |
|---|---|---|
| How URL is stored | In compiled XHTML/WAR | Printed on physical material |
| Cost to change URL | WAR redeploy | Reprint and re-magnetise all vehicles |
| Primary client | Desktop/laptop staff browser | Mobile phone camera or QR scanner app |
| Redirect sensitivity | Low — page load, user already has context | High — cold scan, user expects instant landing |
| Availability requirement | Degraded gracefully if docs VPS is down | **Must work** — public-facing civic service |
| 301 cache risk | Negligible | **Real risk** — mobile browsers cache 301s aggressively |

---

## Architecture Recommendation

### Where to host the stable redirect

Three candidate hosts:

**Option 1 — Docs VPS (same as help links)**
- Stable URL: `https://docs.codenforce.org/go/cear`
- Rejected: availability coupling is wrong. If the docs VPS has a maintenance window or
  Docker hiccup, citizens trying to report a code violation get a dead QR code. The docs
  VPS going down should not affect a civic reporting tool.

**Option 2 — Production codeNforce application server** ✓ Recommended
- Stable URL: `https://[app-domain]/report` (or `/go/cear`)
- An Nginx reverse proxy in front of WildFly handles the redirect at the web server layer —
  completely outside the WAR and Maven build. The redirect target is the WildFly servlet path.
- Correct availability coupling: if the app server is up, the redirect is up; if the app is
  down for maintenance, the QR code landing page would be unreachable regardless.
- The redirect config is a one-line Nginx location block managed in a config file in the
  codenforce repo, never compiled into the WAR.

**Option 3 — Dedicated redirect subdomain** (`go.codenforce.org`)
- Purpose-built short URL service, fully independent from both app and docs servers.
- Best for multi-municipality scaling (each muni could have its own short URL).
- Recommended as a future upgrade if codeNforce is deployed across many municipalities.

**Immediate recommendation**: Option 2 on the production server. Option 3 if/when
multi-municipality deployments make a shared redirect domain worthwhile.

### Stable URL design for the QR code

The QR code URL should be:
- **As short as possible** — shorter URL = lower QR code density = larger, more robust
  printed squares = scannable from greater distance and in worse lighting (important on a
  vehicle in a parking lot or street)
- **Typed-friendly** — citizens who see the URL on the magnet should be able to type it
  manually if their camera app fails: `codenforce.org/report` beats
  `codenforce.org/codenforce/public/cear-submission-portal`
- **HTTPS from the QR code itself** — encode `https://` in the QR code, not `http://`.
  Modern phone browsers show security warnings on HTTP and some QR scanner apps refuse to
  open non-HTTPS URLs.

Recommended stable URL: `https://[app-domain]/report`

### Nginx configuration on the production server

```nginx
# /etc/nginx/snippets/qr-redirects.conf
# Managed in codenforce repo at: deployment/nginx/qr-redirects.conf
# Deploy: copy file to snippets/, nginx -t && systemctl reload nginx
# NO WAR recompile required to change the destination.
# NOTE: must live in snippets/, NOT conf.d/ — conf.d/ is auto-included at the
# http context level by nginx.conf, where location blocks are not permitted.

# Public CEAR submission portal — QR code on enforcement vehicles
# Change only the destination path, never this location block URL
location = /report {
    return 302 https://[app-domain]/codenforce/public/cears.xhtml;
}
```

Key decision: **302, not 301.**

- A 301 (permanent) redirect is cached indefinitely by mobile browsers. If the destination
  path changes six months after the decals are printed and you update the Nginx config, users
  who previously scanned will have the old destination cached in their phone's browser and will
  bypass the redirect entirely until the cache expires — which could be weeks.
- A 302 (temporary/found) redirect is not cached. Every scan hits the redirect server fresh,
  guaranteeing the current destination is always served.
- Reserve 301 only for the HTTP → HTTPS protocol upgrade (which browsers handle separately
  and correctly).

---

## Mobile / QR Scanner Considerations

### Protocol upgrade (HTTP → HTTPS)

Use a 301 at the protocol boundary only:

```nginx
server {
    listen 80;
    server_name [app-domain];
    return 301 https://$host$request_uri;
}
```

This `301` is safe to cache — the protocol upgrade from HTTP to HTTPS for a given domain
never changes. The destination-level redirect inside the HTTPS server block uses `302`.

### Redirect chain length

Each additional redirect adds a round trip on a mobile network. Keep the chain to exactly
two hops maximum:

```
http://[domain]/report        → 301 → https://[domain]/report   (protocol upgrade)
https://[domain]/report       → 302 → https://[domain]/codenforce/public/cears.xhtml
```

Do not chain a third hop (e.g., another redirect inside WildFly or a JSF navigation rule
before the final page). Chains of 3+ redirects are noticeably slow on LTE in a parking lot
and some QR scanner apps abandon the chain entirely.

### QR scanner app behaviour

Most modern iOS/Android camera apps and dedicated QR apps follow redirects transparently.
Edge cases to be aware of:

- **Captive portal detection**: On some Android builds, the OS may intercept HTTPS URLs on
  public WiFi before the redirect completes. This is outside your control but HTTPS is still
  mandatory (HTTP QR codes are far worse).
- **Preview-before-open prompt**: Several QR apps show the decoded URL and ask "open?" before
  navigating. The user sees your stable URL (`/report`), not the internal servlet path. This
  is a UX benefit — the printed URL and the shown URL match.
- **Old enterprise MDM browsers**: Municipal fleet vehicles may be associated with MDM-managed
  phones with locked-down browsers. Test the QR code on the actual device the enforcement
  officers carry.

### Response time

Nginx serving a static 302 with no backend processing completes in under 5ms on any modern
VPS. The mobile network round trip (typically 30–150ms on LTE) dominates. No optimisation
needed at the Nginx level.

### Landing page mobile-readiness

The CEAR submission portal page itself must be responsive. A citizen scanning a QR code from
a car magnet is on a phone. Verify `cears.xhtml` renders correctly at 375px viewport width
before the decals are printed.

---

## Config File Management

The redirect config lives in the codenforce source repository at:

```
deployment/nginx/qr-redirects.conf
```

It is **not** part of the Maven build and is never compiled into the WAR. Deployment process:

1. Edit `qr-redirects.conf` in the codenforce repo.
2. Copy the file to the production server: `scp` or a CI step.
3. On the server: `sudo nginx -t && sudo systemctl reload nginx`
4. No WildFly restart, no WAR redeploy, no Maven involved.

This can be wired into a GitLab CI job on the codenforce repo (separate from the WAR build
pipeline) so that merging a change to `qr-redirects.conf` automatically deploys it.

---

## Adding New QR Codes in Future

If additional QR codes are needed (e.g., per-municipality submission portals, a different
public form, a permit inquiry page):

1. Add a new `location = /[short-slug]` block to `qr-redirects.conf`.
2. Commit, push, deploy (CI or manual copy + nginx reload).
3. Generate the QR code from the new stable URL.
4. Print.

The slug namespace for QR codes should be documented in `qr-redirects.conf` with a comment
block listing all active codes, their print dates, and where they are physically deployed —
this creates an audit trail for when a slug must never be retired or repurposed.

---

## QR Code Redirect Responsibility Matrix

| What changes | Who edits | WAR redeploy? | Nginx reload? | Reprint decals? |
|---|---|---|---|---|
| Destination servlet path (app refactor) | DevOps edits `qr-redirects.conf` | No | **Yes** | No |
| App domain name change | DevOps updates `qr-redirects.conf` + reprints | No | Yes | **Yes** |
| Public-facing slug (e.g. `/report`) | **Cannot change** — physical material | — | — | **Yes, always** |
| New QR code for new feature | DevOps adds slug to `qr-redirects.conf` | No | Yes | New print run |
| Landing page content/layout | XHTML developer | Yes | No | No |
