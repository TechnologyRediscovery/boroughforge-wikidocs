---
title: PostgreSQL Cluster Hygiene — Inventory, Version Management, and Upgrade Procedure
description: Reference document covering the Ubuntu multi-cluster PostgreSQL architecture, current cluster inventory on the CodeNforce production VPS, cleanup of stale clusters, and the pg_upgradecluster 14→18 migration procedure. Includes the critical ordering constraint relative to WAL-G archiving setup.
published: true
date: 2026-09-07
tags: [postgresql, infrastructure, upgrade, cluster-management, ubuntu]
editor: markdown
dateCreated: 2026-09-07
---

# PostgreSQL Cluster Hygiene — Inventory, Version Management, and Upgrade Procedure

## Purpose and scope

This document covers:

- How Ubuntu's PostgreSQL packaging model supports multiple simultaneous major versions
- Current cluster inventory on the production VPS and the state of stale clusters
- How to correctly identify the running server version (and why the naive approach is wrong)
- Cleanup procedure for stale clusters
- The `pg_upgradecluster` procedure for migrating from PostgreSQL 14 to 18
- The critical ordering constraint between the 14→18 upgrade and WAL-G archiving setup

**Companion documents:**
- `cnf-backup-strategy.md` — overall backup architecture and 3-2-1 rationale
- `wal-g-setup.md` — WAL-G installation and Backblaze B2 configuration
- `backup-restore-runbook.md` — incident response restore procedures

---

## Ubuntu's multi-version PostgreSQL architecture

### How PostgreSQL is packaged on Ubuntu

On Ubuntu, PostgreSQL is installed via packages from the PostgreSQL Global Development Group (PGDG) apt repository. Unlike most software where installing a new version replaces the old one, PostgreSQL major versions coexist as separate packages: `postgresql-14`, `postgresql-15`, `postgresql-16`, `postgresql-17`, `postgresql-18` can all be installed simultaneously without conflict.

Each major version installs:
- Its own server binary (e.g., `/usr/lib/postgresql/18/bin/postgres`)
- Its own client binaries (e.g., `/usr/lib/postgresql/18/bin/psql`)
- Its own default configuration directory under `/etc/postgresql/<version>/`
- Its own default data directory parent under `/var/lib/postgresql/<version>/`

**The version in a path is the major version** (14, 15, 16, 17, 18). PostgreSQL major versions are not backward-compatible at the data directory level — a PostgreSQL 14 server cannot read data files written by PostgreSQL 18.

### What a "cluster" is in Ubuntu terms

Ubuntu adds a layer of abstraction: a **cluster** is a named instance of a particular PostgreSQL major version. A cluster consists of:

- A major version (e.g., `14`)
- A cluster name (e.g., `main`)
- A data directory (e.g., `/var/lib/postgresql/14/main`)
- A configuration directory (e.g., `/etc/postgresql/14/main/`)
- A port number (default `5432`, but each cluster must have a unique port if multiple run simultaneously)
- A set of databases (e.g., `cogdb`, `postgres`, `template0`, `template1`)

The default cluster created when `postgresql-14` is installed is named `main`, giving the familiar path `14/main`. You can create additional named clusters with `pg_createcluster`, and multiple versions can each have their own `main` cluster simultaneously with different port numbers.

**Key implication:** "cluster" in Ubuntu PostgreSQL docs means a version+name pair that owns a data directory. This is distinct from PostgreSQL's own use of "cluster" to mean a running database server instance. In this document, "cluster" means the Ubuntu concept.

### The `pg_wrapper` mechanism and why `psql --version` lies

Ubuntu's PostgreSQL packages install a `pg_wrapper` script at `/usr/bin/psql` (and similarly for `pg_dump`, `pg_restore`, etc.). When you run `psql` without a full path, you get the wrapper, not a specific version's binary.

**The critical gotcha:** `psql --version` reports the version of the client binary the wrapper selects, which is controlled by the `pg_ctlcluster` default version setting — **not necessarily the version of the server you are connected to.**

```bash
# This is the client binary version, NOT the server version.
# These can differ silently if you have multiple PostgreSQL versions installed.
psql --version
# Example output: psql (PostgreSQL) 18.2
# But the server you connect to might be running PostgreSQL 14.

# The correct way to determine the RUNNING SERVER version:
# Method 1: pg_lsclusters — shows all clusters and their status
pg_lsclusters
# Output columns: Ver  Cluster  Port  Status  Owner     Data directory                    Log file
# Example:
# 14  main     5432  online  postgres  /var/lib/postgresql/14/main  /var/log/postgresql/postgresql-14-main.log
# 18  main     5433  down    postgres  /var/lib/postgresql/18/main  /var/log/postgresql/postgresql-18-main.log

# Method 2: query the server directly via SQL
psql -U postgres -c "SELECT version();"
# Returns the full version string of the connected server:
# PostgreSQL 14.12 on x86_64-pc-linux-gnu, compiled by gcc ...

# Method 3: look at the data directory PG_VERSION file
cat /var/lib/postgresql/14/main/PG_VERSION
# Returns: 14
# This is the major version that initialized the data directory.
# A server that has been pg_upgradecluster'd will have this file updated.
```

---

## Current cluster inventory

### Production cluster

| Property | Value |
|---|---|
| Major version | 14 |
| Cluster name | main |
| Port | 5432 |
| Data directory | `/var/lib/postgresql/14/main` |
| Config directory | `/etc/postgresql/14/main/` |
| Primary database | `cogdb` |
| Status | online (production) |
| Upstream support ends | November 2026 |

This is the only cluster serving live application traffic. WildFly connects to port 5432.

### Stale clusters

The following clusters exist on the VPS but are not serving production traffic. They are artifacts of prior version installations or failed upgrades and should be removed. Their presence is benign but creates confusion when interpreting `pg_lsclusters` output and wastes a small amount of disk space.

```bash
# Inventory all clusters on the system:
pg_lsclusters
```

Expected stale entries (verify against actual output before removing):

| Major version | Cluster name | Status | Action |
|---|---|---|---|
| 13 | main | down | Remove — EOL, obsolete |
| 15 | main | down | Remove — not production |
| 16 | main | down | Remove — not production |
| 17 | main | down | Remove — not production (superseded target; see below) |
| 18 | main | down | Remove — will become production after upgrade |

**Do not remove the version 18 cluster before reviewing whether you want to reuse it as the upgrade target.** `pg_upgradecluster` can create a fresh target cluster automatically, making any pre-existing stale 18 cluster irrelevant. If one exists, drop it first to avoid port conflicts.

### Verify upstream support status

PostgreSQL Global Development Group publishes versioned support timelines. PostgreSQL 14 reaches end-of-life in November 2026, after which no security patches are released.

```bash
# Check installed package versions:
dpkg -l | grep postgresql | grep -v "^rc"
# rc entries are removed packages with residual config; irrelevant here.

# Check what's available from PGDG:
apt-cache policy postgresql-18
# Shows installed version, candidate version, and sources.
```

---

## Stale cluster removal

**Prerequisite: confirm the cluster to be removed is not running and contains no data you need.**

```bash
# Safety check: list all clusters and their status.
pg_lsclusters

# Confirm the target cluster is 'down' before proceeding.
# If status shows 'online', stop it first:
sudo pg_ctlcluster 13 main stop
# pg_ctlcluster: Ubuntu's wrapper for pg_ctl
# Arguments: <version> <cluster-name> <action>
# Actions: start, stop, restart, reload, status, promote

# Drop the cluster.
# pg_dropcluster removes the data directory, config directory, and
# the cluster's entries in /etc/postgresql/ and system service files.
# It does NOT remove the postgresql-13 package itself.
# --stop: if the cluster happens to be running, stop it first.
sudo pg_dropcluster --stop 13 main

# Repeat for each stale version:
sudo pg_dropcluster --stop 15 main
sudo pg_dropcluster --stop 16 main
sudo pg_dropcluster --stop 17 main
# Do NOT drop 18 main here if it is your intended upgrade target —
# pg_upgradecluster will handle it, or you can drop and let pg_upgradecluster
# create a fresh one. See upgrade procedure below.

# Remove the now-empty package (optional — keeps apt output clean):
sudo apt remove --purge postgresql-13
# --purge: remove configuration files along with the package.
# Without --purge, /etc/postgresql/13/ may linger.

# Verify cleanup:
pg_lsclusters
ls /var/lib/postgresql/
# Should show only 14/ and 18/ directories after cleanup.
```

---

## PostgreSQL 14 → 18 upgrade procedure

### Why upgrade

PostgreSQL 14 upstream support ends November 2026. After that date, discovered security vulnerabilities receive no patches. Running an unpatched database server hosting municipal enforcement records with potential legal standing is an unacceptable security posture.

PostgreSQL 18 is the current stable major version (already several point releases in — 18.6 as of August 2026). PostgreSQL 17 has been superseded as "current"; `pg_upgradecluster`/`pg_upgrade` supports jumping directly from 14 to 18 in one step — there is no requirement to stage through 15/16/17 first, so there is no reason to target 17 instead. The upgrade brings performance improvements (logical replication, query planning, vacuum improvements, plus 18's own additions), but the primary driver here is continued security patch coverage — targeting 18 rather than 17 maximizes the runway before the next forced upgrade.

### The WAL-G ordering constraint

**This is the most important operational constraint in this procedure.**

WAL-G's continuous archive consists of two components: base backups and WAL segments. These form a chain — WAL segments are replayed starting from a base backup. A WAL segment generated by PostgreSQL 14 cannot be replayed against a PostgreSQL 18 data directory. After `pg_upgradecluster` runs, the data directory is a PostgreSQL 18 data directory.

**Implication:** Any WAL archive accumulated under PostgreSQL 14 cannot be used for PITR against the post-upgrade cluster. The upgrade creates a discontinuity in the WAL chain.

**Required ordering:**

1. Take a final `pg_dump` backup of the running PG 14 cluster (belt-and-suspenders).
2. Perform `pg_upgradecluster 14 main 18`.
3. Verify the PG 18 cluster is running correctly.
4. Run `wal-g backup-push` to establish a new base backup under PG 18. This starts a fresh WAL chain.
5. Confirm WAL archiving is running under PG 18 (`pg_stat_archiver`).
6. Retain the PG 14 cluster's final pg_dump for any historical PITR needs (there is none from WAL for post-upgrade; the dump is your last resort for pre-upgrade state).

**Do not set up WAL-G archiving on PG 14 if you are planning to upgrade within weeks.** Setting up archiving, accumulating a WAL chain, then breaking it at upgrade and restarting is operationally messy. Set up WAL-G after the upgrade is complete and verified.

### Pre-upgrade checklist

```bash
# 1. Confirm current production cluster version and status.
pg_lsclusters
psql -U postgres -c "SELECT version();"

# 2. Confirm disk space. pg_upgradecluster initializes a NEW data directory
#    and copies/converts data into it. You need free disk space approximately
#    equal to the size of the existing data directory.
df -h /var/lib/postgresql/
du -sh /var/lib/postgresql/14/main/

# 3. Take a full pg_dump backup before the upgrade.
#    This is your last-resort rollback option.
#    Use directory format for completeness; this will take time for 200GB.
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump \
  -U postgres \
  -Fd \
  -j 4 \
  -Z 6 \
  -f "/var/backups/cnf/pre_upgrade_${DATE}" \
  cogdb
echo "Pre-upgrade dump complete: $(du -sh /var/backups/cnf/pre_upgrade_${DATE})"

# 4. Install postgresql-18 package if not already installed.
sudo apt update
sudo apt install postgresql-18

# 5. Verify pg_lsclusters now shows a 18/main cluster (created by package install).
#    If it exists and is empty, pg_upgradecluster will upgrade into it.
#    If you want pg_upgradecluster to create a fresh cluster, drop this one:
pg_lsclusters
# If 18/main exists and is unwanted:
# sudo pg_dropcluster --stop 18 main

# 6. Stop all application traffic to the database.
#    pg_upgradecluster requires the source cluster to be stopped.
#    Coordinate with WildFly: stop the WildFly service to prevent new connections.
sudo systemctl stop wildfly
# Or whatever the WildFly service is named. Verify no connections remain:
psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'cogdb';"
# Should return 0 after WildFly stops.

# 7. Note the postgresql.conf customizations on the PG 14 cluster.
#    pg_upgradecluster copies configuration files, but verify afterward.
cat /etc/postgresql/14/main/postgresql.conf | grep -v "^#" | grep -v "^$"
```

### The upgrade command

```bash
# pg_upgradecluster performs an in-place upgrade of the data directory.
# Under the hood it uses pg_upgrade, PostgreSQL's official upgrade tool.
#
# Arguments:
#   14         — the source major version
#   main       — the source cluster name
#   18         — the target major version
#
# What it does:
#   1. Starts a fresh PG 18 cluster (or uses the existing 18/main if present)
#   2. Runs pg_upgrade to convert data files from PG 14 format to PG 18 format
#   3. Copies postgresql.conf, pg_hba.conf, and other config files
#   4. Reassigns the port: the new PG 18 cluster takes port 5432,
#      the old PG 14 cluster is moved to a different port (e.g., 5433)
#   5. The PG 14 cluster is left intact but stopped — rollback is possible
#      by stopping PG 18 and restarting PG 14 on its original port
#
# --link flag (optional, not used here):
#   --link uses hard links instead of copying data files, making the upgrade
#   nearly instantaneous but making rollback impossible (the old cluster's
#   data files are now shared with the new cluster and will be modified).
#   Do NOT use --link unless you are confident in the upgrade and accept
#   no-rollback. For a first upgrade, copy mode (default) is safer.
#
# This command will take time proportional to database size.
# For 200GB, expect 20-60 minutes depending on VPS I/O throughput.

sudo pg_upgradecluster 14 main 18

# pg_upgradecluster output will narrate its progress.
# Watch for any ERROR lines. A successful run ends with:
# "Success. Please check that the upgraded cluster works. If it does,
#  you can remove the old cluster with 'pg_dropcluster 14 main'."
```

### Post-upgrade verification

```bash
# 1. Confirm the new cluster is running on port 5432.
pg_lsclusters
# Expected:
# 14  main  5433  down    postgres  /var/lib/postgresql/14/main  ...
# 18  main  5432  online  postgres  /var/lib/postgresql/18/main  ...

# 2. Confirm the server version.
psql -U postgres -p 5432 -c "SELECT version();"
# Must show: PostgreSQL 18.x ...

# 3. Verify cogdb exists and is accessible.
psql -U postgres -p 5432 -d cogdb -c "\dt public.*"
# Should list all expected tables.

# 4. Spot-check row counts on critical tables.
psql -U postgres -p 5432 -d cogdb -c "
  SELECT schemaname, tablename, n_live_tup
  FROM pg_stat_user_tables
  ORDER BY n_live_tup DESC
  LIMIT 20;"

# 5. Check for any post-upgrade warnings.
# pg_upgrade logs to the current working directory during the upgrade.
# pg_upgradecluster typically runs from /var/lib/postgresql.
ls /var/lib/postgresql/*.txt 2>/dev/null
# Files like pg_upgrade_internal.log, analyze_new_cluster.sh may be present.
# The analyze script runs ANALYZE on the new cluster — run it:
sudo -u postgres /var/lib/postgresql/analyze_new_cluster.sh

# 6. Review postgresql.conf on the new cluster.
#    pg_upgradecluster copies the PG 14 config, but verify key settings:
grep -E "^(wal_level|archive_mode|archive_command|archive_timeout|port|max_connections|shared_buffers)" \
  /etc/postgresql/18/main/postgresql.conf
# Confirm port = 5432 and that archive_mode is 'on' if WAL-G is configured.

# 7. Restart WildFly and confirm the application connects.
sudo systemctl start wildfly
# Monitor application logs for connection errors.
# WildFly's JDBC datasource targets port 5432; it should connect to PG 18
# without configuration changes.

# 8. Run the WildFly health check or load a test page to confirm end-to-end function.
```

### Establish fresh WAL-G archive after upgrade

```bash
# After confirming PG 18 is running correctly, immediately establish
# a new WAL-G base backup. This starts the fresh WAL archive chain
# under PG 18. Do this before the first production transaction on the
# new cluster if possible — or at minimum within the same maintenance window.

# Ensure WAL-G environment is configured for PG 18 data directory:
# PGDATA must point to /var/lib/postgresql/18/main in wal-g.env or
# the backup-push command.

sudo -u postgres wal-g backup-push /var/lib/postgresql/18/main

# Verify the backup appears in B2:
sudo -u postgres wal-g backup-list

# Verify WAL archiving is running:
psql -U postgres -p 5432 -c "SELECT * FROM pg_stat_archiver;"
# archived_count should increment; failed_count should be 0.
```

### Post-upgrade cleanup

**Wait at least 48–72 hours after the upgrade before dropping the old cluster.** This gives time to discover any application issues that would require rollback. Only drop when you are confident the PG 18 cluster is stable.

```bash
# Rollback path (before dropping PG 14):
# sudo pg_ctlcluster 18 main stop
# sudo pg_ctlcluster 14 main start
# Then update port in PG 14 config back to 5432 if needed.

# After confirming PG 18 is stable, drop the old cluster:
sudo pg_dropcluster --stop 14 main

# Remove the old package (optional):
sudo apt remove --purge postgresql-14

# Verify only PG 18 remains:
pg_lsclusters
ls /var/lib/postgresql/
# Should show only 18/ directory.

# Remove the pre-upgrade pg_dump from VPS (space reclamation).
# Ensure you have transferred it to the WD drive first.
# rm -rf /var/backups/cnf/pre_upgrade_<DATE>
```

---

## Routine cluster management commands

### Checking cluster status

```bash
# Full cluster inventory with status:
pg_lsclusters

# Detailed status for a specific cluster:
sudo pg_ctlcluster 18 main status

# Check PostgreSQL log for errors:
sudo tail -f /var/log/postgresql/postgresql-18-main.log

# Check active connections to cogdb:
psql -U postgres -c "
  SELECT pid, usename, application_name, client_addr, state, query_start
  FROM pg_stat_activity
  WHERE datname = 'cogdb'
  ORDER BY query_start;"
```

### Configuration reload vs. restart

Not all `postgresql.conf` changes require a full restart. Some take effect with a reload (SIGHUP):

```bash
# Reload configuration without restarting (for parameters that support it):
sudo pg_ctlcluster 18 main reload
# Equivalent to: psql -U postgres -c "SELECT pg_reload_conf();"

# Full restart (required for parameters like wal_level, archive_mode, port):
sudo pg_ctlcluster 18 main restart

# Which parameters require restart vs. reload?
psql -U postgres -c "
  SELECT name, context
  FROM pg_settings
  WHERE context IN ('postmaster', 'sighup')
  AND name IN ('wal_level','archive_mode','archive_command','archive_timeout',
               'max_connections','shared_buffers','port')
  ORDER BY context, name;"
# context='postmaster': requires full restart
# context='sighup': takes effect on reload
```

### Checking disk space used by cluster

```bash
# Data directory size (the raw PostgreSQL files):
du -sh /var/lib/postgresql/18/main/

# Per-database sizes via SQL (more accurate, includes TOAST):
psql -U postgres -c "
  SELECT datname,
         pg_size_pretty(pg_database_size(datname)) AS size
  FROM pg_database
  ORDER BY pg_database_size(datname) DESC;"

# Per-table sizes within cogdb:
psql -U postgres -d cogdb -c "
  SELECT schemaname,
         tablename,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
         pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)
           - pg_relation_size(schemaname||'.'||tablename)) AS index_size
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog','information_schema')
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  LIMIT 20;"
# pg_total_relation_size: table + all indexes + TOAST
# pg_relation_size: table data pages only
# The difference is index + TOAST size.
```

### Checking WAL directory size (WAL storm early warning)

```bash
# Monitor pg_wal/ size — should remain stable during normal operation.
# Rapid growth indicates archive_command is failing and segments are
# accumulating. This is the leading indicator of a WAL storm.
du -sh /var/lib/postgresql/18/main/pg_wal/

# Check archiver status:
psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
# Key fields:
#   archived_count: total segments successfully archived (should increase over time)
#   failed_count:   segments that failed archiving (any non-zero value is an alert condition)
#   last_failed_wal:  the WAL segment that most recently failed
#   last_failed_time: when the last failure occurred
#   last_archived_wal:  most recently successfully archived segment
#   last_archived_time: when the last successful archive completed
```

---

## Known issues and notes

- **`psql --version` vs server version:** The wrapper at `/usr/bin/psql` reports the client binary version, not the connected server version. Always use `SELECT version();` or `pg_lsclusters` to confirm the running server version. This has caused confusion previously.
- **Multiple stale clusters:** The presence of clusters for versions 13, 15, 16 on the production VPS is historical artifact. Remove them during the next maintenance window per the procedure above.
- **PG 14 EOL November 2026:** The 14→18 upgrade is time-constrained. It should be completed before the October 2026 maintenance window to allow a buffer before EOL.
- **WAL-G/upgrade ordering:** Do not set up WAL-G continuous archiving on PG 14 if the upgrade is imminent. Establish WAL-G after the PG 18 cluster is running and verified.
- **Target bumped from 17 to 18 (2026-09-07):** This document originally targeted PostgreSQL 17. PostgreSQL 18 (already at 18.6) is now current and there is no reason to stage through 17 — `pg_upgradecluster`/`pg_upgrade` jumps directly from 14 to 18. All commands above were updated accordingly; re-verify PostGIS's PG18 compatibility (see `cnf-backup-strategy.md` ground-truth findings) before scheduling the maintenance window.
