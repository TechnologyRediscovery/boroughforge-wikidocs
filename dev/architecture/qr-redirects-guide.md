# QR Code Redirects: Implementation Guide

Magnetized QR code decals on code enforcement vehicles point citizens to the public CEAR
submission portal. The QR code URL is permanently printed and cannot change. This guide
describes how to manage the redirect so the destination can be updated at any time without
reprinting decals and without redeploying the codeNforce WAR.

For the architectural rationale and comparison of alternatives, see
[static-link-redirect-architecture.md](../wiki.js/static-link-redirect-architecture.md).

---

## How This Works

Nginx sits in front of WildFly as a reverse proxy and handles SSL. A single `location` block
in Nginx intercepts requests to the stable slug (e.g. `/report`) and issues a 302 redirect to
the actual WildFly page — before the request ever reaches Java.

Changing the destination means editing one config file and running `nginx reload`. No Maven,
no WAR, no WildFly restart.

---

## Prerequisites

- SSH access to the production codeNforce server
- `sudo` rights to reload Nginx
- The codenforce repo cloned locally (config file lives at `deployment/nginx/qr-redirects.conf`)

---

## One-Time Setup

### Step 1 — Add the include line to your existing Nginx server block

Find your main Nginx site config. It is likely at:

```
/etc/nginx/conf.d/codenforce.conf
```

or whichever `.conf` file contains your `server { listen 443 ssl; ... }` block for the
codeNforce domain. Add the `include` line **inside** the `server` block, before the catch-all
`location /` proxy block:

```nginx
server {
    listen 443 ssl;
    server_name your-cnf-domain.com;

    # ... existing ssl_certificate lines ...

    # Stable QR code and short-URL redirects — managed without WAR redeploy
    include /etc/nginx/snippets/qr-redirects.conf;

    # Catch-all proxy to WildFly — must come AFTER the include
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

> **Order matters.** Nginx evaluates `location = /slug` exact-match blocks before the
> `location /` catch-all, regardless of file order. Putting the `include` before `location /`
> is a convention for readability, not a functional requirement.

### Step 2 — Create `/etc/nginx/snippets/qr-redirects.conf` on the server

The file must live in `snippets/`, not `conf.d/`. On Debian/Ubuntu, `nginx.conf` auto-includes
everything in `conf.d/` at the `http` context level — where `location` blocks are illegal.
The `snippets/` directory is not auto-included and is specifically intended for partial config
files like this one.

```bash
sudo nano /etc/nginx/snippets/qr-redirects.conf
```

Paste the initial content (see the template in the next section), save, then test and reload:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Step 3 — Copy the canonical version into the codenforce repo

The file on the server and the file in the repo must stay in sync. The repo copy is the
source of truth:

```
codenforce/deployment/nginx/qr-redirects.conf
```

---

## The Config File

### Template

```nginx
# QR Code & Stable URL Redirects
# ---------------------------------------------------------------
# Source of truth: codenforce repo → deployment/nginx/qr-redirects.conf
# Server location: /etc/nginx/snippets/qr-redirects.conf
#
# To update a destination:
#   1. Edit the return line below
#   2. scp this file to the server (see Deployment section)
#   3. sudo nginx -t && sudo systemctl reload nginx
#   No WAR recompile. No WildFly restart.
#
# IMPORTANT: Never rename or repurpose a slug without reprinting all
# physical materials that use it. Log print dates and locations below.
#
# Active slugs:
#   /report  — CEAR public submission portal
#              Printed: 2026-06
#              Deployed: code enforcement vehicle fleet
# ---------------------------------------------------------------

location = /report {
    return 302 https://your-cnf-domain.com/codenforce/public/cears.xhtml;
}
```

### Why `302` and not `301`

A `301` (permanent redirect) is cached indefinitely by mobile browsers. If the destination
path ever changes after decals are printed, phones that previously scanned will serve the
cached old URL — bypassing your updated config — until their cache expires naturally, which
can take weeks. A `302` is never cached, so every scan hits the server fresh and always gets
the current destination.

---

## Deployment: Updating a Destination

Use this procedure any time the WildFly servlet path changes (e.g. after a WAR refactor or
context root change):

```bash
# 1. Edit the repo copy
nano deployment/nginx/qr-redirects.conf
#    Change the return URL on the relevant location block

# 2. Copy to the server
scp deployment/nginx/qr-redirects.conf \
    user@your-server:/etc/nginx/snippets/qr-redirects.conf

# 3. Validate — this checks syntax without touching live traffic
sudo nginx -t

# 4. Reload — zero downtime, in-flight requests are not dropped
sudo systemctl reload nginx

# 5. Verify
curl -I https://your-cnf-domain.com/report
# Expected response headers:
#   HTTP/2 302
#   location: https://your-cnf-domain.com/codenforce/public/cears.xhtml
```

Commit the repo copy after confirming the redirect works:

```bash
git add deployment/nginx/qr-redirects.conf
git commit -m "redirect: update /report destination to new cears path"
```

---

## Adding a New QR Code

1. Choose a short, typed-friendly slug: `/permits`, `/inspect`, `/pay` — not
   `/public-occupancy-permit-application-form`.

2. Add a block to `qr-redirects.conf` with a comment documenting print date and deployment:

```nginx
# /permits — Occupancy permit application portal
#             Printed: YYYY-MM
#             Deployed: front counter reception desk (3 table cards)
location = /permits {
    return 302 https://your-cnf-domain.com/codenforce/public/occPermitApp.xhtml;
}
```

3. Deploy using the steps above.

4. Generate the QR code from `https://your-cnf-domain.com/permits` — **after** the redirect
   is live and verified, not before.

> **QR code density note**: shorter slugs produce simpler QR codes with larger squares. A
> simpler QR code scans reliably from greater distance and in worse lighting — important for
> a decal on a vehicle in a parking lot.

---

## Verifying a Redirect

```bash
# Check redirect headers (does not follow the redirect)
curl -I https://your-cnf-domain.com/report

# Follow the full chain and show all hops
curl -IL https://your-cnf-domain.com/report

# Check from HTTP (should 301 to HTTPS, then 302 to destination)
curl -IL http://your-cnf-domain.com/report
```

Expected full chain for an HTTP scan:

```
HTTP/1.1 301 Moved Permanently        ← http → https (cached, correct)
location: https://your-cnf-domain.com/report

HTTP/2 302                             ← stable slug → destination (not cached, correct)
location: https://your-cnf-domain.com/codenforce/public/cears.xhtml

HTTP/2 200                             ← WildFly renders the page
```

---

## Slug Retirement Policy

A slug printed on physical materials **must never be repurposed**. If a QR code campaign
ends, comment out the block rather than deleting it, and add a `RETIRED` note:

```nginx
# /report — CEAR portal — RETIRED 2027-03, decals removed from fleet
# DO NOT repurpose: old decals may still be in circulation
# location = /report {
#     return 302 https://...;
# }
```

This preserves the audit trail and prevents accidentally assigning the same slug to a
different destination years later while old decals are still in the wild.
