---
title: Backup Restore Runbook — Incident Response Fast Path
description: Operational runbook for restoring the CodeNforce production database. Covers three recovery scenarios in order of preference — WAL-G PITR from Backblaze B2, pg_dump restore from the WD Elements drive, and DO droplet snapshot restore. Optimized for use under incident conditions.
published: true
date: 2026-09-07
tags: [backup, restore, incident-response, postgresql, walg, disaster-recovery, runbook]
editor: markdown
dateCreated: 2026-09-07
---

# Backup Restore Runbook — Incident Response Fast Path

## How to use this document

This is a procedural runbook. Read it before you need it — not for the first time during an incident. The goal is that under stress, you can open this document and execute each numbered step without having to make architectural decisions.

**Read the decision tree first. Execute the scenario that matches.**

> ### ⚠ `$PGDATA` is currently NOT `/var/lib/postgresql/18/main`
>
> Every `PGDATA` path printed in this runbook is the packaged default. On the production host
> today the PG18 cluster lives on a DigitalOcean block volume:
>
> ```
> /mnt/vol_pg18data/pgdata/18/main
> ```
>
> **Substitute that path wherever this document says `/var/lib/postgresql/18/main`** — with one
> exception: Scenario C and the full-VPS rebuild construct a *new* host, where the packaged
> default is correct and the volume may not exist at all.
>
> Do not restore from memory. Take two seconds first:
>
> ```bash
> pg_lsclusters          # the 'Data directory' column is authoritative
> ```
>
> This is a temporary state — the cluster moves back to local disk after the PG18 soak period,
> at which point this callout should be deleted rather than edited.

> ### ⚠ WAL-G is configured by a YAML file now, not `/etc/wal-g.env`
>
> Every WAL-G command below still uses the superseded form:
>
> ```bash
> sudo -u postgres bash -c 'set -a; source /etc/wal-g.env; set +a
>   wal-g <command>'
> ```
>
> **`/etc/wal-g.env` does not exist.** Configuration lives in `/etc/wal-g/wal-g.yaml` and is passed
> explicitly. The substitution is mechanical — drop the `bash -c` sourcing wrapper entirely and add
> `--config`:
>
> ```bash
> sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml <command>
> ```
>
> `--config` is a global flag, so it goes **before** the subcommand. See `wal-g-setup.md` §2.3–2.4
> for why. **This document has not yet been swept**; the conversion is tracked in the `codenforce`
> repo as F13 and must land before the first restore drill.

---

## Severity and notification

Before starting any restore procedure, make two decisions:

1. **Is this a data loss event or a service availability event?** Data loss (records deleted or corrupted) requires a different response than availability loss (VPS down, can't connect). Both are covered here, but the urgency differs.

2. **Who needs to know?** At minimum, notify TCVCOG point of contact that a restore is in progress, with an estimated time to service restoration. Do not wait until the restore is complete to notify.

---

## Recovery scenario decision tree

```
Is the VPS reachable via SSH?
│
├─ NO → Go to Scenario C (DO snapshot restore)
│        The VPS or its disk is gone or unrecoverable.
│
└─ YES → Is the PostgreSQL service running?
         │
         ├─ NO → Is this a disk/OS issue, or a PostgreSQL-only issue?
         │        │
         │        ├─ Disk/OS issue → Scenario C (DO snapshot)
         │        └─ PostgreSQL only → Scenario A (WAL-G PITR) or B
         │
         └─ YES → Is data missing or corrupted in the database?
                  │
                  ├─ NO → PostgreSQL is running and data is intact.
                  │        This is not a restore scenario. Check application logs.
                  │
                  └─ YES → Do you know approximately WHEN the corruption occurred?
                            │
                            ├─ YES → Scenario A (WAL-G PITR to a specific time)
                            │         Minimizes data loss to the corruption moment.
                            │
                            └─ NO → Can you reach Backblaze B2?
                                    │
                                    ├─ YES → Scenario A (restore to latest clean backup)
                                    └─ NO → Scenario B (WD Elements drive)
```

---

## Common pre-restore steps

Run these before executing any scenario. They establish baseline facts needed for all restore paths.

```bash
# --- Step P1: Record the incident start time ---
date -u
# Note this timestamp. It establishes the outer bound of data loss
# and is needed for incident documentation.

# --- Step P2: Confirm what is broken ---
# Check if PostgreSQL is running:
pg_lsclusters

# Check if cogdb is reachable:
psql -U postgres -p 5432 -d cogdb -c "SELECT now();" 2>&1

# Check disk space on the VPS:
df -h /var/lib/postgresql/

# --- Step P3: Check the WAL archive status (if PostgreSQL is running) ---
psql -U postgres -c "SELECT
  archived_count,
  last_archived_wal,
  last_archived_time,
  failed_count
FROM pg_stat_archiver;" 2>&1
# Record last_archived_wal and last_archived_time.
# This tells you the latest point to which WAL-G PITR can recover.

# --- Step P4: Check what WAL-G base backups are available ---
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-list
' 2>&1
# Record the backup names and their timestamps.
# The most recent full backup is the starting anchor for PITR.

# --- Step P5: Note the WD Elements drive status ---
lsblk -f | grep sda
# Is the drive connected and mounted?
# If not connected: is it physically accessible? Who has it?
```

---

## Scenario A: WAL-G PITR restore from Backblaze B2

**Use when:** Data is corrupted or missing, WAL archive is intact on B2, and you know (approximately) when the corruption occurred.

**What this gives you:** The database state at any second from the earliest retained base backup up to `last_archived_wal`. Data committed after `last_archived_wal` is lost.

**Estimated time:** 30 minutes to several hours, depending on base backup size (~200GB) and how many WAL segments must be replayed from the anchor point to the recovery target.

### A1: Determine the recovery target time

```bash
# What time did the corruption/loss event occur?
# Options for establishing this:

# Option 1: You know the approximate time from user reports or application logs.
# Convert to UTC: date -u -d "2026-09-07 14:30:00 EDT"
# Use a timestamp 1-2 minutes BEFORE the reported corruption time as the target.

# Option 2: Inspect the WAL-G archive for the latest usable backup.
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-list --detail
'
# --detail shows the backup start/stop LSN and associated WAL segment names.
# Use this to identify a backup taken before the corruption event.

# Option 3: No specific time known — restore to latest available WAL.
# In this case, recovery_target_action will be 'promote' with no time specified,
# which replays all available WAL.
# Note: if the corruption is in the WAL stream itself (e.g., data was committed
# and committed correctly, but is logically wrong), replaying all WAL reproduces
# the corruption. In that case you MUST specify a target time before the event.
```

### A2: Prepare the recovery environment

**Decide: restore to the existing VPS or a new VPS?**

- **Existing VPS:** Faster (no provisioning), but you are overwriting the production data directory. There is no rollback path after step A4.
- **New VPS:** Safer — the production data directory is untouched until you verify the restore. Slower (provisioning time). Recommended if time allows.

For a new VPS:
1. Create a new DigitalOcean droplet (Ubuntu, same region, same or larger disk)
2. Install PostgreSQL 18: `sudo apt update && sudo apt install postgresql-18`
3. Install WAL-G binary (see `wal-g-setup.md` Part 2)
4. Copy `/etc/wal-g.env` to the new VPS
5. Continue from step A3 on the new VPS

For the existing VPS (in-place restore):

```bash
# Stop WildFly to prevent new connections:
sudo systemctl stop wildfly

# Stop PostgreSQL:
sudo pg_ctlcluster 18 main stop

# Verify PostgreSQL has stopped:
pg_lsclusters
# Status should show 'down'

# Rename the existing data directory as a temporary backup.
# This preserves the corrupted data in case you need to inspect it,
# and gives you a rollback option if the restore fails.
# WARNING: this doubles the disk space used. Check df -h first.
sudo mv /var/lib/postgresql/18/main /var/lib/postgresql/18/main.corrupted.$(date +%Y%m%d%H%M%S)

# Create a fresh, empty data directory for the restore target:
sudo mkdir -p /var/lib/postgresql/18/main
sudo chown postgres:postgres /var/lib/postgresql/18/main
sudo chmod 700 /var/lib/postgresql/18/main
# PostgreSQL requires PGDATA to be owned by postgres and mode 700.
```

### A3: Restore the base backup

```bash
# wal-g backup-fetch restores the base backup to the data directory.
# 'LATEST' fetches the most recent base backup.
# Replace 'LATEST' with a specific backup name (from backup-list)
# if you need to restore from an older base backup.
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-fetch /var/lib/postgresql/18/main LATEST
' 2>&1 | tee /var/log/wal-g/restore-$(date +%Y%m%d%H%M%S).log

# This will take time proportional to the base backup size.
# Monitor progress via the log output.
# A successful fetch ends with no error and exits 0.

# Verify the data directory contents look like a PostgreSQL cluster:
ls /var/lib/postgresql/18/main/
# Expected: PG_VERSION, pg_wal/, base/, global/, pg_hba.conf (maybe), etc.
cat /var/lib/postgresql/18/main/PG_VERSION
# Must show: 18
```

### A4: Configure point-in-time recovery

```bash
# PostgreSQL 12+ uses postgresql.conf for recovery configuration.
# Earlier versions used a separate recovery.conf file (not applicable here).

# Add recovery configuration to postgresql.conf:
sudo tee -a /etc/postgresql/18/main/postgresql.conf << 'EOF'

# --- PITR RECOVERY CONFIGURATION ---
# Added for restore on <DATE>. Remove these lines after recovery is complete
# and the cluster has been promoted to normal operation.

# restore_command: how PostgreSQL fetches WAL segments during recovery.
# %f = WAL segment filename, %p = local path to write the fetched segment to.
restore_command = '/usr/local/bin/wal-g-restore.sh %f %p'

# recovery_target_time: stop replaying WAL at this UTC timestamp.
# PostgreSQL will replay all WAL up to (but not including) this moment,
# then pause waiting for promotion.
# SET THIS TO 1-2 MINUTES BEFORE THE CORRUPTION OCCURRED.
# Format: 'YYYY-MM-DD HH:MM:SS UTC'
# Example: recovery_target_time = '2026-09-07 14:28:00 UTC'
recovery_target_time = 'YYYY-MM-DD HH:MM:SS UTC'

# recovery_target_action: what to do when the recovery target is reached.
# 'pause': stop at the target and wait. Lets you verify data before committing.
# 'promote': immediately promote to a writable primary (faster, less safe).
# Use 'pause' for its ability to verify before commitment.
recovery_target_action = 'pause'

# --- END PITR RECOVERY CONFIGURATION ---
EOF

# Create the recovery signal file.
# PostgreSQL 12+ enters recovery mode when this file exists in PGDATA.
# Without it, PostgreSQL starts normally and ignores restore_command.
sudo -u postgres touch /var/lib/postgresql/18/main/recovery.signal
# File presence triggers recovery mode; file content is ignored.
```

### A5: Start PostgreSQL in recovery mode

```bash
# Start PostgreSQL. It will enter recovery mode, fetch WAL from B2,
# and replay transactions up to recovery_target_time.
sudo pg_ctlcluster 18 main start

# Monitor the recovery progress:
sudo tail -f /var/log/postgresql/postgresql-18-main.log

# During recovery you will see log lines like:
# LOG: starting point-in-time recovery to 2026-09-07 14:28:00+00
# LOG: restored log file "000000010000000000000001" from archive
# LOG: redo starts at 0/3000028
# LOG: consistent recovery state reached at 0/3000100
# ... (one line per WAL segment fetched and replayed)
# LOG: recovery stopping before commit of transaction ..., time 2026-09-07 14:28:01+00
# LOG: pausing at the end of recovery

# The database is in a read-only state during recovery.
# You CAN connect and run read-only queries to verify data.
```

### A6: Verify data before promoting

```bash
# Connect to the recovering database (read-only mode):
psql -U postgres -d cogdb

# Check that the data looks correct at the recovery target time.
# Examples:
-- Check recent records near the recovery target time:
SELECT count(*) FROM ce_case;

-- Verify the specific records you were concerned about:
-- (run queries specific to the data that was corrupted or missing)

-- Check the recovery timestamp PostgreSQL stopped at:
SELECT now();

-- Exit psql:
\q
```

### A7: Promote to normal operation

```bash
# If data verification passes, promote the cluster to writable primary.
# This is irreversible — the recovery.signal file is removed and
# the cluster becomes a normal read-write primary.

# Option 1: promote via pg_ctl (recommended — clean)
sudo -u postgres /usr/lib/postgresql/18/bin/pg_ctl promote \
  -D /var/lib/postgresql/18/main
# After promote, the log will show:
# LOG: selected new timeline ID: 2
# LOG: archive recovery complete

# Option 2: if recovery_target_action = 'pause', connect and run:
# psql -U postgres -c "SELECT pg_wal_replay_resume();"
# This resumes replay briefly then promotes.

# Verify promoted state:
psql -U postgres -c "SELECT pg_is_in_recovery();"
# Must return: f (false) — the cluster is no longer in recovery mode.

# Remove the recovery configuration lines added in step A4:
# Edit /etc/postgresql/18/main/postgresql.conf and delete the
# "PITR RECOVERY CONFIGURATION" block.
# Then reload:
sudo pg_ctlcluster 18 main reload
```

### A8: Re-establish WAL archiving

```bash
# After promotion, the cluster is on a new timeline (e.g., timeline 2).
# WAL archiving resumes automatically if archive_mode = on was set
# in postgresql.conf before the restore.

# Verify archiving has resumed:
psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
# archived_count should be incrementing again.
# last_archived_time should be recent.

# Take a new base backup immediately to establish a new archive anchor:
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-push /var/lib/postgresql/18/main
'
```

### A9: Restart application and confirm

```bash
# Start WildFly:
sudo systemctl start wildfly

# Monitor application logs for connection errors:
sudo journalctl -u wildfly -f
# (adjust to actual WildFly log path or service name)

# Confirm the application is serving requests correctly.
# Test a read operation (load a case record) and a write operation
# (log a test inspection entry if possible in a test environment).

# Document: what time did service restoration complete?
date -u
# Record this for the incident post-mortem and RTO calculation.
```

### A10: Clean up

```bash
# After confirming the restored cluster is stable (at minimum 24 hours):

# Remove the renamed corrupted data directory if present:
# (Only if in-place restore was used in step A2)
sudo rm -rf /var/lib/postgresql/18/main.corrupted.*
# WARNING: this is permanent. Only do this after you are confident
# the restore is correct and complete.
```

---

## Scenario B: pg_dump restore from WD Elements drive

**Use when:** WAL-G archive is unavailable (B2 unreachable, archive corrupted, archiving was never set up), and the WD Elements drive is physically accessible.

**What this gives you:** The database state as of the most recent weekly pg_dump. All changes between the dump and the failure are lost.

**Data loss:** Up to one week of transactions if the most recent dump is used.

**Estimated time:** 1-4 hours, dominated by `pg_restore` time for the 200GB blob dump.

### B1: Connect the WD Elements drive

```bash
# Physically connect the WD Elements USB drive.
# Wait for the kernel to detect it:
dmesg | tail -20
# Look for: [sda] 12207031250 512-byte logical blocks ...

# Verify the drive is detected:
lsblk -f | grep sda

# Mount if not auto-mounted:
sudo mount /mnt/pg_backup
# (Assumes /etc/fstab entry exists per cnf-backup-strategy.md)

# List available dump sets:
ls /mnt/pg_backup/
# Expected: structural_YYYYMMDD/ and blobs_YYYYMMDD/ directories.
# Identify the most recent pair with matching dates.
RESTORE_DATE="20260907"
# Replace with the actual most recent date found.
```

### B2: Prepare the target database

```bash
# Stop WildFly:
sudo systemctl stop wildfly

# Option A: restore into an existing (empty or wiped) cogdb.
# Drop and recreate the database:
psql -U postgres -c "SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity WHERE datname = 'cogdb';"
# Terminate all active connections first.
psql -U postgres -c "DROP DATABASE IF EXISTS cogdb;"
psql -U postgres -c "CREATE DATABASE cogdb;"

# Option B: restore into a new database for verification first.
psql -U postgres -c "CREATE DATABASE cogdb_restore_$(date +%Y%m%d);"
# After verifying, rename or swap. This is safer but requires
# WildFly reconfiguration to point at the new database name temporarily.
```

### B3: Restore the structural dump

```bash
# pg_restore reads the directory-format dump and applies it to cogdb.
pg_restore \
  -U postgres \
  -d cogdb \
  # -d: target database (must exist already — see step B2)
  -Fd \
  # -Fd: directory format (must match how the dump was created)
  -j 4 \
  # -j 4: parallel restore workers. Restores tables simultaneously.
  # Adjust to VPS core count.
  --no-owner \
  # --no-owner: do not restore original ownership. Objects are created
  # owned by the connecting role (postgres). Avoids errors if the
  # original role names differ between source and target.
  --no-privileges \
  # --no-privileges: do not restore GRANT/REVOKE statements.
  # Avoids errors from missing roles on the target system.
  /mnt/pg_backup/structural_${RESTORE_DATE} \
  2>&1 | tee /tmp/structural_restore.log

# Check for errors:
grep -i "error\|fatal" /tmp/structural_restore.log
# Minor errors (e.g., role does not exist) may be acceptable.
# Any error touching cogdb tables or data is a problem.
```

### B4: Restore the blob dump

```bash
# Restore blobbbytes data. This is the large component (~190GB).
pg_restore \
  -U postgres \
  -d cogdb \
  -Fd \
  -j 2 \
  # -j 2: blob table is single-table; 2 workers for parallelism on indexes.
  --no-owner \
  --no-privileges \
  --data-only \
  # --data-only: the structural dump already created the blobbbytes table.
  # This restores only the row data, not the CREATE TABLE statement.
  # Without --data-only, pg_restore would attempt to create the table again
  # and fail with "relation already exists".
  /mnt/pg_backup/blobs_${RESTORE_DATE} \
  2>&1 | tee /tmp/blob_restore.log

grep -i "error\|fatal" /tmp/blob_restore.log
```

### B5: Verify and promote

```bash
# Verify row counts:
psql -U postgres -d cogdb -c "
  SELECT schemaname, tablename, n_live_tup
  FROM pg_stat_user_tables
  ORDER BY n_live_tup DESC
  LIMIT 20;"

# Run ANALYZE to update query planner statistics after bulk load:
psql -U postgres -d cogdb -c "ANALYZE;"
# Bulk restores leave the planner statistics stale; ANALYZE updates them.
# This improves query performance after the restore.

# Start WildFly:
sudo systemctl start wildfly

# Document service restoration time and estimated data loss window:
date -u
echo "Restored from dump dated ${RESTORE_DATE}. Data loss window: dump date to failure time."
```

### B6: Unmount the drive

```bash
# Unmount and physically disconnect after restore is confirmed complete.
sudo umount /mnt/pg_backup
# Physically unplug the USB cable.
# The drive should not remain mounted indefinitely — see cnf-backup-strategy.md
# on offline discipline.
```

---

## Scenario C: DigitalOcean droplet snapshot restore

**Use when:** The VPS is unreachable, the disk is unrecoverable, or there is an OS-level failure that makes Scenarios A and B inaccessible.

**What this gives you:** The VPS state as of the most recent DO snapshot (up to 24 hours old). PostgreSQL will enter crash recovery on startup. Data committed after the snapshot is lost.

**Data loss:** Up to 24 hours of transactions plus any transactions in-flight at snapshot time.

**Estimated time:** 30-60 minutes to restore the droplet; additional time for PostgreSQL crash recovery and application verification.

### C1: Restore the droplet from snapshot

In the DigitalOcean control panel:

1. Navigate to **Backups** for the production droplet (or **Snapshots** if using manual snapshots)
2. Identify the most recent snapshot. Note its timestamp — this is your RPO bound.
3. Click **Restore** on the chosen snapshot
4. Confirm the restore — this replaces the current droplet's disk with the snapshot state
5. Wait for the restore to complete (DO shows progress in the control panel)

Alternatively, create a new droplet from the snapshot:
1. **Create → Droplet**
2. Choose **Snapshots** tab under "Choose an image"
3. Select the snapshot
4. Configure the droplet (same region, same size or larger)
5. This preserves the original droplet until you are confident in the restored one

### C2: Verify the restored system

```bash
# SSH into the restored VPS (same IP if restored in-place, new IP if new droplet):
ssh -i ~/.ssh/your_do_key your_vps_user@your.vps.ip

# Check PostgreSQL status:
pg_lsclusters

# If PostgreSQL is not running, start it:
sudo pg_ctlcluster 18 main start

# PostgreSQL will perform crash recovery on startup — this is expected.
# Watch the log:
sudo tail -f /var/log/postgresql/postgresql-18-main.log
# Look for: "database system is ready to accept connections"
# This confirms crash recovery completed successfully.

# Verify cogdb is accessible:
psql -U postgres -d cogdb -c "SELECT count(*) FROM ce_case;"

# Check WAL archiver status — it may resume archiving from the snapshot point:
psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
```

### C3: Assess WAL recovery gap

```bash
# Check what WAL segments are available in B2 that postdate the snapshot.
# If WAL archiving was running before the failure, some segments may have
# been archived to B2 AFTER the snapshot was taken but BEFORE the failure.
# These segments can potentially be replayed to recover transactions lost
# between the snapshot time and the archiving failure point.

# This is an advanced recovery step requiring careful execution.
# Consult the WAL-G documentation on timeline handling and recovery
# from a snapshot + WAL combination before attempting this.
# When in doubt, accept the snapshot as the recovery point.
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g wal-show
'
```

### C4: Start application and document

```bash
sudo systemctl start wildfly
date -u
echo "DO snapshot restore complete. Snapshot time: <snapshot timestamp from DO console>."
echo "Estimated data loss: snapshot time to failure time."
```

---

## Post-restore checklist (all scenarios)

Run after any successful restore before closing the incident.

```bash
# --- Verify application is functioning end-to-end ---
# Load a case record from the UI.
# Submit a test form entry (if a test environment is available).
# Confirm WildFly logs show no database connection errors.

# --- Verify WAL archiving is active ---
psql -U postgres -c "SELECT
  archived_count, last_archived_time, failed_count
FROM pg_stat_archiver;"
# If failed_count > 0, archiving is broken — fix before closing the incident.

# --- Take an immediate base backup ---
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-push /var/lib/postgresql/18/main
'
# This establishes a clean anchor point post-restore.

# --- Document the incident ---
# Record:
#   - Incident start time (when failure was detected)
#   - Root cause (what failed)
#   - Recovery scenario used
#   - Recovery target time (for PITR) or dump/snapshot date used
#   - Service restoration time
#   - Measured RTO (restoration time - incident detection time)
#   - Estimated data loss window (RPO actually experienced)
#   - Any steps that were unclear, slow, or failed
# This feeds the next revision of this runbook.

# --- Check disk space after restore ---
df -h /var/lib/postgresql/
# Ensure adequate free space remains. Restore operations can leave
# temporary files or the renamed .corrupted directory.

# --- Verify retention policy ---
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-list
  wal-g wal-show
'
# Confirm the archive looks healthy and retention is within expected parameters.
```

---

## Reference: key paths and identifiers

| Item | Value |
|---|---|
| Production PostgreSQL version | 18.6 (EOL ~November 2030) |
| Production cluster name | main |
| Production port | 5432 |
| PGDATA | `/var/lib/postgresql/18/main` |
| PostgreSQL config | `/etc/postgresql/18/main/postgresql.conf` |
| WAL-G environment file | `/etc/wal-g.env` |
| WAL-G binary | `/usr/local/bin/wal-g` |
| WAL-G logs | `/var/log/wal-g/` |
| PostgreSQL log | `/var/log/postgresql/postgresql-18-main.log` |
| WD Elements XFS mount | `/mnt/cnfpg_backup` (label: cnfadmin) |
| WD Elements exFAT mount | `/mnt/cnfwinstorage` (label: WinCompat) |
| B2 bucket | `cnf-wal-archive` |
| B2 WAL prefix | `s3://cnf-wal-archive/cogdb` |
| Production database | `cogdb` |

---

## Runbook revision log

| Date | Change | Author |
|---|---|---|
| 2026-09-07 | Initial version — three scenarios, pre/post checklists | Echo Darsow |

**Revision trigger conditions:** This runbook must be reviewed and updated after:
- Any actual restore event (update with lessons learned)
- Any change to the backup architecture (new tools, changed paths, new B2 bucket)
- The PostgreSQL major version upgrade (paths change from 18 to whatever comes next; PG19 is currently in beta)
- Annually as a scheduled review, even if no incidents occurred
