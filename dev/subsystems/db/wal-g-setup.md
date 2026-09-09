---
title: WAL-G Setup — Installation and Backblaze B2 Configuration
description: Step-by-step how-to for installing WAL-G on the production VPS, configuring Backblaze B2 as the WAL archive target, modifying postgresql.conf, pushing the initial base backup, establishing the cron schedule, and verifying the archive is healthy. Run this procedure after the PostgreSQL 14→18 upgrade is complete and verified.
published: true
date: 2026-09-07
tags: [walg, backup, postgresql, backblaze, infrastructure, disaster-recovery]
editor: markdown
dateCreated: 2026-09-07
---

# WAL-G Setup — Installation and Backblaze B2 Configuration

## Prerequisites and ordering constraints

**Complete these before starting this procedure:**

- [ ] PostgreSQL 14→18 upgrade complete and PG 18 cluster verified (see `postgresql-cluster-hygiene.md`)
- [ ] PG 18 cluster running on port 5432, `cogdb` accessible
- [ ] Backblaze account created and B2 Cloud Storage enabled
- [ ] Outbound HTTPS from the VPS is unblocked (WAL-G uploads to B2 over HTTPS port 443)

**Why after the upgrade:** WAL segments produced by PostgreSQL 14 cannot be replayed against a PostgreSQL 18 data directory. Setting up WAL-G archiving before the upgrade and then upgrading creates a broken archive chain. Establish the archive fresh against PG 18.

**Companion documents:**
- `cnf-backup-strategy.md` — why WAL-G, what WAL archiving is, S3/object storage primer
- `postgresql-cluster-hygiene.md` — upgrade procedure and cluster management
- `backup-restore-runbook.md` — how to use the archive to restore

---

## Part 1: Backblaze B2 setup

### 1.1 Create the B2 bucket

Log into the Backblaze console at `https://secure.backblaze.com/b2_buckets.htm`.

1. Click **Create a Bucket**
2. **Bucket Name:** `cnf-wal-archive` (must be globally unique across all B2 customers; prefix with something distinctive if taken, e.g., `trllc-cnf-wal-archive`)
3. **Files in Bucket:** Private (not public)
4. **Default Encryption:** Enabled (server-side AES-256; B2 manages keys)

**Why enable it despite the "excluded from snapshots" warning:** the B2 console warns that
enabling default encryption (SSE-B2) means encrypted files are excluded from future **Snapshots**
— a separate B2 web-console feature (Browse Files page) that bundles bucket contents into a
downloadable zip/tar archive. Per Backblaze's own docs (`cloud-storage-server-side-encryption`):
downloading files and creating snapshots run through additional infrastructure outside the normal
API path, and Backblaze deliberately doesn't extend that infrastructure access to encryption
keys — so encrypted objects can't feed either the console's direct-download links or its Snapshot
button. **This doesn't touch WAL-G at all.** WAL-G talks to B2 exclusively through the
S3-compatible API (`wal-g wal-push`/`wal-fetch`/`backup-push`/`backup-fetch`) — ordinary
authenticated API GET/PUT calls decrypt and encrypt SSE-B2 objects transparently, with zero extra
WAL-G configuration. The restore path documented in `backup-restore-runbook.md` never goes through
the console, so it's never affected by this exclusion.

Use **SSE-B2** (Backblaze-managed keys), not SSE-C (customer-managed keys): SSE-C requires
attaching your own encryption key to every single upload/download API call, which WAL-G has no
built-in support for, and losing an SSE-C key means Backblaze cannot recover that data — ever.
SSE-B2 needs no per-request key handling and costs nothing extra, and directly extends this
project's existing at-rest-encryption posture (see `cnf-backup-strategy.md`'s "Encrypt the drive
at rest" section for the local WD Elements drive) to the offsite copy as well.

**When you'd actually want a Snapshot:** it's a convenience for a one-off bulk export via the web
console — e.g., migrating the whole bucket to a different provider, or grabbing a full offline
copy without scripting anything. Nothing in this project's designed restore path depends on it. If
a bulk export is ever needed anyway, a scripted bulk download via `rclone` or the B2/S3 CLI (going
through the same API WAL-G uses) works against encrypted objects with no restriction — the
Snapshot button is Backblaze's own GUI convenience for that job, not the only way to do it.

5. **Object Lock:** Enabled

**Why Object Lock:** Object Lock prevents deletion or overwrite of objects for a defined retention period, even by an authenticated user with valid credentials. If the VPS is compromised and an attacker obtains the B2 application key, Object Lock prevents them from deleting your WAL archive. This is the primary ransomware mitigation for the cloud backup layer.

After bucket creation, set the default Object Lock mode:
- **Mode:** Compliance (stronger than Governance — even B2 support cannot delete locked objects within the retention window)
- **Retention period:** 30 days

This means any WAL segment or base backup uploaded to the bucket cannot be deleted for 30 days from upload, regardless of credentials presented.

### 1.2 Create a scoped application key

**Why a scoped key, not the master key:** The master account key has full access to all B2 buckets and account settings. If it is compromised, the attacker controls your entire B2 account. A scoped application key with minimum necessary permissions limits blast radius to the WAL archive bucket only.

In the Backblaze console, go to **App Keys → Add a New Application Key**:

1. **Name of Key:** `cnf-vps-wal-writer`
2. **Allow access to Bucket(s):** `cnf-wal-archive` (restrict to the specific bucket)
3. **Type of Access:** Read and Write
   - WAL-G needs write (to upload segments and base backups) and read (to list backups and verify uploads)
   - It also needs delete for `wal-g delete` retention management. If you want maximum protection and will run retention cleanup manually with the master key, you can restrict to Read and Write only and omit Delete here.
4. **Allow List All Bucket Names:** No (WAL-G does not need to enumerate other buckets)
5. **File Name Prefix:** Leave empty (WAL-G manages its own prefix structure within the bucket)
6. **Duration:** No expiration (or set a long expiration and rotate annually)

Record the **applicationKeyId** and **applicationKey** shown after creation. The `applicationKey` is shown exactly once — it cannot be retrieved again. Store it in a password manager immediately.

### 1.3 Note the B2 endpoint URL

In the bucket details, find the **Endpoint** field. It looks like:
```
s3.us-west-004.backblazeb2.com
```
The subdomain encodes your B2 region. This varies by account; use the value shown in your console, not the example here.

---

## Part 2: WAL-G installation on the VPS

All commands in this section run on the production VPS as a user with sudo access.

### 2.1 Download the WAL-G binary

WAL-G distributes pre-compiled binaries via GitHub Releases. The binary is statically linked — no dependencies beyond libc, no pip installs, no virtualenvs.

```bash
# Determine the current release version.
# Check https://github.com/wal-g/wal-g/releases for the latest tag.
# As of mid-2026, verify the current version before running.
WALG_VERSION="v3.0.3"
# Replace with the actual current release tag.

# Download the Linux AMD64 binary for PostgreSQL.
# WAL-G builds separate binaries per database; use the PostgreSQL one.
curl -L \
  # -L: follow redirects (GitHub Releases uses redirects to S3)
  "https://github.com/wal-g/wal-g/releases/download/${WALG_VERSION}/wal-g-pg-ubuntu-20.04-amd64.tar.gz" \
  -o /tmp/wal-g.tar.gz
# The filename convention may change between releases.
# Check the Assets list on the GitHub release page for the exact filename
# matching your Ubuntu version and architecture (amd64 for most VPS).

# Verify the download (compare against the checksum published on the release page):
sha256sum /tmp/wal-g.tar.gz
# Compare against the .sha256 file in the release Assets.

# Extract and install:
tar -xzf /tmp/wal-g.tar.gz -C /tmp/
# -x: extract
# -z: decompress with gzip
# -f: the archive file to extract from
# -C: extract into this directory

sudo mv /tmp/wal-g-pg /usr/local/bin/wal-g
# Rename to wal-g for convenience. The binary name in the archive
# is wal-g-pg to distinguish from wal-g-mysql, wal-g-mongo, etc.

sudo chmod +x /usr/local/bin/wal-g
# Ensure the binary is executable.

# Verify:
wal-g --version
# Should print the version string matching WALG_VERSION above.
```

### 2.2 Create the log directory

```bash
sudo mkdir -p /var/log/wal-g
sudo chown postgres:postgres /var/log/wal-g
# WAL-G runs as the postgres OS user (called by PostgreSQL's archive_command).
# The log directory must be writable by the postgres user.
```

### 2.3 Create the environment configuration file

WAL-G reads its configuration exclusively from environment variables. Storing these in a file rather than in `postgresql.conf` is critical: `postgresql.conf` is readable via `pg_settings` by any user who can connect to the database. Credentials in `postgresql.conf` are visible to application users.

```bash
sudo tee /etc/wal-g.env > /dev/null << 'EOF'
# WAL-G environment configuration for CodeNforce production cluster.
# This file contains credentials — restrict permissions accordingly.
# Sourced by the archive_command wrapper script (see wal-g-archive.sh below).

# S3 prefix: the bucket and path prefix where WAL-G stores all objects.
# Format: s3://<bucket-name>/<prefix>
# All WAL segments and base backups for this cluster are stored under this prefix.
# Do not share a prefix between different PostgreSQL clusters.
WALG_S3_PREFIX=s3://cnf-wal-archive/cogdb

# Backblaze B2 application key credentials.
# These are B2 credentials, not AWS credentials, but WAL-G uses the S3
# API and therefore uses AWS-named variables.
AWS_ACCESS_KEY_ID=your_b2_application_key_id_here
AWS_SECRET_ACCESS_KEY=your_b2_application_key_here

# B2's S3-compatible API endpoint.
# Replace with the endpoint shown in your B2 bucket details.
# The 004 portion encodes your B2 region — use the value from your console.
AWS_ENDPOINT_URL=https://s3.us-west-004.backblazeb2.com

# Compression algorithm for WAL segments and base backups.
# zstd achieves better compression ratios than gzip and is significantly
# faster, both for compression and decompression.
# Alternatives: lz4 (faster, worse ratio), lzma (better ratio, much slower),
#               brotli (good ratio, slower than zstd).
# zstd is the recommended default for most use cases.
WALG_COMPRESSION_METHOD=zstd

# Delta backup chain depth.
# With WALG_DELTA_MAX_STEPS=6, WAL-G takes up to 6 delta backups
# (capturing only changed data pages) before requiring a full base backup.
# On the 7th consecutive backup-push, a full backup runs automatically.
# Deltas reduce upload time and B2 storage cost significantly for databases
# where most data is stable (e.g., blobbytes is write-once; structural
# tables are small relative to total database size).
# Set to 0 to always take full base backups (simpler chain, more storage).
WALG_DELTA_MAX_STEPS=6

# PostgreSQL data directory — used by backup-push to know what to back up.
PGDATA=/var/lib/postgresql/18/main

# Connect to PostgreSQL as the postgres superuser.
# backup-push requires a database connection to call pg_backup_start/stop.
PGUSER=postgres
PGDATABASE=postgres
EOF

# Restrict permissions: readable by root and postgres only.
# The postgres user needs to read this file when archive_command runs.
sudo chown root:postgres /etc/wal-g.env
sudo chmod 640 /etc/wal-g.env
# 640: owner (root) read+write, group (postgres) read, others nothing.
```

### 2.4 Create the archive command wrapper script

`postgresql.conf`'s `archive_command` does not source environment files automatically. A small wrapper script sources `/etc/wal-g.env` before calling WAL-G.

```bash
sudo tee /usr/local/bin/wal-g-archive.sh > /dev/null << 'EOF'
#!/bin/bash
# Wrapper for WAL-G archive_command.
# Sources the environment configuration and calls wal-g wal-push.
# Called by PostgreSQL with %p replaced by the WAL segment path.

set -euo pipefail
# -e: exit immediately if any command fails (non-zero exit code)
# -u: treat unset variables as errors
# -o pipefail: if any command in a pipeline fails, the pipeline fails

# Source credentials and configuration.
# 'set -a' exports all subsequently defined variables automatically,
# making them available to child processes (wal-g binary).
set -a
source /etc/wal-g.env
set +a

# Call wal-g wal-push with the WAL segment path.
# $1 is the path passed by PostgreSQL's %p substitution.
exec /usr/local/bin/wal-g wal-push "$1" \
  >> /var/log/wal-g/archive.log 2>&1
EOF

sudo chmod +x /usr/local/bin/wal-g-archive.sh
sudo chown root:postgres /usr/local/bin/wal-g-archive.sh
```

Create a corresponding wrapper for restore:

```bash
sudo tee /usr/local/bin/wal-g-restore.sh > /dev/null << 'EOF'
#!/bin/bash
# Wrapper for WAL-G restore_command.
# Used during PITR recovery to fetch WAL segments from B2.
# Called by PostgreSQL with %f (filename) and %p (destination path).

set -euo pipefail
set -a
source /etc/wal-g.env
set +a

exec /usr/local/bin/wal-g wal-fetch "$1" "$2" \
  >> /var/log/wal-g/restore.log 2>&1
EOF

sudo chmod +x /usr/local/bin/wal-g-restore.sh
sudo chown root:postgres /usr/local/bin/wal-g-restore.sh
```

---

## Part 3: PostgreSQL configuration

Edit `/etc/postgresql/18/main/postgresql.conf`. The following parameters must be set or modified.

```bash
# Open the config file for editing:
sudo nano /etc/postgresql/18/main/postgresql.conf
# Or: sudo -u postgres psql -c "SHOW config_file;" to confirm path
```

Parameters to add or modify:

```ini
# Minimum WAL verbosity for archiving.
# 'minimal' (the default) records only enough for crash recovery — it does
# not include the information needed to reconstruct changes for archiving.
# 'replica' adds enough detail for WAL shipping and PITR. It is the minimum
# required value for archive_mode = on to work correctly.
# Changing wal_level requires a full PostgreSQL restart.
wal_level = replica

# Enable the archive_command hook.
# When 'on', PostgreSQL calls archive_command for each completed WAL segment
# before recycling it. 'off' (default) means WAL segments are recycled
# without being archived.
# Requires restart (postmaster-level parameter).
archive_mode = on

# The shell command PostgreSQL calls for each WAL segment ready to archive.
# %p is replaced with the full path to the segment file.
# PostgreSQL waits for exit code 0 before recycling the segment.
# Non-zero exit causes PostgreSQL to retain the segment and retry.
# The wrapper script sources credentials before calling wal-g.
archive_command = '/usr/local/bin/wal-g-archive.sh %p'

# Maximum time between WAL segment archives, even if the segment is not full.
# A 16MB WAL segment at low transaction volume could take hours to fill.
# archive_timeout forces a segment switch (and therefore an archive call)
# at least every N seconds, bounding the worst-case RPO.
# At 60 seconds: worst-case data loss is approximately 1 minute.
# Each forced segment is exactly 16MB regardless of how full it is.
# Storage cost: 16MB × (86400 / 60) = 1440 segments/day × 16MB ≈ 22GB/day
# of WAL at maximum archive_timeout frequency. At low write volume,
# actual WAL generation is much less; archive_timeout produces empty segments.
# zstd compresses empty-ish WAL segments well (~90% compression).
# Actual cost is well under $1/month.
# Requires reload only (sighup-level parameter).
archive_timeout = 60

# Store the restore_command here for reference.
# This is used during recovery, not during normal operation.
# It can be set here (PostgreSQL 12+) instead of in a recovery.conf file.
# Commented out during normal operation; uncomment only during a restore.
# restore_command = '/usr/local/bin/wal-g-restore.sh %f %p'
```

Apply the changes:

```bash
# wal_level and archive_mode require a restart:
sudo pg_ctlcluster 18 main restart

# Verify the restart succeeded:
pg_lsclusters
psql -U postgres -c "SELECT version();"

# Verify the archive parameters took effect:
psql -U postgres -c "
  SELECT name, setting
  FROM pg_settings
  WHERE name IN ('wal_level','archive_mode','archive_command','archive_timeout');"
```

---

## Part 4: Initial base backup

The first `backup-push` takes a full base backup of the entire PostgreSQL data directory and uploads it to B2. This is the foundation of the WAL archive chain — all WAL segments archived afterward can be used for PITR starting from this point.

```bash
# Run as the postgres OS user (who owns $PGDATA).
# The backup-push command:
#   1. Calls pg_backup_start() to tell PostgreSQL a backup is starting
#      (triggers a checkpoint and records the backup start LSN)
#   2. Archives the data directory contents to B2 in parallel
#   3. Calls pg_backup_stop() to record the backup end LSN
#   4. Uploads the backup manifest and stop-WAL file
#
# This runs against the live, running database — no downtime required.
# It uses a CHECKPOINT under the hood; expect brief I/O spike.
#
# For a 200GB database at typical VPS uplink speed, this takes 30-90 minutes.
# Run during a low-traffic window.

sudo -u postgres bash -c '
  set -a
  source /etc/wal-g.env
  set +a
  wal-g backup-push /var/lib/postgresql/18/main
' >> /var/log/wal-g/backup-push.log 2>&1

# Monitor progress:
tail -f /var/log/wal-g/backup-push.log

# Verify the backup appears in B2:
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-list
'
# Expected output shows the backup with its start/stop times, size, and LSN range.
# Example:
# name                          last_modified          wal_segment_backup_start  ...
# base_000000010000000000000003  2026-09-07T02:15:00Z  000000010000000000000003  ...
```

---

## Part 5: Automated cron schedule

Two cron jobs are needed: the regular base backup, and retention cleanup.

```bash
# Create the cron file for WAL-G scheduled jobs.
sudo tee /etc/cron.d/wal-g << 'EOF'
# WAL-G scheduled backup jobs for CodeNforce production database.
# WAL segments are archived continuously via archive_command in postgresql.conf.
# These cron jobs handle periodic base backups and retention management.

# Weekly full base backup: every Sunday at 02:00 UTC.
# WAL-G automatically determines whether to take a full or delta backup
# based on WALG_DELTA_MAX_STEPS. On Sunday it takes a full backup;
# subsequent daily runs (if added) take deltas until the step count is reached.
# Run as the postgres user who owns PGDATA.
0 2 * * 0 postgres . /etc/wal-g.env && /usr/local/bin/wal-g backup-push /var/lib/postgresql/18/main >> /var/log/wal-g/backup-push.log 2>&1

# Retention management: run after each backup-push (Sunday 03:00 UTC,
# after the backup-push window).
# 'delete retain FULL 4' keeps the 4 most recent full backups plus their
# delta chains and all WAL segments needed to restore any of them.
# WAL segments not needed by any retained backup are deleted from B2.
# --confirm is required; without it, wal-g delete runs in dry-run mode.
0 3 * * 0 postgres . /etc/wal-g.env && /usr/local/bin/wal-g delete retain FULL 4 --confirm >> /var/log/wal-g/delete.log 2>&1
EOF

# Verify cron is installed:
cat /etc/cron.d/wal-g
```

**Note on daily vs. weekly base backups:** Weekly base backups with continuous WAL archiving is appropriate for this workload. Daily base backups reduce restore time (less WAL to replay from a more recent anchor point) at the cost of more B2 storage and upload bandwidth. With a 200GB database and `WALG_DELTA_MAX_STEPS=6`, daily delta backups are small; only the Sunday full backup is large. A daily delta schedule can be added later if RTO needs tightening.

---

## Part 6: Verification

### 6.1 Verify WAL archiving is active

```bash
# pg_stat_archiver tracks archiving statistics.
# Run this a few minutes after the postgresql.conf restart.
psql -U postgres -c "SELECT
  archived_count,
  last_archived_wal,
  last_archived_time,
  failed_count,
  last_failed_wal,
  last_failed_time
FROM pg_stat_archiver;"

# Healthy state:
#   archived_count: a non-zero and increasing number
#   last_archived_time: recent (within the last archive_timeout seconds)
#   failed_count: 0
#   last_failed_wal: null
#
# Problem state:
#   failed_count > 0: archive_command is failing
#   last_archived_time: old (more than a few minutes ago): archiving has stalled
#   pg_wal/ directory growing: segments are accumulating (WAL storm risk)

# Monitor pg_wal/ size as a leading indicator:
du -sh /var/lib/postgresql/18/main/pg_wal/
# Normal: stable at a few hundred MB
# Problem: growing continuously toward GB scale
```

### 6.2 Verify the archive has no gaps

```bash
# wal-g wal-show inspects the WAL segment sequence in B2.
# It reports all timelines, associated backups, and checks for missing segments.
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g wal-show
'
# Output status:
#   OK: continuous WAL chain, no gaps. PITR is possible across the full range.
#   LOST_SEGMENTS: gap in the WAL sequence. PITR is not possible across the gap.
#                  Segments before the gap may still be restorable to a point
#                  within the pre-gap window.
```

### 6.3 Test a WAL segment archive manually

Before relying on the automated `archive_command`, manually invoke the wrapper to confirm it works end-to-end.

```bash
# Find a recent WAL segment to test with:
ls /var/lib/postgresql/18/main/pg_wal/ | head -5
# Note a segment filename, e.g.: 000000010000000000000005

# Manually invoke the archive wrapper (simulates what PostgreSQL does):
sudo -u postgres /usr/local/bin/wal-g-archive.sh \
  /var/lib/postgresql/18/main/pg_wal/000000010000000000000005

# Check the archive log for output:
cat /var/log/wal-g/archive.log

# Verify the segment appears in B2:
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g wal-show
'
```

### 6.4 Test the restore path (critical)

Verify that WAL segments can be fetched from B2. This tests the credentials, network path, and restore_command wrapper before you need them in an actual incident.

```bash
# Fetch a specific WAL segment from B2 to a temporary location:
SEGMENT="000000010000000000000005"
sudo -u postgres bash -c "
  set -a; source /etc/wal-g.env; set +a
  wal-g wal-fetch ${SEGMENT} /tmp/test_fetch_${SEGMENT}
"

# Verify the file was downloaded and is non-empty:
ls -lh /tmp/test_fetch_${SEGMENT}
rm /tmp/test_fetch_${SEGMENT}
# Clean up the test file.
```

---

## Part 7: B2 Object Lock configuration verification

After setup, verify that the Object Lock configuration on the bucket is enforced as intended.

In the Backblaze console:
1. Open the `cnf-wal-archive` bucket settings
2. Confirm **Object Lock** is shown as Enabled
3. Confirm **Default Retention** is set to Compliance mode, 30 days

Test immutability (optional, requires a throwaway object):
1. Upload a test file to the bucket via the console or B2 CLI
2. Attempt to delete it within the retention window — it should be rejected
3. After confirming, wait for the test object to expire naturally (30 days) or contact B2 support for early deletion of test objects

---

## Monitoring checklist (ongoing)

Add the following to whatever monitoring practice applies to the VPS:

| Check | Frequency | Healthy condition | Action if unhealthy |
|---|---|---|---|
| `pg_stat_archiver.failed_count` | Daily | 0 | Investigate `archive_command` failures; check `/var/log/wal-g/archive.log` |
| `pg_stat_archiver.last_archived_time` | Hourly | Within last 2 minutes | Archive may be stalled; check `pg_wal/` size |
| `pg_wal/` directory size | Hourly | Stable, <1GB | Growing size = archive backlog; risk of WAL storm |
| `wal-g backup-list` | Weekly | New backup present after cron window | Cron may have failed; check `/var/log/wal-g/backup-push.log` |
| `wal-g wal-show` | Weekly | Status: OK | LOST_SEGMENTS means a gap; PITR may be limited |
| B2 bucket size | Monthly | Growing as expected, within budget | Unexpected growth may indicate retention deletion failing |

---

## Operational notes

**Credential rotation:** The B2 application key stored in `/etc/wal-g.env` should be rotated annually or immediately if there is any reason to suspect compromise. To rotate: create a new application key in the B2 console with the same permissions, update `/etc/wal-g.env`, reload the cron environment (the file is sourced fresh on each cron run, so no service restart is needed for cron jobs; PostgreSQL's `archive_command` sources it via the wrapper script at each invocation, so no reload is needed there either).

**WAL-G binary updates:** When a new WAL-G release is published, update the binary by repeating the download and `mv` steps in Part 2. WAL-G is backward-compatible — a newer binary can read archives created by older versions. Test after each binary update by running `wal-g backup-list` and `wal-g wal-show` to confirm the new binary can read the existing archive.

**B2 egress costs:** Recovery operations that fetch WAL segments from B2 incur egress charges above the free 3× monthly average. For a 200GB database, 3× is 600GB of free monthly downloads — a full restore well within that. Multiple restores in a single month could exceed the free tier; at $0.01/GB the cost remains low (a 200GB restore costs $2.00 beyond the free tier).
