---
title: Wiki.js VPS Docker Operations Cheat Sheet
description: Core commands for checking, restarting, and troubleshooting the Wiki.js Docker container on the documentation VPS
published: false
date: 2026-06-22T00:00:00.000Z
tags:
editor: markdown
dateCreated: 2026-06-22T00:00:00.000Z
---

# Wiki.js VPS Docker Operations Cheat Sheet

This page collects basic commands for checking the Wiki.js Docker container, viewing logs, restarting services, and confirming that Wiki.js can reach PostgreSQL.

The current documentation VPS uses:

- Wiki.js running in a Docker container named `wiki`
- Host-native PostgreSQL
- Wiki.js connecting to PostgreSQL through the Docker bridge address
- Built-in Wiki.js HTTPS / Let's Encrypt handling

## See what Docker containers are running

Show running containers:

```bash
sudo docker ps
```

Include stopped containers:

```bash
sudo docker ps -a
```

Show a cleaner table:

```bash
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

## Check Wiki.js logs

Show recent logs:

```bash
sudo docker logs --tail 100 wiki
```

Follow live logs:

```bash
sudo docker logs -f wiki
```

Watch likely sync, certificate, and error lines:

```bash
sudo docker logs -f wiki | grep -Ei 'git|sync|storage|error|warn|letsencrypt|certificate|https'
```

## Restart Wiki.js

Restart the container:

```bash
sudo docker restart wiki
```

Stop and start separately:

```bash
sudo docker stop wiki
sudo docker start wiki
```

## Check the container restart policy

```bash
sudo docker inspect wiki --format '{{ .HostConfig.RestartPolicy.Name }}'
```

Expected value:

```text
unless-stopped
```

## Inspect Wiki.js container configuration

Show environment variables:

```bash
sudo docker inspect wiki --format '{{range .Config.Env}}{{println .}}{{end}}'
```

Show published ports:

```bash
sudo docker port wiki
```

Show mounts, if `jq` is installed:

```bash
sudo docker inspect wiki --format '{{json .Mounts}}' | jq
```

Without `jq`:

```bash
sudo docker inspect wiki --format '{{json .Mounts}}'
```

## Get a shell inside the Wiki.js container

Use `sh`, which is usually available:

```bash
sudo docker exec -it wiki sh
```

If `bash` is available:

```bash
sudo docker exec -it wiki bash
```

Exit the container shell:

```bash
exit
```

## Check listening ports on the VPS

```bash
sudo ss -ltnp | grep -E ':80|:443|:5432'
```

Expected rough meaning:

```text
:80    Docker / Wiki.js HTTP
:443   Docker / Wiki.js HTTPS
:5432  PostgreSQL on localhost and/or Docker bridge
```

## Check PostgreSQL service status

Because Wiki.js connects to host-native PostgreSQL:

```bash
sudo systemctl status postgresql@16-main
```

Restart PostgreSQL if needed:

```bash
sudo systemctl restart postgresql@16-main
```

Confirm PostgreSQL is listening:

```bash
sudo ss -ltnp | grep :5432
```

## Test that a Docker container can reach PostgreSQL

Use a temporary PostgreSQL client container:

```bash
sudo docker run --rm -it postgres:16 \
  psql -h 172.17.0.1 -U wiki -d wiki -c "select current_database(), current_user;"
```

If this works, a Docker container can reach the host PostgreSQL service through the Docker bridge address.

## Check the Wiki.js TLS certificate

From the VPS:

```bash
echo | openssl s_client -servername docs.codenforce.org -connect docs.codenforce.org:443 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

This shows the subject, issuer, and validity dates for the HTTPS certificate.

## Optional monthly restart cron

Edit root's crontab:

```bash
sudo crontab -e
```

Add this line to restart Wiki.js at 3:00 AM on the first day of each month:

```cron
0 3 1 * * /usr/bin/docker restart wiki >/dev/null 2>&1
```

## Common quick checks

Check Wiki.js status:

```bash
sudo docker ps --filter name=wiki
```

Restart and immediately watch logs:

```bash
sudo docker restart wiki
sudo docker logs -f wiki
```

Check whether PostgreSQL is running:

```bash
sudo systemctl is-active postgresql@16-main
```

Check whether ports 80 and 443 are bound:

```bash
sudo ss -ltnp | grep -E ':80|:443'
```

## Custom CSS: move the page sidebar (Contents / Tags / Last Edited By) to the right

**Try this first, no CSS needed:** Wiki.js's default theme has a built-in **Table of Contents
Position** setting — **Administration → Theme → Table of Contents Position → Right**. It moves
the Contents/Tags/Last-Edited-By column (and the title-banner indent that lines up with it) as
one unit, which is exactly this ask. Confirm the header title/description banner still lines up
with the article body afterward; if it does, nothing below is needed.

**If the toggle isn't available or doesn't fully do it**, paste this into
**Administration → Theme → Custom CSS** (append — don't overwrite whatever is already
there; see the "Custom Theme CSS...not git-backed" note in
[SL-1-nginx-tls-vps.md](../../../codenforce/docs/subsystems/documentation/SL-1-nginx-tls-vps.md)
Phase 0 — nothing here lives in git, so re-paste after any VPS/droplet migration):

```css
/* Move the page sidebar (Page Contents / Tags / Last Edited By) to the right of the
   article body instead of the left. Reverse-engineered from the default theme's
   client/themes/default/components/page.vue: .page-col-sd is the sidebar column,
   .page-col-content is the article column, both children of the same flex row — swapping
   their `order` swaps which side they render on. Only takes effect at the `lg` breakpoint
   and up; below that the sidebar isn't rendered at all, so no media query is needed here. */
.v-application .page-col-sd {
  order: 2 !important;
}
.v-application .page-col-content {
  order: 1 !important;
}

/* The title/description banner above the two columns is indented (offset-lg3/offset-xl2)
   to line up under the sidebar's width when the sidebar is on the left. With the sidebar
   moved to the right, that indent just leaves dead space on the left — drop it so the
   title lines up flush with the article body underneath it. */
.v-application .page-header-section .page-col-content {
  margin-left: 0 !important;
}
```

If the deployed Wiki.js version renders different class names than `.page-col-sd` /
`.page-col-content` / `.page-header-section` (check via browser dev tools — right-click the
sidebar → Inspect), update the selectors above to match; the `order`/`margin-left` approach
itself still applies.
