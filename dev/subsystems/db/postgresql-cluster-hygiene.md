---
title: PostgreSQL Cluster Hygiene — Inventory, Version Management, and Upgrade Procedure
description: Reference procedure for the Ubuntu multi-cluster PostgreSQL architecture, cluster inventory on the CodeNforce production VPS, cleanup of stale clusters, and the pg_upgradecluster 14→18 migration. Covers the PostGIS prerequisite and version constraint, the upgrade-method trade-off (copy vs link vs clone), automatic checksum handling, and the ordering constraint relative to WAL-G archiving setup.
published: true
date: 2026-09-13
tags: [postgresql, infrastructure, upgrade, cluster-management, ubuntu, postgis]
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

> **Where the plan lives.** This document is *procedure* — how to perform the operations. The
> live PG14→18 upgrade **campaign** (scope, sequencing, open questions, per-step status, the
> copy-vs-`--link` decision) is tracked in the `codenforce` repo, per the Dev↔Docs separation
> policy: `docs/subsystems/db/mw1-pg18-maintenance-window.md`, indexed from
> `docs/subsystems/db/db-index.md`. Do not add roadmap or status content here — it belongs there.

---

## Ubuntu's multi-version PostgreSQL architecture

### How PostgreSQL is packaged on Ubuntu

On Ubuntu, PostgreSQL is installed via packages from the PostgreSQL Global Development Group (PGDG) apt repository. Unlike most software where installing a new version replaces the old one, PostgreSQL major versions coexist as separate packages: `postgresql-14`, `postgresql-15`, `postgresql-16`, `postgresql-18` can all be installed simultaneously without conflict.

Each major version installs:
- Its own server binary (e.g., `/usr/lib/postgresql/18/bin/postgres`)
- Its own client binaries (e.g., `/usr/lib/postgresql/18/bin/psql`)
- Its own default configuration directory under `/etc/postgresql/<version>/`
- Its own default data directory parent under `/var/lib/postgresql/<version>/`

**The version in a path is the major version** (14, 15, 16, 17). PostgreSQL major versions are not backward-compatible at the data directory level — a PostgreSQL 14 server cannot read data files written by PostgreSQL 18.

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
# Example output: psql (PostgreSQL) 18.6
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

Expected stale entries — **inventoried and resolved 2026-09-13.** All four were confirmed to be
empty shells: each contained only `postgres`, `template0` and `template1` (the three databases
`initdb` creates) at roughly 7.5–8 MB, with no user databases of any kind. Cluster 15 was down and
so not inspectable over a socket; it was verified offline instead — 39 MB with exactly three
directories under `base/` (OIDs `1`, `4`, `5`). Dropped.

| Major version | Cluster name | Port | Status before | Contents | Action |
|---|---|---|---|---|---|
| 13 | main | 5433 | online | 3 system DBs only | Dropped 2026-09-13 |
| 15 | main | 5434 | down | 3 system DBs only (verified offline) | Dropped 2026-09-13 |
| 16 | main | 5435 | online | 3 system DBs only | Dropped 2026-09-13 |
| 17 | main | 5436 | online | 3 system DBs only | Dropped 2026-09-13 |

Two things worth carrying forward from that exercise:

- **Three of the four were *running*.** Idle postmasters each hold their own `shared_buffers`
  allocation, and five clusters across four ports is a genuine "which server did that `psql` just
  talk to?" hazard in the middle of a maintenance window. Space was never the issue — ~3 GB total.
- **A `live_connections` count of 1 on an idle cluster is usually the inventory query itself.**
  Counting `pg_stat_activity` rows with `backend_type = 'client backend'` includes the `psql`
  session doing the counting. Don't read it as evidence the cluster is in use.

**Package removal was deliberately deferred.** Dropping the clusters removes the operational
hazard; `apt remove --purge postgresql-13/15/16/17` is cosmetic, risks dragging uninventoried
dependencies, and is not something to run against production shortly before a major version
upgrade. It also would not reduce `pg_wrapper` ambiguity, since the wrapper selects the *highest*
installed version regardless.

**Do not remove the version 18 cluster before reading this.** As of 2026-09-13 **PostgreSQL 18 is
not installed on production at all** — there is no 18 cluster to keep or remove. Installing
`postgresql-18` will auto-create an empty `18/main` on the next free port, and
`pg_upgradecluster` **creates its own target cluster** and fails if one with that name already
exists. So the auto-created cluster must be **dropped**, not reused:

```bash
sudo apt install postgresql-18       # auto-creates an empty 18/main
pg_lsclusters                        # confirm it appeared
sudo pg_dropcluster --stop 18 main   # drop it; pg_upgradecluster makes its own
```

The stale PG17 cluster (if present) can be removed freely — it is not the upgrade target.

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
# 17 is no longer the upgrade target (18 is). Drop 17 freely:
sudo pg_dropcluster --stop 17 main
# Do NOT drop 18 main if it is your intended upgrade target —
# pg_upgradecluster will handle creating or using it.

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

PostgreSQL 18 is the current stable major version as of mid-2026. The upgrade brings performance improvements (logical replication, query planning, vacuum improvements), but the primary driver here is continued security patch coverage through approximately November 2029.

### The WAL-G ordering constraint

**This is the most important operational constraint in this procedure.**

WAL-G's continuous archive consists of two components: base backups and WAL segments. These form a chain — WAL segments are replayed starting from a base backup. A WAL segment generated by PostgreSQL 14 cannot be replayed against a PostgreSQL 18 data directory. After `pg_upgradecluster` runs, the data directory is a PostgreSQL 18 data directory.

**Implication:** Any WAL archive accumulated under PostgreSQL 14 cannot be used for PITR against the post-upgrade cluster. The upgrade creates a discontinuity in the WAL chain.

**Required ordering:**

1. Take a final `pg_dump` backup of the running PG 14 cluster (belt-and-suspenders).
2. Perform the upgrade — `pg_upgradecluster -v 18 -m upgrade ...`, see [The upgrade command](#the-upgrade-command) for the exact invocation.
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

# 2. Confirm disk space. THIS DECIDES THE UPGRADE METHOD.
#    In 'upgrade' (copy) mode, pg_upgradecluster initializes a NEW data
#    directory and copies data into it — you transiently hold two full copies,
#    so you need free space roughly equal to the existing data directory.
#    If you don't have it, 'link' mode is the alternative (no extra space,
#    but no rollback to the old cluster). See the method table below.
df -hT /var/lib/postgresql/
du -sh /var/lib/postgresql/14/main/
findmnt -no FSTYPE /var/lib/postgresql   # ext4 => 'clone' mode unavailable

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

# 4. Install postgresql-18 from PGDG.
#    The PGDG apt repository must be configured first — Ubuntu's own archive
#    does not carry PostgreSQL 18. See full-vps-catastrophic-recovery.md
#    Phase 2.1 for the repository setup commands.
sudo apt update
sudo apt install postgresql-18
#    And the matching PostGIS build — see the PostGIS section above.
#    This must be installed BEFORE pg_upgradecluster runs.
sudo apt install postgresql-18-postgis-3

# 5. Drop the empty 18/main cluster the package install just created.
#    pg_upgradecluster CREATES its own target cluster and fails if a cluster
#    of that version+name already exists. The auto-created one is not reused.
pg_lsclusters
sudo pg_dropcluster --stop 18 main

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

### PostGIS: a hard prerequisite, and a version constraint

**If the database uses PostGIS — and `cogdb` does — this section is not optional.** The most
common way a PostGIS cluster upgrade fails is skipping it.

PostGIS is not a portable schema object. It is a compiled shared library (`postgis-3.so`) built
against one specific PostgreSQL major version. `pg_upgrade` replays your schema into the new
cluster, and when it reaches `CREATE EXTENSION postgis` it must load that library **under the new
version**. If `postgresql-18-postgis-3` is not installed, the upgrade aborts.

**Version constraint** (PostGIS compatibility matrix, checked 2026-09-13):

| PostGIS series | PG18 | PG14 |
|---|---|---|
| 3.7 (beta) | works, supported | — |
| **3.6** (3.6.4, 2026-06-08) | **works, supported** | works (limited: GiST bulk index build sort is PG15+ only) |
| 3.5 | *compatible, not a recommended target* | works, supported |
| 3.4 and older | not a recommended target | works, supported |

**PostGIS 3.6 is the only stable series supported on PG18**, and it also runs on PG14. That
overlap is what makes a safe path possible: move both sides onto the same PostGIS version *before*
the cluster upgrade, so the extension and the server aren't changing versions simultaneously.

**Order matters — do not rearrange:**

```bash
# 1. Check what you're actually on.
psql -U postgres -d cogdb -c "SELECT postgis_full_version();"

# 2. Upgrade PostGIS to 3.6 on the CURRENT (PG14) cluster, from PGDG.
sudo apt install postgresql-14-postgis-3
#    Then, in every spatial database:
psql -U postgres -d cogdb -c "SELECT postgis_extensions_upgrade();"
psql -U postgres -d cogdb -c "SELECT postgis_full_version();"   # confirm 3.6.x

# 3. Install the matching PostGIS build for the TARGET version.
#    This must happen BEFORE pg_upgradecluster runs — both so pg_upgrade can
#    load the library, and so the PostGIS upgrade hook in
#    /etc/postgresql-common/pg_upgradecluster.d/ is present to run.
sudo apt install postgresql-18-postgis-3

# 4. ...now run the cluster upgrade (below).

# 5. After the upgrade, repoint the extension at the new library:
psql -U postgres -p 5432 -d cogdb -c "SELECT postgis_extensions_upgrade();"
psql -U postgres -p 5432 -d cogdb -c "SELECT postgis_full_version();"
```

**Objects in `cogdb` that depend on this working:** the `mapping.parceldatamap` materialized view
and a generated column on `external_wprdc.wprdcparcelboundaries`. Verify both after the upgrade,
not just that `CREATE EXTENSION` succeeded.

### PG18-specific: data checksums are handled automatically

PostgreSQL 18 changed the `initdb` default to **enable data checksums**, and `pg_upgrade`
requires the source and target clusters to have **matching checksum settings** — a mismatch
aborts the upgrade before any data is touched. Your PG14 cluster was initialized without
checksums (the PG14 default), so on paper this is a compatibility problem.

**Under `pg_upgradecluster` it isn't one.** The man page states plainly: *"The new cluster is set
up to use data page checksums if the old cluster uses them."* The wrapper reads the source
cluster's setting and initializes the target to match. No flag is needed, and the wrapper does
not accept a `--` passthrough to `initdb` anyway.

The checksum-mismatch concern is real **only** if you bypass the wrapper and drive raw
`pg_upgrade` against a target you `initdb`'d by hand. Don't do that; use the wrapper.

**Verify the source setting anyway**, so you know what you're landing on:
```bash
psql -U postgres -c "SHOW data_checksums;"
# Expect: off (the PG14 default)
```

If you want checksums enabled afterward, that's a **separate follow-up task**, not part of the
upgrade: `pg_checksums --enable -D /var/lib/postgresql/18/main` on a stopped cluster. It rewrites
every data page (~30–90 minutes for 200 GB), so give it its own maintenance window rather than
bolting it onto this one.

### The upgrade command

`pg_upgradecluster` is Debian/Ubuntu's wrapper around the upgrade process. Its synopsis is:

```
pg_upgradecluster [-v newversion] oldversion name [newdatadir]
```

**Read that carefully — two details bite hard:**

**1. The target version is `-v`, not a positional argument.** The third positional slot is
`newdatadir`. So `pg_upgradecluster 14 main 18` does *not* mean "upgrade 14/main to 18" — it means
"upgrade 14/main to the newest installed version, using a data directory called `18`". Always
write `-v 18`.

**2. The default method is `dump`, not `pg_upgrade`.** From the man page:
`-m, --method=dump|upgrade|link|clone` … **"The default is dump."** The `dump` method runs a full
`pg_dump` + `pg_restore` cycle, which on a 200 GB database takes many hours. `pg_upgrade` mode
converts the cluster in place and is what you almost certainly want. **The method must always be
passed explicitly** — never rely on the default.

| Method | Mechanism | Disk needed | Speed | Rollback |
|---|---|---|---|---|
| `dump` *(default!)* | `pg_dump`/`pg_restore` | space for the dump | slowest by far | old cluster intact |
| `upgrade` | `pg_upgrade`, copying data files | ≈ size of the database | I/O-bound (tens of minutes to hours) | **old cluster intact** |
| `link` | `pg_upgrade` with hard links | negligible | minutes, size-independent | **none** — clusters share data files; the old one is unusable afterward |
| `clone` | `pg_upgrade` with reflinks | negligible | minutes | old cluster intact | 

`clone` requires a copy-on-write filesystem (XFS with `reflink=1`, or btrfs). On ext4 it is
unavailable — check with `findmnt -no FSTYPE /var/lib/postgresql` before planning around it.

**Choosing between `upgrade` and `link` is a disk-space decision.** If free space comfortably
exceeds the database size, use `upgrade` and keep the in-place rollback. If it doesn't, `link` is
the standard choice at large sizes, but it is only safe with a **verified-restorable** pre-upgrade
dump, because that dump becomes your only way back.

There is a third option, and for this cluster it is the one that applies: **keep copy mode, and
put the *new* cluster somewhere with room.** The `[newdatadir]` positional argument exists exactly
for that. The PG14 data directory is 95 GB against ~76 GB free on the droplet, so a same-disk copy
does not fit; a temporary DigitalOcean block volume supplies the space without a permanent —
and irreversible — droplet disk resize.

```bash
# ---------------------------------------------------------------------------
# THE COMMAND FOR THIS CLUSTER (2026-09-13). Copy mode, new cluster on the
# attached block volume. PG14 is never touched, so rollback stays intact.
#
#   -v 18             target major version (NOT a positional argument)
#   -m upgrade        use pg_upgrade (NOT the 'dump' default)
#   --keep-on-error   leave the failed new cluster in place to inspect
#                     (default behaviour is to delete it)
#   -j 4              parallel jobs, passed through to pg_upgrade
#   14 main           source version and cluster name
#   /mnt/...          [newdatadir] — where the NEW cluster is created.
#                     Omit it and pg_createcluster defaults to
#                     /var/lib/postgresql/18/main on the droplet's root disk,
#                     which does not have room for a 95 GB copy.
# ---------------------------------------------------------------------------
sudo pg_upgradecluster -v 18 -m upgrade --keep-on-error -j 4 \
     14 main /mnt/vol_pg18data/pgdata/18/main

# The volume must already be mounted, and the PGDATA parent must exist and be
# owned by postgres — but do NOT pre-create the final 'main' directory:
# pg_createcluster creates it and fails if it already exists.
#   sudo mkdir -p /mnt/vol_pg18data/pgdata/18
#   sudo chown -R postgres:postgres /mnt/vol_pg18data/pgdata
#   sudo chmod 700 /mnt/vol_pg18data/pgdata
#   findmnt /mnt/vol_pg18data      <- MUST return a row before proceeding

# ---------------------------------------------------------------------------
# Variants, for reference — not what we run here.
# ---------------------------------------------------------------------------
# Copy mode onto the default location, when the root disk has room:
# sudo pg_upgradecluster -v 18 -m upgrade --keep-on-error -j 4 14 main
#
# Hard-link mode — when free disk space is insufficient and no volume is
# available. Equivalent to '-m upgrade --link'. There is no going back to the
# PG14 cluster after this; the two clusters share physical data files.
# Note --link cannot be combined with a newdatadir on another filesystem,
# because hard links cannot cross filesystems.
# sudo pg_upgradecluster -v 18 -m link --keep-on-error -j 4 14 main
```

**What the wrapper does for you**, beyond running `pg_upgrade`:

- Copies `postgresql.conf`, `pg_hba.conf`, and friends from the old cluster and adjusts them.
- Matches the new cluster's data-checksum setting to the old cluster's (see above).
- Moves the old cluster to a spare port and gives the new cluster the original port (5432), so
  clients need no reconfiguration. Override with `--keep-port` if you don't want that.
- Sets the old cluster to **manual** startup mode, so a reboot won't silently start it alongside
  the new one. It remains fully intact as your rollback (in `upgrade`/`clone`/`dump` modes).
- Runs extension upgrade hooks from `/etc/postgresql-common/pg_upgradecluster.d/` — the mechanism
  the man page describes as existing **specifically for extensions like PostGIS**, which need
  auxiliary metadata initialized fresh for the new version rather than copied over. See the
  PostGIS prerequisite section above: those hooks ship with the PostGIS packages, so the PG18
  PostGIS package must be installed *before* this command runs.

A successful run ends with: *"Success. Please check that the upgraded cluster works. If it does,
you can remove the old cluster with 'pg_dropcluster --stop 14 main'."*

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

# Refresh planner statistics.
# NOTE: the analyze_new_cluster.sh script that older guides reference was
# removed from pg_upgrade in PostgreSQL 14. The current equivalent is:
sudo -u postgres vacuumdb --all --analyze-in-stages
# --analyze-in-stages runs three increasingly thorough passes, so usable
# statistics exist within seconds rather than after the full run completes.
# PG18 carries planner statistics across pg_upgrade for the first time, so
# this may be less critical than it once was — but skipping it is the classic
# cause of "the upgrade worked, yet everything is mysteriously slow."
# Check first whether pg_upgradecluster already ran an analyze pass.

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
- **PG 14 EOL November 2026:** The 14→18 upgrade is time-constrained. It should be completed before the October 2026 maintenance window to allow a buffer before EOL. PG18 is supported until approximately November 2030.
- **PG18 data checksum default change:** PostgreSQL 18 enables data checksums by default at `initdb` time and `pg_upgrade` requires matching settings — but `pg_upgradecluster` matches the target to the source automatically, so no flag is needed. Earlier revisions of this document recommended a `-- --no-data-checksums` passthrough; that syntax is not supported by the wrapper and the advice was unnecessary. See the checksum section above.
- **`pg_upgradecluster` argument order:** the target version is `-v 18`, not a third positional argument. `pg_upgradecluster 14 main 18` silently treats `18` as a *data directory path*. Earlier revisions of this document had this wrong.
- **`pg_upgradecluster` defaults to `-m dump`:** not `pg_upgrade`. On a 200 GB database the default method means a multi-hour `pg_dump`/`pg_restore` cycle. Always pass the method explicitly.
- **PostGIS packages must be installed for the target version before upgrading:** `postgresql-18-postgis-3`. Missing it aborts the upgrade and also means the PostGIS upgrade hook in `/etc/postgresql-common/pg_upgradecluster.d/` is absent. PostGIS 3.6 is the only stable series supported on PG18.
- **PG18 "LTS" terminology:** PostgreSQL does not use an LTS designation. All major versions receive five years of support. PG18 is the current stable major release with support through ~November 2030.
- **WAL-G/upgrade ordering:** Do not set up WAL-G continuous archiving on PG 14 if the upgrade is imminent. Establish WAL-G after the PG 18 cluster is running and verified.
- **Post-upgrade ANALYZE:** the `analyze_new_cluster.sh` script referenced by older guides was removed from `pg_upgrade` in PostgreSQL 14; use `vacuumdb --all --analyze-in-stages` instead. PG18 improved statistics persistence across upgrades, but running ANALYZE explicitly remains best practice to avoid query planner regressions in the period immediately after cutover.
