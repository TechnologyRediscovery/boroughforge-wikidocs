---
title: Static-Link Redirect System — How-To
description: Day-to-day guide to adding/changing help-link redirects and understanding the CI pipeline that deploys them
published: true
date: 2026-08-14
tags: documentation, nginx, cicd
editor: markdown
---

# Static-Link Redirect System — How-To

Practical, day-to-day guide for the `/help/{stable-id}` redirect layer that lets codeNforce
XHTML pages link to docs.codenforce.org without ever hardcoding a real wiki path — and without
a WAR redeploy when a docs page moves.

**This is not the design doc.** For the architecture rationale, the options that were
considered and rejected, and the full stable-ID inventory/migration plan, see
[static-link-redirect-architecture.md](../wiki.js/static-link-redirect-architecture.md). This
page only covers how to actually *use* the system as built (SL.1 + SL.2).

---

## How this works, in one picture

```
[XHTML help link]  →  https://docs.codenforce.org/help/cecase-events-add
                              │
                              ▼
                       [Nginx on the docs VPS]
                         ├─ exact match on /help/cecase-events-add → 302 to the real wiki page
                         └─ anything else under /help/*            → 302 to the wiki homepage
                              │
                              ▼
                       [Wiki.js page, e.g. /users/cecases/add-an-event]
```

The stable ID (`cecase-events-add`) is the *only* thing that's permanent. The real wiki path
behind it can change at any time — you only ever edit one file to repoint it, and nothing
gets redeployed except Nginx's own config (a `reload`, not a restart).

---

## The three files, and who touches which

All three live in `boroughforge-wikidocs` (not the codenforce WAR repo):

| File | Who edits it | How often |
|---|---|---|
| `helpmap/_redirects` | **You, by hand** — this is the only file a content editor or developer normally touches | Every time a stable ID needs a new/changed target |
| `helpmap/generate-helplinks-nginx.sh` | Nobody, in normal operation | Only if the Nginx template itself needs to change |
| `.github/workflows/deploy-helplinks.yml` | Nobody, in normal operation | Only if the deploy mechanism itself changes |
| `/etc/nginx/snippets/helplinks.conf` (on the VPS) | **Nobody, ever** — auto-generated | Every deploy, overwritten from scratch |

---

## Step by step: adding or changing a redirect

### 1. Edit `helpmap/_redirects`

One stable ID per line, whitespace-separated: `stable-id   /target/path/on/wiki`. Comments
start with `#`; blank lines are ignored.

```
# Adding a new one:
occ-inspection-schedule     /users/subsystems/occ/scheduling-an-inspection

# Changing an existing target (edit in place — never delete/rename the ID itself):
occ-permit-files            /users/permitting/permit-files

# Not yet published — leave commented as # TODO so it safely falls back to the homepage
# instead of 404ing or pointing somewhere wrong:
# TODO cecase-upload-files
```

Rules that matter:
- **Stable IDs are permanent.** Once printed in an XHTML link (or, once SL.3 ships, baked into
  `helpLinkCC` usages), that ID can never be renamed or deleted — only its target path changes.
- **Anchors go in the target column**, not a separate field: `occ-permit-files
  /users/permitting/permit-files#overview`.
- **Unpublished pages get commented out with `# TODO`**, not given a guessed target. A
  commented line is invisible to the generator script and falls through to Nginx's catch-all
  `/help/` block (302 to the homepage) — safe, never a broken link.

### 2. Commit and push to `main`

```bash
git add helpmap/_redirects
git commit -m "helpmap: add occ-inspection-schedule redirect"
git push origin main
```

### 3. GitHub Actions takes it from here — automatically

Pushing to `main` with a change under `helpmap/_redirects` or
`helpmap/generate-helplinks-nginx.sh` fires `.github/workflows/deploy-helplinks.yml`. You don't
run anything yourself. The workflow:

1. Copies both `helpmap/` files to the docs VPS, into a dedicated deploy account's home
   directory (`~/helpmap-deploy/helpmap/`) — **not** a personal admin login; see
   [SL-2-helplinks-cicd.md](../../../codenforce/docs/subsystems/documentation/SL-2-helplinks-cicd.md)
   (codenforce repo) for why and how that account is scoped.
2. SSHes in and runs `generate-helplinks-nginx.sh` under a narrowly-scoped `sudo` rule (that
   one script only — nothing else).
3. That script regenerates `/etc/nginx/snippets/helplinks.conf` from scratch and runs
   `nginx -t && systemctl reload nginx` — a few seconds, zero downtime, no dropped in-flight
   requests.

You can also trigger this manually without pushing a file change — the workflow has a
`workflow_dispatch` trigger: GitHub repo → **Actions** tab → "Deploy help link redirects" →
**Run workflow**.

### 4. Verify

```bash
curl -I https://docs.codenforce.org/help/occ-inspection-schedule
# expect: HTTP/2 302, with a `location:` header pointing at the real wiki page

curl -I https://docs.codenforce.org/help/some-id-that-does-not-exist
# expect: HTTP/2 302, `location:` pointing at the wiki homepage — the safe fallback
```

---

## What the generated config actually looks like

`generate-helplinks-nginx.sh` turns every **active** (non-comment) line in `_redirects` into
one `location` block. Given this `_redirects` excerpt:

```
cecase-events-add    /users/cecases/add-an-event
occ-permit-files     /users/permitting/permit-files
```

`/etc/nginx/snippets/helplinks.conf` comes out as:

```nginx
# Auto-generated by CI on Fri 14 Aug 2026 18:32:01 UTC — do not edit manually
location = /help/cecase-events-add { return 302 https://docs.codenforce.org/users/cecases/add-an-event; }
location = /help/occ-permit-files { return 302 https://docs.codenforce.org/users/permitting/permit-files; }
```

> **Why `snippets/` and not `conf.d/`?** Debian/Ubuntu's stock `nginx.conf` auto-`include`s
> everything under `conf.d/*.conf` at the `http {}` context — where bare `location` blocks are
> illegal (`nginx -t` fails with `"location" directive is not allowed here`). `snippets/` isn't
> auto-included by anything, so it only loads via the explicit `include` line below, inside the
> actual `server {}` block — the right context for `location` directives.

This file is `include`d from the docs VPS's main Nginx server block (set up in
[SL-1-nginx-tls-vps.md](../../../codenforce/docs/subsystems/documentation/SL-1-nginx-tls-vps.md)),
alongside a catch-all block for anything *not* in the generated list:

```nginx
server {
    listen 443 ssl;
    server_name docs.codenforce.org;
    # ... ssl_certificate lines ...

    include /etc/nginx/snippets/helplinks.conf;   # every known stable ID — exact matches

    location /help/ {                            # anything else under /help/*
        return 302 https://docs.codenforce.org/;
    }

    location / {                                  # everything not under /help/ at all
        proxy_pass http://localhost:3000;         # → Wiki.js
        # ...
    }
}
```

**Order in the file doesn't matter here** — Nginx always evaluates `location =` exact matches
before prefix matches like `location /help/`, regardless of where each block physically sits
in the config. The three blocks above simply cover, in order of specificity: a known ID → an
unknown ID under `/help/` → anything outside `/help/` entirely.

### `_redirects` is a manifest, not a queue

Nothing ever gets "consumed" or deleted from `helpmap/_redirects` by the pipeline. The
generator script only *reads* it (`grep`/`read`) — it never writes back to it. Every single
deploy re-parses the **entire current file** and rebuilds **all** of `helplinks.conf` from
scratch (its first line is a truncating `>`, not an append), not just whatever changed since
the last run. `_redirects` in git is the one durable source of truth; it just keeps
accumulating lines over time. To retire a stable ID, manually comment it out (or delete the
line) and commit that — the next deploy stops emitting its `location` block.

### Editing `helplinks.conf` by hand on the VPS (emergency stopgap only)

Sometimes you need a redirect live *now* and the pipeline isn't cooperating (SSH/CI issue,
time pressure, etc.). It's safe to SSH in and add `location =` blocks to
`/etc/nginx/snippets/helplinks.conf` directly, then `sudo nginx -t && sudo systemctl reload
nginx` — that's exactly what the script does, nginx doesn't care who wrote the directives.

**But it will not survive the next successful deploy.** Because the script always truncates
and rewrites the whole file from `_redirects` alone, any block you added by hand vanishes,
silently, the next time CI runs the generator successfully — there's no merge, no warning.
If you use this stopgap, **also commit the matching lines to `_redirects` in the same sitting**
so the hand-added redirects become permanent instead of disappearing on the next deploy.

---

## Using a stable ID from XHTML today

`helpLinkCC` (the composite component that will wrap this in a single reusable tag) is
**SL.3, not built yet**. Until it ships, link directly to the stable ID with a plain output
link — never hardcode the real wiki path:

```xml
<h:outputLink value="https://docs.codenforce.org/help/cecase-events-add" target="_blank">
    <i class="material-icons">help_outline</i> help
</h:outputLink>
```

The stable ID (`cecase-events-add`) is the only part of this that should ever be hand-picked;
everything after `/help/` in the target column of `_redirects` can change freely without
touching this XHTML again.

---

## Troubleshooting

This page assumes the pipeline is already working. If the GitHub Actions workflow itself is
failing (SSH auth, sudoers, secrets), that's CI/CD setup, not day-to-day usage — see
[SL-2-helplinks-cicd.md](../../../codenforce/docs/subsystems/documentation/SL-2-helplinks-cicd.md)
for the account/secrets/sudoers setup and its SSH-connectivity debug workflow.

---

## See also

- [static-link-redirect-architecture.md](../wiki.js/static-link-redirect-architecture.md) — full design doc, stable-ID inventory, options considered
- [SL-1-nginx-tls-vps.md](../../../codenforce/docs/subsystems/documentation/SL-1-nginx-tls-vps.md) — Nginx + TLS setup on the docs VPS
- [SL-2-helplinks-cicd.md](../../../codenforce/docs/subsystems/documentation/SL-2-helplinks-cicd.md) — CI/CD account, secrets, sudoers, debugging
- [documentation-feature-index.md](../../../codenforce/docs/subsystems/documentation/documentation-feature-index.md) — overall SL.0–SL.5 status
