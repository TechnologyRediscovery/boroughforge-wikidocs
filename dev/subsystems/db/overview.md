---
title: Database & Patching — Developer Notes
description: Index of developer and operations pages for the CodeNforce production database — backup, restore, recovery, PostgreSQL administration, and production findings.
published: true
date: 2026-08-07T00:00:00.000Z
tags: subsystem:db, audience:dev, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Database & Patching — Developer Notes

Index of the database, backup, and recovery pages for the CodeNforce production `cogdb` PostgreSQL cluster.

## Backup and Restore

- [PostgreSQL backup strategy](/dev/subsystems/db/cnf-backup-strategy) — architecture, tooling, and discipline for local physical backups and WAL-G archiving to Backblaze B2.
- [WAL-G setup](/dev/subsystems/db/wal-g-setup) — installing WAL-G and configuring Backblaze B2 as the WAL archive target.
- [Backup restore runbook](/dev/subsystems/db/backup-restore-runbook) — incident-response fast path for restoring the production database.
- [WD Elements safe unplug](/dev/subsystems/db/wd-elements-safe-unplug) — safely disconnecting the WD Elements backup drive after a backup run.

## Disaster Recovery

- [Full VPS catastrophic recovery](/dev/subsystems/db/full-vps-catastrophic-recovery) — rebuilding the entire CodeNforce stack on a fresh VPS.
- [VPS provider alternatives](/dev/subsystems/db/vps-provider-alternatives) — non-DigitalOcean hosting options for DR testing and provider diversification.

## PostgreSQL Administration
Claude?
- [PostgreSQL cluster hygiene](/dev/subsystems/db/postgresql-cluster-hygiene) — cluster inventory, version management, and the 14 to 18 upgrade procedure.
- [PostgreSQL user and role administration](/dev/subsystems/db/postgres-user-admin-guide) — the permission model, read-only backup role, and safe removal of departed users.

## Production Findings

- [Production DB log](/dev/subsystems/db/proddblog) — append-only log of patch and schema divergence findings.

See the [subsystem registry](/system/subsystem-registry) X-series entry `X4` for scope notes. This is an X-series dev-only concern — no admin/users/public spoke applies unless it graduates to the numbered list.
