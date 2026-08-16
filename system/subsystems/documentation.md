---
title: Documentation & Help Systems
description: The Wiki.js docs site itself, plus the static-link redirect layer connecting in-app help and QR codes to it.
published: true
date: 2026-08-16T00:00:00.000Z
tags: subsystem:documentation, type:hub
editor: markdown
dateCreated: 2026-08-16T00:00:00.000Z
---

# Documentation & Help Systems (`documentation`)

The Wiki.js docs site you're reading right now, plus the static-link redirect layer that
connects it to the rest of CodeNforce: in-app `/help/{id}` links (dev/admin/users audiences)
and the QR-code `/report` redirect for citizens scanning vehicle decals. Unlike every other
subsystem in the registry, this one *is* the docs site — there's no separate
`dev/`/`admin/`/`users/`/`public/` spoke set to link out to.

- **Design docs:** [Docs overhaul plan](/dev/architecture/docs-overhaul-aug26) (directory
  structure, subsystem registry, page-type taxonomy) and
  [Static-link redirect architecture](/dev/wiki.js/static-link-redirect-architecture) (the
  `/help/{id}` + QR-redirect design).
- **Operations:** [Wiki.js VPS reference](/dev/wiki.js/wikijs-vps-reference) — Docker/Nginx/TLS
  cheat sheet, plus the Custom-CSS page-sidebar-position fix.
- **Change history:** [Documentation change log](/system/doclog) — structural changes to this
  repo (file moves, conversions, subsystem-registry revisions).
- **Cross-repo:** the static-link engineering work (`SL.1`–`SL.5`) and its day-to-day tracking
  live in the `codenforce` Java repo's `docs/subsystems/documentation/` folder, not in this
  Wiki.js site — see `documentation-feature-index.md` and `SL-1-nginx-tls-vps.md` there.

See also: [subsystem registry](/system/subsystem-registry), entry #24.
