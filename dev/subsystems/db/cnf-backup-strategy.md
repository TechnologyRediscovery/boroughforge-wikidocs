---
title: PostgreSQL Backup Strategy — CodeNforce Production Database
description: Architecture, tooling, annotated procedures, and operational discipline for backing up the cogdb PostgreSQL 14 cluster on the production DigitalOcean VPS. Covers local physical media, WAL-G continuous archiving to Backblaze B2, and the 3-2-1 framework guiding all design decisions.
published: true
date: 2026-09-07
tags: [backup, postgresql, walg, backblaze, rsync, infrastructure, disaster-recovery]
editor: markdown
dateCreated: 2026-09-07
---

# PostgreSQL Backup Strategy — CodeNforce Production Database

## Purpose and scope

This document describes the backup architecture for the CodeNforce (`cogdb`) PostgreSQL 14 production database, hosted on a single DigitalOcean VPS. It covers:

- Rationale for each design decision (treat this as an embedded ADR log)
- Annotated shell commands with explanation of every flag and option
- Alternative tools and approaches where relevant
- Operational discipline requirements that make the technical tooling actually work

This is a living document. Sections marked **[NOT YET IMPLEMENTED]** describe the target architecture; sections marked **[IMPLEMENTED]** describe what is currently in place.

**Companion documents:**
- `postgresql-cluster-hygiene.md` — cluster inventory, version management, `pg_upgradecluster` procedure
- `wal-g-setup.md` — step-by-step WAL-G installation and Backblaze B2 configuration (forthcoming)
- `backup-restore-runbook.md` — the fast-path restore procedure for incident response (forthcoming)

---

## Ground truth: verified against production schema (2026-09-07)

This document was reviewed against a real production schema-only dump (`cogdb_prod_schemaonly_7SEP26_beforemapping.sql`, in the `codenforce` repo under `codeconnect/workspace/schema_dump/`) taken with `pg_dump` 16.15 against the live PostgreSQL 14.24 server, using `--schema` flags for all 10 schemas and `--section=pre-data --section=post-data`. Findings:

- **Table name corrected:** the blob table is `blobbytes` (two b's). This document previously spelled it `blobbbytes` (three b's) throughout — fixed.
- **Schema list confirmed:** 10 schemas exist in prod — `public` (179 tables), `westmc` (13), `workflow` (12), `settingsconfig` (7), `external_wprdc` (3), `logging` (1), `mapping` (0 base tables, 1 materialized view: `parceldatamap`), and three currently-empty reserved schemas (`finance`, `worldfacing`, `external_munispecific`). See the codenforce dev-docs segmentation plan (cross-referenced below) for what this means for schema-splitting work.
- **bytea column count corrected:** there are **two** `bytea` columns, not one — `public.blobbytes.blob` (the ~190 GB bulk referred to throughout this doc) and `public.photodoc.metadatamap` (negligible size). The 95%-of-volume narrative and the split-dump strategy below remain valid; only the "one bytea column" framing was imprecise.
- **PostGIS is in active use** (`public.geometry` type, `public.st_transform()` function — referenced by `mapping.parceldatamap` and a generated column on `external_wprdc.wprdcparcelboundaries`), **but this specific dump contains zero `CREATE EXTENSION` statements** — not for PostGIS, not even for `plpgsql` (which every `LANGUAGE plpgsql` function in the dump depends on, and which pg_dump normally emits by default regardless of `-n`/`--schema` filtering per the official docs). Restoring this exact dump into a clean database would fail at the first `LANGUAGE plpgsql` function and again at `wprdcparcelboundaries`' `geometry` column, with no self-evident error pointing at "you forgot the extensions." This is a concrete, reproducible finding, not a hypothesis — and it is the strongest available argument for actually implementing **Level 2 spot-restore verification** (below): a Level 1 `pg_restore --list` manifest check would not catch this, since it only confirms referenced data files are present, not that the SQL is replayable. Root cause not fully confirmed (possibly a `--schema`-filtering interaction with this specific pg_dump 16→PG14 cross-version invocation); until understood, treat every schema-only dump taken with an explicit `--schema` list as **suspect for missing `CREATE EXTENSION` statements** and verify via restore, or add `-e '*'` / omit schema filtering for the definitive backup copy.
- **Dump location practice:** this document's structural-dump script comment said "Run on the DO VPS"; the actual first production pull was run from the local machine over an SSH port-forward tunnel. Both are valid — see the note added inline in that script — but pick one and keep the doc consistent with actual practice going forward.
- **Schema segmentation and the PostgreSQL 14→18 upgrade:** the user's broader question of whether to split `public` into multiple schemas (a `blob` schema for `blobbytes`/`blobtype`/`photodoc`/`pdfdoc`/`bobsource` in particular) and whether to bundle that with the version upgrade is an **architecture decision, not a backup-tooling concern**, and per this repo's Dev↔Docs separation policy it is written up in the `codenforce` repo, not here: see `codenforce/docs/subsystems/system/pgu-0-schema-and-upgrade-plan.md`. That plan is the place for blast-radius analysis, sequencing recommendations, and PostGIS/PG18 compatibility verification — this document only needs to stay accurate about what currently exists in prod.

---

## Threat model and recovery objectives

### What we are protecting against

In order of likelihood for a single-VPS municipal application:

1. **Logical data corruption** — a bad deploy, a bad migration, an accidental `DELETE` or `UPDATE` without a `WHERE` clause. The most common real-world failure mode.
2. **VPS failure** — disk failure, hypervisor failure, or a DigitalOcean incident affecting the droplet.
3. **Account-level failure** — DigitalOcean account compromise, billing suspension, or provider incident affecting snapshot storage.
4. **Ransomware** — encrypts production data and potentially cloud-attached backup destinations before detection.
5. **Regional datacenter incident** — fire, flooding, extended power failure at the DO facility.

Each of these has a different recovery path. A good architecture has at least one viable path for each scenario.

### Recovery objectives (baseline)

These are working baselines for tool selection, not contractually binding commitments. Formal RPO/RTO must be negotiated with TCVCOG and documented in the MSA or a separate SLA addendum.

| Objective | Target | Rationale |
|---|---|---|
| **RPO** (max data loss) | ≤ 4 hours | WAL archiving with 60-second `archive_timeout` achieves ~1 minute in practice; 4 hours gives headroom for incident detection lag |
| **RTO** (max restore time) | ≤ 4 hours | Consistent with Tier 2 classification (operationally important, not public-safety-critical) |

**Context:** Code enforcement is administratively critical but operationally asynchronous. If CodeNforce is unavailable for four hours, inspections are logged on paper and entered later. This is disruptive and creates data-entry lag but is not a public safety failure. The legal sensitivity of violation records (due process timelines, evidentiary standing) argues for tight RPO — not losing records — more than it argues for tight RTO.

**Comparative context:** Financial transaction systems and 911 dispatch infrastructure operate at RTO measured in minutes or seconds. Municipal operational databases like code enforcement are typically in the 4–24 hour envelope in practice. A formal ≤4 hour target places CodeNforce meaningfully ahead of comparable deployments.

---

## Architecture overview: the 3-2-1 framework

The 3-2-1 rule is the industry standard baseline for backup defensibility:

- **3** copies of data
- **2** different storage media types
- **1** copy physically offsite (geographically and administratively separate)

### Current state [PARTIALLY IMPLEMENTED]

| Copy | Location | Media | Notes |
|---|---|---|---|
| Production | DO VPS, NYC datacenter | Block storage (VPS disk) | |
| Snapshot | DO snapshot storage, same region | Block storage (DO managed) | Crash-consistent, not application-consistent; same provider failure domain |
| — | — | — | No independent offsite copy exists yet |

**Critical gap:** Both existing copies are in the same DigitalOcean failure domain. Provider incidents, account compromise, or ransomware that propagates into snapshot storage before detection can eliminate both. This is technically 2-1-0, not 3-2-1.

### Target state [PARTIALLY IMPLEMENTED]

| Copy | Location | Media | Status |
|---|---|---|---|
| Production | DO VPS | Block storage | ✅ Exists |
| WAL archive + base backup | Backblaze B2, independent provider | Object storage (S3-compatible) | 🔲 Not yet implemented |
| Weekly pg_dump | WD Elements 6TB, Monroeville office | Spinning disk (XFS) | 🔲 Drive procured; procedure not yet automated |

This satisfies 3-2-1:
- **3 copies:** VPS + B2 + WD drive
- **2 media types:** Cloud block/object storage + local spinning disk
- **1 offsite:** WD drive at Monroeville office is geographically separate from the DO datacenter

**Provider diversification note:** Using Backblaze B2 (not DO Spaces) for the WAL archive is a deliberate decision. DO Spaces would be convenient but keeps the WAL archive inside the DigitalOcean failure domain. Backblaze is an independent publicly traded company (Nasdaq: BLZE) with its own infrastructure, billing, and failure modes entirely separate from DigitalOcean.

---

## Layer 1: DigitalOcean droplet snapshots [IMPLEMENTED]

### What these are and what they are not

DO droplet backups are block-level snapshots — they capture the raw disk state of the VPS at a point in time. For a running PostgreSQL instance, this produces a **crash-consistent** backup: it is equivalent to the state the disk would be in after a hard power cut. PostgreSQL can recover from this via WAL replay on next startup, but only if the WAL files needed for that replay were also captured in the snapshot, which is not guaranteed.

The contrast is an **application-consistent** backup, where PostgreSQL is explicitly asked to reach a clean checkpoint before the snapshot is taken. DO managed database clusters do this. Self-managed PostgreSQL on a VPS does not receive this treatment from DO's snapshot mechanism.

**Practical implication:** Most crash-consistent snapshots will recover successfully. But "probably fine" is not a defensible position for a system holding municipal enforcement records with potential legal standing. Treat DO snapshots as a **system recovery** tool (getting a VPS back to a running state quickly after OS-level failure or misconfiguration) rather than the primary database recovery path.

### Configuration

- Enable weekly snapshot frequency in the DO control panel
- Retain the maximum 7 snapshots
- Cost: approximately 20% of droplet monthly cost

---

## Layer 2: WAL-G continuous archiving to Backblaze B2 [NOT YET IMPLEMENTED]

This is the highest-leverage addition to the current backup posture.

### Conceptual background: what S3 object storage is

Understanding this is prerequisite to understanding WAL-G's design.

A DigitalOcean VPS disk is **block storage**: a fixed allocation of sectors formatted with a filesystem (XFS, ext4), with directories, inodes, permissions. The OS mounts it, you `ls` it, files live at paths. The disk is attached to your machine and your machine alone. Data lives in a specific physical location.

**Object storage** (S3 and its compatibles) is a fundamentally different abstraction. It is a key-value store exposed over HTTP. Every piece of data is an "object" — a blob of bytes — addressed by a globally unique string key. The operations are HTTP verbs:

```
PUT  /bucket-name/wal-archive/000000010000000000000001.lz4   → upload
GET  /bucket-name/wal-archive/000000010000000000000001.lz4   → download
DELETE ...                                                    → delete
LIST /bucket-name/wal-archive/                               → list objects with prefix
```

There is no filesystem. The path-like keys (`wal-archive/000000010000000000000001.lz4`) are just strings that happen to contain slashes — tools interpret the slashes as hierarchy, but the underlying store is flat. There are no mount points, no inodes, no `cd`. You write whole objects; you read whole objects.

Key properties relevant to backup:
- **No pre-provisioned capacity.** You do not create "a 500GB bucket." You PUT objects in and pay for what you use.
- **Built-in redundancy.** The storage provider replicates every object across multiple physical facilities. You do not configure RAID or manage disks.
- **Accessible from anywhere** with credentials and an HTTPS connection — the backup is not coupled to any specific machine.
- **Billing per unit consumed:** gigabytes × time + per-request charges + egress.

**Why "S3-compatible" is a universal term:** Amazon's S3 HTTP API (authentication scheme, REST endpoints, XML response format) became a de facto industry standard. Backblaze B2, Cloudflare R2, DigitalOcean Spaces, Wasabi, and others all implement it. Software written for Amazon S3 can be pointed at any of these by changing the endpoint URL and credentials. WAL-G uses the S3 API, so it works against any S3-compatible provider without code changes.

### What WAL is and why it matters for backup

PostgreSQL's **Write-Ahead Log** (WAL) is the database's crash recovery mechanism and the foundation of continuous backup.

**The write-ahead invariant:** Before any change is applied to the actual database data files (heap, indexes), PostgreSQL writes a record of that change to a sequential log file. If the server crashes before flushing the change to the data files, the WAL record allows PostgreSQL to replay and complete the change on next startup. This is what "durable" means in ACID: a committed transaction is guaranteed to survive a crash because its WAL record survived.

**WAL segment files:** WAL is stored in 16MB segment files in `$PGDATA/pg_wal/`. Each file has a name encoding its timeline and position in the sequence, e.g., `000000010000000000000001`. When a segment fills, PostgreSQL begins writing a new one. After a checkpoint — when in-memory changes are flushed to data files — old segments are no longer needed for crash recovery and PostgreSQL recycles or deletes them.

**The default behavior discards history.** By default, PostgreSQL deletes WAL segments after they are no longer needed locally. Your ability to reconstruct the database at any prior point in time is gone the moment those segments are deleted.

**WAL archiving** is the configuration that intercepts this deletion: PostgreSQL invokes a shell command (`archive_command`) to copy each completed segment to external storage before recycling it. The full WAL stream is the authoritative record of every transaction ever committed. Combined with a periodic base backup (a snapshot of the data directory at a known point), you can restore the database to any point in time by:

1. Restoring the base backup to disk.
2. Replaying WAL segments sequentially from the base backup point to the desired recovery time.

This is called **Point-in-Time Recovery (PITR)** and is a core PostgreSQL feature, not a third-party extension.

### WAL-G: what it is and why it was chosen

WAL-G is an open-source backup and WAL archiving tool written in Go. It originated at Yandex, is now community-maintained, and supports PostgreSQL, MySQL, SQL Server, MongoDB, and others from a single binary.

**Why WAL-G over alternatives:**

| Tool | Status (2026) | Best fit | Notes |
|---|---|---|---|
| **WAL-G** | Actively maintained | Single VPS + object storage | Designed for cloud-native from the start; single binary; S3-native |
| **pgBackRest** | Archived April 2026, read-only | — | Was the gold standard; Crunchy Data sold, sponsorship lost; no further security patches. Do not use for new installations. |
| **Barman** | Actively maintained (EnterpriseDB) | Multiple PostgreSQL servers + on-prem backup host | Excellent for centralized multi-server management; requires a dedicated backup host — adds a second VPS for a single-server setup |
| **pg_dump (cron)** | N/A — PostgreSQL built-in | Simple logical backups, selective restore | No PITR; restore time scales linearly with database size; suitable as a supplement, not a primary |

**The single-VPS decision rule:** WAL-G is designed for exactly this topology — one PostgreSQL instance on a cloud VPS, WAL archive in an S3-compatible bucket. Barman is the better tool if you ever manage multiple PostgreSQL servers. The expert guidance as of 2026 is: "You run on a public cloud, your repository lives in S3-or-equivalent, you can run a Go binary. Use WAL-G."

**A note on pgBackRest:** Many tutorials and blog posts from 2020–2025 recommend pgBackRest as the gold standard. As of April 27, 2026, the repository is archived. Do not start new installations on pgBackRest. Existing deployments continue to work but receive no security patches.

### How WAL-G integrates with PostgreSQL

WAL-G hooks into two PostgreSQL configuration parameters:

**`archive_command`** — PostgreSQL calls this shell command when a WAL segment is ready to be archived. `%p` is replaced by the full path to the segment file. WAL-G compresses the segment and uploads it to B2. PostgreSQL waits for exit code 0 before recycling the segment. If the command fails (non-zero exit), PostgreSQL retains the segment and retries — no silent data loss.

```
archive_command = 'wal-g wal-push %p'
```

**`restore_command`** — PostgreSQL calls this during recovery to fetch WAL segments from the archive. `%f` is the filename, `%p` is the destination path to write to.

```
restore_command = 'wal-g wal-fetch %f %p'
```

**Base backup:** Separately from WAL shipping, `wal-g backup-push $PGDATA` takes a full physical base backup using `pg_basebackup` under the hood and uploads it to B2. This establishes a recovery anchor point. WAL segments archived between two base backups allow PITR to any second in that window.

**Delta backups:** WAL-G supports delta backups (`WALG_DELTA_MAX_STEPS`) — only changed data pages relative to the previous backup are uploaded. This dramatically reduces base backup size and upload time. Up to 6 deltas between full backups is a sensible starting point.

### postgresql.conf changes required

```ini
# Minimum WAL detail level for archiving.
# 'minimal' (default) does not record enough information for archiving.
# 'replica' is the minimum needed. 'logical' is higher and not required here.
wal_level = replica

# Enable the archive_command hook.
# PostgreSQL will not call archive_command unless this is 'on'.
archive_mode = on

# The command PostgreSQL calls for each completed WAL segment.
# %p = full path to the segment file (relative to $PGDATA).
# WAL-G compresses and uploads to the configured S3 target.
archive_command = 'wal-g wal-push %p'

# Force a WAL segment to be archived at least every N seconds,
# even if transaction volume is low and the segment hasn't filled.
# A 16MB segment at low write volume might take hours to fill otherwise,
# meaning your effective RPO could be hours despite continuous archiving.
# 60 seconds means the worst-case data loss is ~1 minute of transactions.
# Each forced segment is 16MB; at $0.006/GB this costs ~$0.0001 per segment.
archive_timeout = 60
```

**Important:** Changes to `wal_level` and `archive_mode` require a PostgreSQL restart. `archive_command` and `archive_timeout` require only a `pg_reload_conf()` or `SIGHUP`.

### WAL-G environment configuration

WAL-G reads its configuration from environment variables, typically stored in a file sourced by the `archive_command` wrapper or a systemd unit.

```bash
# /etc/wal-g.env — store credentials here, not in postgresql.conf
# (postgresql.conf is readable via pg_settings; do not put secrets there)

# Backblaze B2 presents an S3-compatible API.
# The bucket prefix is where WAL-G stores all objects for this cluster.
WALG_S3_PREFIX=s3://your-b2-bucket-name/cogdb-wal

# Backblaze B2 uses AWS Signature Version 4 for authentication.
# These are your B2 application key credentials, not AWS credentials.
AWS_ACCESS_KEY_ID=your_b2_application_key_id
AWS_SECRET_ACCESS_KEY=your_b2_application_key

# B2's S3-compatible endpoint. The subdomain encodes your B2 region.
# Find your region in the B2 console under "Endpoint" for your bucket.
AWS_ENDPOINT_URL=https://s3.us-west-004.backblazeb2.com

# zstd provides better compression ratio and faster speed than gzip.
# Particularly relevant for the structural (relational) data.
# Binary blob data (blobbytes) compresses poorly regardless of algorithm.
WALG_COMPRESSION_METHOD=zstd

# Allow up to 6 delta backups between full base backups.
# Each delta only uploads changed pages since the previous backup.
# After 6 deltas, the next backup-push automatically takes a full backup.
# Set to 0 to always take full base backups (simpler, more storage).
WALG_DELTA_MAX_STEPS=6
```

**Security note:** The application key stored in `/etc/wal-g.env` has write access to B2. If the VPS is compromised, an attacker has these credentials. Mitigate with:
1. B2 application key scoped to a single bucket (not account-level access)
2. B2 Object Lock (immutability) on the bucket — objects cannot be deleted for a defined retention period even with valid write credentials
3. Consider a separate write-only key for archiving (cannot delete) and a separate read key for restores

### Cron schedule for base backups

```cron
# /etc/cron.d/wal-g-backup
# Run a base backup every Sunday at 02:00 UTC.
# With WALG_DELTA_MAX_STEPS=6, subsequent weekday runs take deltas.
# The full backup on Sunday resets the delta chain.
0 2 * * 0 postgres /usr/local/bin/wal-g backup-push /var/lib/postgresql/14/main >> /var/log/wal-g/backup-push.log 2>&1
```

### Retention management

```bash
# Delete base backups older than 30 days, and all WAL segments
# that are not needed to restore any retained backup.
# Run after backup-push to prevent unbounded B2 storage growth.
wal-g delete retain FULL 4 --confirm
# Retains the 4 most recent full backups plus their delta chains and WAL.
```

### Verifying the WAL archive is healthy

```bash
# Check PostgreSQL's internal archiving statistics.
# archived_count: total segments successfully archived
# failed_count: segments that could not be archived (non-zero is a problem)
# last_failed_wal: the name of the most recently failed segment
# last_failed_time: when the last failure occurred
psql -U postgres -c "SELECT * FROM pg_stat_archiver;"

# Check WAL-G's view of the archive:
# Lists all base backups in B2 with their start/stop LSN and size.
wal-g backup-list

# Integrity check: verifies no gaps in the WAL segment sequence.
# 'OK' means a continuous chain exists from the oldest backup to present.
# 'LOST_SEGMENTS' means there are gaps — PITR to affected windows is impossible.
wal-g wal-show
```

**Operational requirement:** `pg_stat_archiver.failed_count` must be monitored. If `archive_command` begins failing and is not corrected, `$PGDATA/pg_wal/` fills with unarchived segments. When `pg_wal/` fills the disk, PostgreSQL stops accepting writes — the application goes down. This is called a WAL storm and it is self-inflicted. Add an alert on `failed_count > 0` and on `pg_wal/` directory size.

---

## Layer 3: local physical backup to WD Elements 6TB [PARTIALLY IMPLEMENTED]

### Hardware selection rationale

**Model:** Western Digital Elements Desktop 6TB (`WDBWLG0060HBK-NESN`)

The `NESN` suffix is WD's North America regional distribution code — it has no bearing on hardware specs or Linux compatibility.

**Why Elements Desktop specifically, not My Passport or other WD lines:**

WD My Passport drives ship with AES-256 hardware encryption baked into the USB-SATA bridge controller, always on. The Windows SmartWare software sets the unlock password. On Linux, an unset password means the drive works, but WD's implementation also presents a Virtual CD (VCD) partition containing SmartWare — a fake optical drive that can confuse `lsblk` output and cause automount noise. This is manageable but unnecessary friction for a Linux-only backup device.

WD Elements Desktop omits hardware encryption and the VCD partition entirely. It is a plain USB mass storage device with no firmware features that require Windows software to manage.

**Why desktop (AC-powered), not portable (bus-powered):**

At 6TB, bus-powered portables approach the limits of USB power delivery. For a stationary backup appliance running sustained sequential writes during `pg_dump`, an AC-powered desktop unit is more electrically and thermally stable.

**Why USB 3.0 is sufficient:**

The drive is a 5400 RPM spinning hard disk with a maximum sequential throughput of approximately 150 MB/s. USB 3.0 theoretical maximum is 625 MB/s (5 Gbps). The drive's mechanical ceiling is the bottleneck, not the USB interface. USB 3.2 Gen 2 (10 Gbps) would provide no measurable benefit.

**Connector note:** The WD Elements Desktop uses Micro-USB 3.0 (the wide dual-row Micro-B connector), not USB-C. The included cable must be retained — Micro-USB 3.0 cables are not widely stocked. The drive is AC-powered, so running it through a USB hub is fine; a bus-powered hub would be a problem for a bus-powered drive, but this drive draws power from the wall.

### Drive preparation: partitioning

**Why GPT, not MBR:**

MBR partition tables have a 2TB addressable limit with 512-byte logical sectors (2³² sectors × 512 bytes = 2.2TB). A 6TB drive formatted with MBR will produce a corrupt or silently truncated partition table. Always use GPT on any drive over 2TB.

```bash
# Confirm the correct device before any destructive operation.
# lsblk shows block devices with their sizes and mount points.
# -f also shows filesystem type and UUID.
# Verify /dev/sda is the WD Elements (6TB) and not an internal drive.
lsblk -f

# Alternatively, blkid shows UUID and filesystem type for a specific device:
blkid /dev/sda1

# Open parted in interactive mode (alternative to --script flags below):
# sudo parted /dev/sda
# Then type commands at the (parted) prompt.
# Using --script below for reproducibility in documentation.

# Create a GPT partition table on the entire disk.
# WARNING: this destroys all existing data and partition structure on /dev/sda.
# 'mklabel gpt' creates the GUID Partition Table header.
sudo parted /dev/sda --script mklabel gpt

# Create partition 1: PostgreSQL backup target.
# 'mkpart primary' — 'primary' is vestigial terminology from MBR; on GPT all
#   partitions are equivalent. The label is informational only.
# 'xfs' — parted records the filesystem type hint, but does not format.
#   The actual filesystem is created by mkfs.xfs below.
# '1MiB' — start at 1 MiB, not sector 0. This ensures proper alignment
#   to physical sector boundaries (4K Advanced Format drives).
#   Misaligned partitions cause write amplification — each logical write
#   triggers a read-modify-write on the physical 4K sector.
# '500GiB' — end at 500 GiB. Adjust based on expected PostgreSQL backup growth.
sudo parted /dev/sda --script mkpart primary xfs 1MiB 500GiB

# Create partition 2: Windows-compatible storage (code officer photos, etc.)
# '500GiB' — start where partition 1 ends.
# '100%' — use all remaining space to the end of the disk.
sudo parted /dev/sda --script mkpart primary exfat 500GiB 100%

# Verify the result. Should show two partitions with correct sizes.
# 'print' shows the partition table.
sudo parted /dev/sda --script print
```

**Alternative partitioning tools:**

`fdisk` is the traditional interactive tool but has inconsistent GPT support depending on version. `gdisk` is `fdisk` specifically for GPT and is excellent, but requires installation (`sudo apt install gdisk`). `parted` ships with Ubuntu and handles GPT reliably. For a GUI, `gparted` is available via `sudo apt install gparted`.

### Drive preparation: formatting

**Why XFS for the PostgreSQL partition:**

XFS is designed for large sequential files and handles large file counts in a single directory gracefully — both properties match the `pg_dump` directory format output (`-Fd`), which produces a directory of compressed segment files. XFS is the default filesystem on RHEL/CentOS for this reason. `fsck` on a large ext4 volume can take significant time; XFS's journal recovery is faster.

ext4 is also a valid choice. It is simpler and more widely documented. For a backup drive under infrequent write load, the performance difference is immaterial. XFS is preferred here for the large-file and directory-entry optimization.

**Why exFAT for the Windows-compatible partition:**

exFAT has no 4GB per-file size limit (FAT32's ceiling would be a problem for large video or RAW image files). Microsoft published the exFAT specification openly in 2019, and native kernel-level support landed in Linux 5.4 — Ubuntu 20.04 and later handle it natively without a FUSE driver. Windows has had native exFAT support since Windows XP SP2 with an update. For a drive shared between Linux (backup scripts) and Windows (code officer laptop), exFAT is the lowest-friction choice.

NTFS is an alternative. Linux reads and writes NTFS via `ntfs-3g` (a FUSE driver), which works but adds userspace overhead and occasional edge-case behavioral differences with NTFS semantics. For a dedicated backup partition under sustained write load, XFS is preferable. For the cross-platform partition, exFAT is cleaner than NTFS.

```bash
# Format partition 1 as XFS.
# mkfs.xfs creates the XFS filesystem on the block device.
# -L sets the volume label (visible via lsblk -f and in file managers).
# XFS block size defaults to 4096 bytes, matching the drive's physical sectors.
sudo mkfs.xfs -L "cnfadmin" /dev/sda1

# Format partition 2 as exFAT.
# -L sets the volume label (visible in Windows Explorer and Linux file managers).
# exfatprogs is required: sudo apt install exfatprogs
sudo mkfs.exfat -L "WinCompat" /dev/sda2

# Verify both filesystems were created correctly.
# FSTYPE column should show 'xfs' and 'exfat'.
# UUID column will show the UUIDs needed for fstab.
lsblk -f /dev/sda
```

**Alternative for exFAT tools:** Older Ubuntu versions used `exfat-fuse` and `exfat-utils`. Ubuntu 22.04+ should use `exfatprogs` (the in-kernel driver's companion tooling). If `mkfs.exfat` is not found, check which package is installed: `dpkg -l | grep exfat`.

### Persistent mounting via UUID

**Why UUID, not `/dev/sdX`:**

USB device letter assignments (`/dev/sda`, `/dev/sdb`) depend on enumeration order at boot. If internal drives change, or another USB device is plugged in first, the WD Elements may enumerate as `/dev/sdb` instead of `/dev/sda`. A backup script hardcoded to `/dev/sda1` would write to the wrong device or fail. UUIDs are assigned at filesystem creation and remain stable.

```bash
# Get the UUID for each partition.
# blkid queries the kernel's block device database for filesystem metadata.
# The UUID field is what goes in /etc/fstab.
sudo blkid /dev/sda1
sudo blkid /dev/sda2
# Actual output (tangoonefour, verified 2026-09-07):
# /dev/sda1: LABEL="cnfadmin"  UUID="82069ecb-9e20-4f0d-b587-ecb74b38d7c6" TYPE="xfs"
# /dev/sda2: LABEL="WinCompat" UUID="FE9F-BAE2" TYPE="exfat"
# Note: exFAT UUIDs use a shorter format than XFS UUIDs (no dashes in most implementations)

# Add to /etc/fstab for persistent mounting.
# Format: UUID=<uuid>  <mountpoint>  <fstype>  <options>  <dump>  <pass>
#
# 'defaults' — standard mount options (rw, suid, dev, exec, auto, nouser, async)
# 'nofail'   — if the drive is not attached, boot continues instead of halting.
#              Without nofail, a missing USB drive causes boot to drop to a
#              recovery shell waiting for the device. This is important for a
#              drive that is deliberately disconnected between backup runs.
# '0'        — dump: 0 means the dump utility ignores this filesystem.
#              Dump is largely obsolete; 0 is correct for external drives.
# '2'        — pass: fsck check order. 0 = skip, 1 = root filesystem, 2 = others.
#              XFS uses its own journal recovery and does not use fsck in the
#              same way ext4 does, but '2' is still conventional.
#              For exFAT, fsck is not meaningful — use '0' for that partition.

echo "UUID=82069ecb-9e20-4f0d-b587-ecb74b38d7c6  /mnt/cnfpg_backup     xfs   defaults,nofail  0  2" | sudo tee -a /etc/fstab
echo "UUID=FE9F-BAE2                              /mnt/cnfwinstorage    exfat defaults,nofail  0  0" | sudo tee -a /etc/fstab

# Create the mount points and mount both partitions.
sudo mkdir -p /mnt/cnfpg_backup /mnt/cnfwinstorage
sudo mount -a
# -a mounts all filesystems listed in /etc/fstab that are not already mounted.
# Verify:
lsblk -f /dev/sda
```

---

## PostgreSQL dump procedure [PARTIALLY IMPLEMENTED — first manual run 2026-09-07]

### Why a split dump strategy

The `cogdb` database has an unusual data distribution: approximately 95% of total volume (roughly 190 GB of a ~200 GB database) lives in `bytea` binary large object data in the `blobbytes` table. This concentration drives three architectural decisions:

**1. Blob data compresses poorly.** If those blobs are images, PDFs, or other already-compressed binary content (which is typical for inspection photos), gzip achieves negligible compression ratio on them. The output is approximately the same size as the input, burning CPU for nothing.

**2. Different change velocity.** Relational tables (properties, violations, inspections, workflow state, persons, etc.) change every time an inspector touches the application. Blob content is effectively write-once — once a photo or document is attached to a record, it is rarely modified. Applying daily backup overhead to 190 GB of write-once data is wasteful.

**3. Targeted restoration.** If a bad migration corrupts a workflow table, restoring 190 GB of blobs to recover 50 MB of relational records is an unnecessary delay to RTO. Keeping them separate allows a fast restore of only the structural data.

**The split:**

| Dump | Content | Compression | Recommended cadence |
|---|---|---|---|
| Structural | Full schema for all tables + row data for all tables except `blobbytes` | `zstd` or `gzip -6` (effective on relational data) | Daily |
| Blob | `blobbytes` data only (schema already in structural) | None or `-Z 0` | Weekly |

### pg_dump: format selection

PostgreSQL offers four dump formats:

| Format | Flag | Description | Use case |
|---|---|---|---|
| Plain SQL | `-Fp` or default | Human-readable SQL statements | Small databases, selective inspection |
| Custom | `-Fc` | Compressed binary, single file | General purpose, selective restore |
| Directory | `-Fd` | One file per table, parallelizable | Large databases, parallel dump/restore |
| Tar | `-Ft` | Tar archive | Archival, not parallelizable |

**Directory format (`-Fd`) is correct for cogdb** because it is the only format that supports parallel dump (`-j N`) and parallel restore. Each table's data lands in a separate compressed file, so table-level verification and selective restore are possible without decompressing everything. A `toc.dat` manifest file enables integrity checking without full decompression.

### Connecting to prod: SSH tunnel from tangoonefour

**Verified 2026-09-07:** dumps run on the local Ubuntu machine (`tangoonefour`), not on the
VPS, using the same SSH port-forward already set up for pgAdmin access — no separate tunnel
infrastructure needed for these scripts. Output is written straight to the mounted XFS
partition, so (for this path) there is no separate transfer step — contrast with the rsync
procedure below, which applies if the dump is instead run on the VPS itself.

```bash
# ~/scripts/pgcitftunnel.sh — existing tunnel script, reused as-is.
#!/bin/bash
ssh -f edarsow@citfdrop -L 32000:localhost:5432 -N
# -f: fork to background after authentication (daemonize the tunnel).
# -L 32000:localhost:5432: forward local port 32000 to port 5432 as seen from
#   citfdrop's own loopback — i.e. where PostgreSQL listens on the VPS. This
#   is why pg_dump below connects to "localhost:32000", not the VPS's public IP.
# -N: no remote command — the SSH session exists only to hold the tunnel open.
```

Both dump commands below assume this tunnel is up. Bring it up if it isn't, before dumping:

```bash
if ! nc -z localhost 32000 2>/dev/null; then
  ~/scripts/pgcitftunnel.sh
  sleep 2
  # -f above forks after auth; give sshd a moment to bind the local port
  # before the first pg_dump connection attempt.
fi
```

The tunnel stays up in the background (`-f`/`-N`) after the script exits — no need to tear it
down between runs. To close it manually: `pkill -f "L 32000:localhost:5432"`.

### The wrapper script: `cnfprodbak.sh`

**Verified 2026-09-07:** the structural and blob dumps are one script with a mode argument,
not two separate scripts — `codeconnect/database/scripts/cnfprodbak.sh` in the `codenforce`
repo:

```bash
./cnfprodbak.sh structural   # schema + all non-blob row data
./cnfprodbak.sh blobs        # blobbytes row data only
```

Both modes share the same tunnel-check, connection variables, and `BACKUP_ROOT`. The real
script (real role name, real local paths) is **gitignored** — it embeds prod-adjacent
identifiers (the `sylvia` role name, local backup paths) that are unnecessary reconnaissance
value if pushed to a repo shared with collaborators, matching this repo's existing
`codenforce.properties`/`.template` convention. A genericized, committed twin lives alongside
it — `codeconnect/database/scripts/cnfprodbak.sh.template` — copy it, fill in the
placeholders, and that copy is what actually runs. `DB_USER` is `sylvia`, the role with
`SELECT` on all tables (not `postgres`, which was a stand-in during planning).

**A structural gotcha this doc's original one-flag-per-line-with-inline-comment style hit in
practice:** a bare `# comment`-only line inside a `\`-continued command has no trailing
backslash of its own, so it silently **terminates** the continuation right there. The first
draft of this script hit exactly that: `pg_dump` ran with only the flags before the first
comment, silently falling back to connecting as the OS user instead of `-U`. The real script
uses a bash array for `pg_dump`'s arguments instead — each array element can carry its own
trailing comment safely, since newlines inside `( … )` don't need escaping the way a plain
`\`-continued command line does.

**First run (2026-09-07):** `./cnfprodbak.sh structural` completed successfully — 76 MB.
`./cnfprodbak.sh blobs` is running as of this writing; expected size is 150+ GB. See
"Incremental blob backup strategy" below for why subsequent weekly runs won't re-transfer
that same volume every time.

### Production load considerations

`pg_dump` opens a `REPEATABLE READ` transaction for consistency. This is non-blocking for reads — running applications can continue to read and write while the dump runs. However, it pins an old transaction snapshot, which has two implications:

1. PostgreSQL cannot vacuum away row versions visible to that snapshot for the dump's duration. On a busy database with many updates/deletes, a long-running dump can cause table bloat.
2. Long-running dumps during peak hours compete for I/O with the application.

**Recommendation:** Run both dumps during the lowest-traffic window, which for municipal applications is typically 02:00–04:00 local time. The blob dump in particular (190 GB sequential read) is I/O-intensive.

**Before starting:** confirm no long-running locks with:
```bash
psql -h "${PGHOST}" -p "${PGPORT}" -U postgres -d cogdb -c "
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
  FROM pg_stat_activity
  WHERE state != 'idle' AND query_start < now() - interval '5 minutes'
  ORDER BY duration DESC;"
```

### Version compatibility note

`pg_dump` and `pg_restore` version compatibility runs in one direction: a dump taken with a newer `pg_dump` **cannot** be restored with an older `pg_restore`. Since dumps now run locally on tangoonefour (a client-side tool connecting over the tunnel), the versions that matter are tangoonefour's installed `pg_dump`/`pg_restore` versus the VPS's PostgreSQL 14.24 server — not the VPS's own `pg_dump`. `pg_dump` supports dumping from older servers, so a newer local client against the PG14 server is fine; verify before any restore attempt:

```bash
# Server version, over the tunnel:
psql -h "${PGHOST}" -p "${PGPORT}" -U postgres -d cogdb -c "SELECT version();"
# Local client tools (tangoonefour):
pg_dump --version
pg_restore --version
# Local pg_restore must be >= the pg_dump version that produced the dump
# (i.e. >= tangoonefour's own pg_dump, since that's what ran the dump).
```

---

## Incremental blob backup strategy [PROPOSED — not yet implemented]

### The problem

The structural dump is 76 MB — trivial to re-transfer weekly. The blob dump is the opposite:
150+ GB today and only growing. Re-running a full `pg_dump -t public.blobbytes` every week
means re-reading, re-transferring, and re-writing every blob already sitting on the WD drive,
just to pick up the handful of photos/documents added since last week. Re-copying 150+ GB
weekly is not sustainable against a typical bandwidth cap — this needs an actual incremental
strategy, not a smaller compression flag.

### Checking current size

Handy for sizing this problem before/during a blob dump — safe to run in a second `psql`
session over the same tunnel while `cnfprodbak.sh blobs` is still running (pg_dump just holds
a long-running snapshot; a concurrent read connection doesn't block it):

```sql
-- Whole-database size:
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Biggest tables (blobbytes should dominate):
SELECT
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  pg_size_pretty(pg_relation_size(relid))       AS table_only,
  pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_toast
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 15;

-- blobbytes specifically:
SELECT pg_size_pretty(pg_total_relation_size('public.blobbytes'));
```

```bash
psql -h localhost -p 32000 -U sylvia -d <dbname> -c "SELECT pg_size_pretty(pg_database_size(current_database()));"
```

Note `pg_total_relation_size` includes indexes and TOAST storage — for `blobbytes` specifically
the actual `bytea` payload lives in the TOAST table, not the main heap, so `total_size` (not
`table_only`) is the number that reflects what a blobs dump actually copies.

### Ground truth: `blobbytes` is provably insert-only

Verified against `BlobIntegrator.java`/`BlobCoordinator.java` (2026-09-07), then acted on — see
codenforce `docs/subsystems/system/pgu-0-schema-and-upgrade-plan.md` §2.1 for the full scrub:

| Method | Touches | Status |
|---|---|---|
| `updateBlobFilename` (Integrator + Coordinator) | `blobbytes.filename` | **Removed** — confirmed zero live callers (its only caller, `stripPDFMetadata`, itself had zero callers) and was non-functional anyway (parameter bind was commented out) |
| `updateBlobBytes` | `blobbytes.blob` (the actual bytea payload) | **Removed** — dead code, never called outside its own definition |
| `deleteBytes` | `DELETE FROM blobbytes` | **Removed** — dead code, never called outside its own definition |

All three were deleted outright (not just flagged) in the same pass. The only surviving write
path anywhere in the codebase against `blobbytes` is `BlobIntegrator.insertBlobBytes` (`INSERT
INTO public.blobbytes`, called from `BlobCoordinator.storeBlob`). `blobbytes.blob`, `.createdts`,
`.filename`, and `.bobsource_sourceid` are now immutable once written — not by convention, by the
absence of any code path that could change them.

`blobbytes`'s schema also cooperates: `bytesid integer DEFAULT nextval('public.blobbytes_seq')`
is a strictly increasing sequence — a clean, gap-tolerant high-water mark. (`createdts` would
also work, but a sequence has no timezone/clock-skew ambiguity at the boundary.)

### Recommended approach: high-water-mark `\copy`, not `pg_dump`

`pg_dump` has no row-filtering flag (no `--where`) — it always dumps the whole table. The
right tool for a filtered extract is `psql`'s `\copy`, which wraps server-side `COPY` and
streams through the client connection (works over the tunnel exactly like `pg_dump` does).

```bash
STATE_FILE="/mnt/cnfpg_backup/state/blobbytes_last_bytesid"
LAST_ID=$(cat "${STATE_FILE}" 2>/dev/null || echo 0)

# Freeze the upper bound before the COPY so a concurrent insert mid-run can't
# produce an inconsistent "some of this batch, none of the next" result.
NEW_MAX=$(psql -h "${PGHOST}" -p "${PGPORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  "SELECT COALESCE(max(bytesid), ${LAST_ID}) FROM public.blobbytes;")

OUT_FILE="/mnt/cnfpg_backup/dumps/blobbytes_incr_${DATE}_${LAST_ID}-${NEW_MAX}.copy"

psql -h "${PGHOST}" -p "${PGPORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "\copy (
  SELECT bytesid, createdts, blob, uploadedby_userid, filename, bobsource_sourceid
  FROM public.blobbytes
  WHERE bytesid > ${LAST_ID} AND bytesid <= ${NEW_MAX}
  ORDER BY bytesid
) TO '${OUT_FILE}' WITH (FORMAT binary)"
# FORMAT binary, not csv: bytea in text/CSV format is hex-escaped (~2x size).
# Binary COPY format is the closest to on-disk size, and losslessly round-trips
# back in with \copy ... FROM ... WITH (FORMAT binary), as long as the target
# table's column types/order match exactly.

echo "${NEW_MAX}" > "${STATE_FILE}"
```

A typical week's delta is however many photos/documents were uploaded that week — a few
hundred MB at most for a single-municipality deployment, not 150 GB. That actually fits in a
bandwidth cap.

### What this doesn't solve, and the mitigation

### What this doesn't solve, and the mitigation

- **A future code change could reintroduce a mutation path.** "Insert-only" is now enforced by
  the absence of any UPDATE/DELETE code against `blobbytes` (see codenforce
  `pgu-0-schema-and-upgrade-plan.md` §2.1), not just a convention — but that's a point-in-time
  fact, not a permanent guarantee. A periodic **full re-baseline** (a plain `./cnfprodbak.sh
  blobs` run, quarterly or so) is still worth keeping as a self-healing check against that,
  cheap insurance against the incremental chain silently drifting if that ever changes.
- **Restore complexity increases.** A restore is no longer "one `pg_restore`" — it's the last
  full baseline **plus every incremental `.copy` file since, applied in `bytesid` order**.
  Update the Level 2 restore drill (above) to actually exercise this chain, not just the
  baseline, or the drill isn't testing what will really happen in an incident.
- **This is a Layer 3 (local drive) problem specifically.** WAL-G (Layer 2, not yet
  implemented) already solves incremental blob backup at the physical/WAL level — every WAL
  segment ships continuously regardless of table size, and `WALG_DELTA_MAX_STEPS` gives
  page-level delta base backups. Once Layer 2 is live, it carries the tight-RPO burden for
  blobs; Layer 3's job is an offline, offsite copy that's fine to be a week stale by design —
  it just shouldn't cost 150 GB of bandwidth to stay a week stale.

### Open items

- [ ] Add an `incremental` (or similar) mode to `cnfprodbak.sh` implementing the above
- [ ] Decide the re-baseline cadence (quarterly proposed, unconfirmed)
- [ ] Extend the Level 2 restore drill to replay the incremental chain, not just the baseline

---

## Transfer procedure: rsync over SSH [NOT YET AUTOMATED]

### Why rsync, not scp or sftp

`rsync` is the correct tool for large transfers because:

- **Resumable at the block level.** If the connection drops mid-transfer, the next `rsync` run resumes from where it left off using the partially transferred files already on disk. `scp` restarts the entire file from byte zero.
- **Verification built in.** `--checksum` computes a cryptographic hash of each file on both ends and compares, detecting silent corruption that size+mtime comparison misses.
- **Delta transfer algorithm.** For incremental transfers of files that change between runs, rsync transfers only the changed blocks. For `pg_dump` output this is less relevant (each dump run creates new files), but the verification property alone justifies rsync over scp.

### Structural dump transfer

```bash
#!/usr/bin/env bash
# Run on the LOCAL MACHINE (tangoonefour), not the VPS.
# "Pull" model: local machine initiates the transfer from VPS.
# Preferred over pushing from VPS because you control timing
# and can resume cleanly without coordinating with the VPS side.

VPS_HOST="your.do.vps.ip.address"
VPS_USER="your_vps_user"
SSH_KEY="~/.ssh/your_do_ed25519_key"
VPS_BACKUP_ROOT="/var/backups/cnf"
LOCAL_MOUNT="/mnt/cnfpg_backup"
DATE=$(date +%Y%m%d)

rsync \
  -a \
  # -a: archive mode. Equivalent to -rlptgoD:
  #   -r: recursive (descend into directories)
  #   -l: preserve symbolic links
  #   -p: preserve permissions
  #   -t: preserve modification times
  #   -g: preserve group ownership
  #   -o: preserve owner (requires root on destination)
  #   -D: preserve device files and special files
  # For a backup to a local drive, -a is the correct comprehensive option.
  -v \
  # -v: verbose. Print filenames as they are transferred.
  # Omit for unattended/cron runs; use --log-file instead.
  --progress \
  # --progress: show per-file transfer progress (bytes, speed, ETA).
  # Useful for interactive runs to see transfer rate.
  # Omit for cron; it adds noise to logs.
  -z \
  # -z: compress data during transit.
  # Relational data in the structural dump is already gzip-compressed
  # by pg_dump (-Z 6), so -z achieves little additional compression.
  # However, even compressed data sees some benefit, and at 300 Mbps
  # the CPU cost is negligible. Include it here for belt-and-suspenders.
  # For the blob dump (see below), omit -z entirely.
  --checksum \
  # --checksum: compute MD5 hash of each file on both source and destination,
  # compare them, and retransfer if they differ.
  # Without --checksum, rsync uses size + modification time to decide
  # whether files are identical. A file that is corrupt but has the same
  # size and mtime would pass that check undetected.
  # --checksum is slower (CPU cost to hash every file) but is the only
  # way to verify transfer integrity. For a backup workflow, this cost
  # is justified. Hashing 3 GB of structural dump data is fast.
  -e "ssh -i ${SSH_KEY}" \
  # -e: specify the remote shell program.
  # "ssh -i ${SSH_KEY}" uses SSH with a specific identity file.
  # The SSH connection provides encryption and authentication for the
  # rsync data stream. Without -e, rsync would attempt a direct TCP
  # connection (rsync daemon mode), which requires separate configuration.
  "${VPS_USER}@${VPS_HOST}:${VPS_BACKUP_ROOT}/structural_${DATE}/" \
  # Source: the remote directory (trailing slash matters in rsync).
  # Trailing slash on the SOURCE means "transfer the contents of this
  # directory" rather than "transfer the directory itself."
  # Without trailing slash: creates structural_DATE/structural_DATE/ nesting.
  # With trailing slash: contents land directly in the destination directory.
  "${LOCAL_MOUNT}/structural_${DATE}/"
  # Destination: local directory. rsync creates it if it doesn't exist.
```

### Blob dump transfer

```bash
rsync \
  -av \
  --progress \
  # No -z flag: blob data is incompressible binary content.
  # Applying zlib compression to pre-compressed images/PDFs during transit
  # burns CPU on both the VPS and local machine while achieving essentially
  # zero size reduction. At 300 Mbps the transfer takes ~85 minutes
  # regardless; don't add CPU overhead for no benefit.
  --checksum \
  # --checksum still applies: hashing 190 GB takes time but is worth doing
  # to confirm the transfer was not silently corrupted in transit.
  -e "ssh -i ${SSH_KEY}" \
  "${VPS_USER}@${VPS_HOST}:${VPS_BACKUP_ROOT}/blobs_${DATE}/" \
  "${LOCAL_MOUNT}/blobs_${DATE}/"
```

### Transfer time estimates at 300 Mbps (37.5 MB/s)

| Component | Estimated dump size | Approximate transfer time |
|---|---|---|
| Structural (gzip-compressed relational data) | 1–3 GB | 1–2 minutes |
| Blob (uncompressed binary) | ~190 GB | ~85 minutes |

DigitalOcean includes 1 TB/month outbound transfer per droplet in standard pricing. A 200 GB weekly transfer is well within that allowance for most droplet sizes.

### VPS-side cleanup

After confirming successful local transfer, remove the dump directory from the VPS to prevent disk exhaustion. The VPS disk (250 GB) cannot hold multiple generations of 200 GB dumps:

```bash
# Verify the local copy is present before deleting the VPS copy.
ls -lh "${LOCAL_MOUNT}/structural_${DATE}/"
ls -lh "${LOCAL_MOUNT}/blobs_${DATE}/"

# Then on the VPS:
rm -rf "${VPS_BACKUP_ROOT}/structural_${DATE}"
rm -rf "${VPS_BACKUP_ROOT}/blobs_${DATE}"
```

---

## Verification [NOT YET IMPLEMENTED]

A backup that has never been successfully restored is a hypothesis, not a backup. Two verification levels apply.

### Level 1: manifest integrity (fast, automated)

`pg_restore --list` reads the dump's `toc.dat` manifest and verifies that all referenced data files are present. It does not decompress or parse all data — it is fast and appropriate as a post-transfer automated check.

```bash
# pg_restore --list: read and print the table of contents of the dump.
# If the dump is corrupt or files are missing, this exits non-zero.
# Redirect stdout to /dev/null since we only care about exit code here.
# Exit code 0 = manifest valid and all referenced files present.
# Exit code non-zero = something is wrong.

pg_restore --list "${LOCAL_MOUNT}/structural_${DATE}" > /dev/null \
  && echo "Structural manifest OK: $(date)" \
  || echo "STRUCTURAL MANIFEST FAILED: $(date)" >&2

pg_restore --list "${LOCAL_MOUNT}/blobs_${DATE}" > /dev/null \
  && echo "Blob manifest OK: $(date)" \
  || echo "BLOB MANIFEST FAILED: $(date)" >&2
```

**Common footgun — a hang with zero output, not an error, on `pg_restore --list`:** `pg_restore`
falls back to reading from **stdin** as a custom-format archive stream if it isn't given an
explicit archive path — e.g. running it after `cd`-ing into the dump directory and expecting
the current directory to be implicit, the way many other tools behave. Since nothing is piped
into an interactive terminal, it blocks forever waiting on input, with **no error and no
output**, until manually interrupted. This looks identical to a hung/corrupt restore but isn't
one. A genuine `pg_dump`/`pg_restore` version mismatch fails **immediately** with an explicit
`unsupported version` message — it does not hang silently. Diagnose with:

```bash
pg_dump --version
pg_restore --version
# Confirm the archive path is explicit and absolute, then redirect stdin from
# /dev/null so a missing-path mistake fails fast with an error instead of
# hanging again, and cap it with timeout as a hard safety net:
timeout 30 pg_restore --list -v "$(pwd)/structural_${DATE}" < /dev/null
```
If that still hangs against an explicit, correct path, that's the point to suspect real
corruption or a genuine version incompatibility — not before.

**Confirmed 2026-09-07:** this exact footgun, not a version mismatch. Local pg_dump/pg_restore
on tangoonefour are 16.15; the VPS's own pg_dump/pg_restore are 14.24 — but pg_dump/pg_restore
are client-side tools, so the binary that ran over the tunnel was tangoonefour's 16.15 the whole
time (`-h`/`-p` only select where to *connect*, not which binary executes). A newer pg_dump
dumping an older server is the explicitly-supported direction, and the archive was then listed
with pg_restore 16.15 on the same machine that wrote it — no mismatch existed in this path
either way. The unqualified `pg_restore --list` (no path, run from inside the dump directory)
had silently blocked on stdin for 15 minutes; the explicit-path + `< /dev/null` form above
returned instantly with a full, valid TOC listing (FK constraints, default ACLs, and the
`mapping.parceldatamap` matview data entry all present) — Level 1 manifest check passes for the
structural dump.

**Worth banking for later, unrelated to this hang:** if this dump is ever restored onto a host
that only has the VPS's pg_restore 14.24 (e.g. disaster recovery onto a fresh server), *that*
restore would fail — 14.24 cannot read an archive written by pg_dump 16.15. Not a concern for
verification on tangoonefour itself, since that always uses tangoonefour's own matching
pg_restore, but worth installing a matching-major-version PostgreSQL client on whatever host
would actually perform a real disaster-recovery restore.

### Level 2: spot restore to a scratch database (required for true verification)

This is the only test that proves the dump is actually restorable. It requires PostgreSQL installed on `tangoonefour` (local machine). Run this on a schedule, not continuously — monthly for the structural dump is a reasonable cadence given WAL-G covers continuous PITR.

**Why a local `sylvia` role instead of `postgres` superuser:** the dump archive's TOC bakes in the *source* database's actual ownership/ACLs for every object — e.g. `blobbytes` (and most app tables) are owned by `sylvia` in production, so the archive literally contains `ALTER TABLE ... OWNER TO sylvia` and matching `GRANT` statements. Restoring as `postgres` would replay those fine (superuser can reassign to anyone), but restoring as a role that ISN'T `sylvia` and isn't a member of it would make pg_restore log a permission error on each `OWNER TO`/`GRANT` statement and move on (it doesn't abort the run — schema and data still land, just not owned/granted the way production has them). Mirroring the role name locally sidesteps this entirely: since the restoring role IS `sylvia`, ownership reassignment to itself and any GRANTs it holds succeed with zero extra flags, and the scratch DB ends up ownership/ACL-faithful to production.

**One-time local setup** (run once on tangoonefour, as the local Postgres superuser — adjust auth to however you already have local role mirroring configured, e.g. password/`.pgpass`/peer):

```bash
sudo -u postgres psql -c "CREATE ROLE sylvia LOGIN CREATEDB;"
```

`CREATEDB` lets `sylvia` create and drop its own scratch databases, so the verification script below never needs `postgres` at all.

Save the script as `~/scripts/verify-structural-restore.sh` and `chmod +x` it:

```bash
#!/usr/bin/env bash
set -euo pipefail

# verify-structural-restore.sh — Level 2 spot restore verification.
# Run on tangoonefour (local machine with a PostgreSQL server installed).
# Restores a structural dump into a scratch database and spot-checks row
# counts. Does NOT drop the scratch database automatically — it's left in
# place afterward so the restored data can actually be inspected; drop it
# yourself once you're done with it (command printed at the end of the run).
#
# Usage: ./verify-structural-restore.sh [YYYYMMDD]
#   YYYYMMDD - dump date to verify; defaults to today.
# Requires: local Postgres role "sylvia" with CREATEDB (see one-time setup above).

LOCAL_MOUNT="/mnt/cnfpg_backup"
DATE="${1:-$(date +%Y%m%d)}"
DUMP_PATH="${LOCAL_MOUNT}/structural_${DATE}"
VERIFY_DB="cnf_verify_${DATE}"
PGUSER="sylvia"

if [[ ! -d "${DUMP_PATH}" ]]; then
  echo "Dump not found: ${DUMP_PATH}" >&2
  exit 1
fi

# Create a fresh scratch database for the restore test.
createdb -U "${PGUSER}" "${VERIFY_DB}"

# Pre-install postgis as local superuser before pg_restore runs: the archive's
# own statement is "CREATE EXTENSION IF NOT EXISTS postgis", so having it
# already installed turns that into a no-op instead of a permission error —
# which otherwise cascades into every downstream object that depends on the
# geometry type (spatialdata8, wprdcparcelboundaries, parceldatamap, etc.).
# No `|| true` here: if this fails (e.g. postgis isn't installed on this
# machine at all), that's worth stopping the run over, not silently ignoring.
sudo -u postgres psql -d "${VERIFY_DB}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Restore the structural dump into the scratch database. No --no-owner/--no-privileges
# needed: connecting as sylvia matches production ownership, so OWNER TO/GRANT
# statements in the archive succeed as-is instead of erroring and being skipped.
#
# `|| true`: pg_restore already continues past individual statement errors
# (e.g. GRANTs to production-only roles that don't exist locally) by design —
# without `|| true` here, its own nonzero exit code trips `set -e` and kills
# this script immediately afterward, before the spot-check below ever runs.
pg_restore \
  -U "${PGUSER}" \
  -d "${VERIFY_DB}" \
  -Fd \
  -j 4 \
  "${DUMP_PATH}" || true
# -U: PostgreSQL role to connect as.
# -d: target database; must already exist (createdb above), pg_restore does not create it.
# -Fd: directory format (matches how the dump was created).
# -j 4: parallel restore workers, same guidance as the dump.

# Spot check: compare row counts against production.
# pg_stat_user_tables.n_live_tup is an estimate, not an exact count, and won't
# exactly match production (dump was taken at a different time) — just
# confirm the numbers are in the right order of magnitude.
psql -U "${PGUSER}" -d "${VERIFY_DB}" -c "
  SELECT schemaname, tablename, n_live_tup
  FROM pg_stat_user_tables
  ORDER BY n_live_tup DESC
  LIMIT 20;"

echo "Verification complete for ${DUMP_PATH}: ${VERIFY_DB} restored and spot-checked."
echo "Scratch database ${VERIFY_DB} was left in place for manual inspection."
echo "Drop it yourself when done: dropdb -U ${PGUSER} ${VERIFY_DB}"
```

**Residual caveat:** any GRANT in the archive that names a *different* production role (not `sylvia`) will still fail locally if that role doesn't exist on tangoonefour — pg_restore logs it and moves on, harmless for a row-count spot-check (see `restore_failure_analysis_7SEP26.md` in the codenforce repo for a real, quantified example of exactly this). The postgis pre-install above handles the one extension actually in use in this database; a different structural dump that introduced a different non-"trusted" extension would need the same one-time superuser pre-install treatment before its own `CREATE EXTENSION IF NOT EXISTS` statement is reached.

**The scratch database is not auto-dropped.** Earlier versions of this script tore `${VERIFY_DB}` down automatically via a `trap cleanup EXIT`, which also silently discarded the results of a run that hit real, non-cosmetic errors. Drop it manually once you've actually looked at the spot-check output: `dropdb -U sylvia cnf_verify_YYYYMMDD`.

### Level 2 (blobs): spot restore + content checksum

A row-count spot-check (as above) doesn't prove much for a single binary-blob column — the same row count landing doesn't mean the bytes inside each one are intact, the way it does for a table full of typed relational columns with constraints. The real test for `blobbytes` is restoring the data and computing a **content checksum**, not just counting rows.

**The blobs dump is data-only** (see "Why a split dump strategy" above) — its archive has no `CREATE TABLE blobbytes` to restore against. So there are two ways to get a target table for it: restore into a database that already has the schema (e.g. one `verify-structural-restore.sh` already populated), or pull just `blobbytes`' definition out of a same-date structural dump into a fresh, otherwise-empty database.

```bash
#!/usr/bin/env bash
set -euo pipefail

# verify-blobs-restore.sh — Level 2 spot restore verification for the blobs dump.
# Run on tangoonefour (local machine with a PostgreSQL server installed).
# Restores blobbytes data into a scratch database, then runs a content
# checksum (not just a row count) to prove the bytea payloads themselves
# restored correctly. Does NOT drop the scratch database automatically —
# inspect it, then drop it yourself (command printed at the end of the run).
#
# Usage: ./verify-blobs-restore.sh [YYYYMMDD] [EXISTING_DB]
#   YYYYMMDD    - dump date to verify; defaults to today. Also selects which
#                 dated structural dump blobbytes' schema is pulled from, if
#                 EXISTING_DB is omitted.
#   EXISTING_DB - optional. Restore into this already-existing database (e.g.
#                 a scratch DB verify-structural-restore.sh already
#                 populated) instead of creating a fresh single-table one.
# Requires: local Postgres role "sylvia" with CREATEDB (see
# verify-structural-restore.sh's one-time setup).

LOCAL_MOUNT="/mnt/cnfpg_backup"
DATE="${1:-$(date +%Y%m%d)}"
EXISTING_DB="${2:-}"
BLOBS_DUMP_PATH="${LOCAL_MOUNT}/blobs_${DATE}"
STRUCTURAL_DUMP_PATH="${LOCAL_MOUNT}/structural_${DATE}"
PGUSER="sylvia"

if [[ ! -d "${BLOBS_DUMP_PATH}" ]]; then
  echo "Blobs dump not found: ${BLOBS_DUMP_PATH}" >&2
  exit 1
fi

if [[ -n "${EXISTING_DB}" ]]; then
  VERIFY_DB="${EXISTING_DB}"
  echo "Restoring blobs into existing database: ${VERIFY_DB}"
else
  # No existing DB given: build a fresh one with ONLY blobbytes' schema,
  # pulled from a same-date structural dump (the blobs dump itself has no
  # CREATE TABLE statement to restore against).
  if [[ ! -d "${STRUCTURAL_DUMP_PATH}" ]]; then
    echo "No EXISTING_DB given and no matching structural dump at ${STRUCTURAL_DUMP_PATH}." >&2
    echo "blobbytes' schema has to come from somewhere: pass an existing DB, or ensure a same-date structural dump exists." >&2
    exit 1
  fi
  VERIFY_DB="cnf_verify_blobs_${DATE}"
  createdb -U "${PGUSER}" "${VERIFY_DB}"
  pg_restore \
    -U "${PGUSER}" \
    -d "${VERIFY_DB}" \
    -Fd \
    --schema-only \
    -t blobbytes \
    "${STRUCTURAL_DUMP_PATH}"
  # --schema-only -t blobbytes: pulls just this one table's definition (plus
  # its own indexes/sequence) out of the structural dump — not all 179
  # tables, since blobs are being tested in isolation here. This does NOT
  # pull in pdfdoc/photodoc's incoming FKs to blobbytes — expected and fine,
  # since those tables aren't part of this check.
fi

# Restore the blob data. Same `|| true` reasoning as the structural script:
# don't let set -e kill the run before the checksum check below.
pg_restore \
  -U "${PGUSER}" \
  -d "${VERIFY_DB}" \
  -Fd \
  -j 4 \
  "${BLOBS_DUMP_PATH}" || true

# Content checksum, not just a row count: proves every row's bytea payload
# reconstructed correctly, not just that some number of rows landed. Safe to
# diff against the same query run on production at any time — blobbytes is
# provably insert-only (see "Ground truth" above), so old rows never change.
psql -U "${PGUSER}" -d "${VERIFY_DB}" -c "
  SELECT
    count(*)                                        AS row_count,
    max(bytesid)                                     AS max_id,
    md5(string_agg(md5(blob), '' ORDER BY bytesid))  AS content_checksum
  FROM public.blobbytes;"

echo "Verification complete for ${BLOBS_DUMP_PATH}: ${VERIFY_DB} restored and checksummed."
echo "Compare the content_checksum above against the same query run on production (see below)."
echo "Scratch database ${VERIFY_DB} was left in place for manual inspection."
echo "Drop it yourself when done: dropdb -U ${PGUSER} ${VERIFY_DB}"
```

**Production-side comparison** — run the identical query over the same tunnel used for dumps, and diff `content_checksum` against what the script above printed. A match is byte-for-byte proof the blob backup is restorable, not just "some rows landed":

```bash
psql -h localhost -p 32000 -U sylvia -d cogdb -c "
  SELECT
    count(*)                                        AS row_count,
    max(bytesid)                                     AS max_id,
    md5(string_agg(md5(blob), '' ORDER BY bytesid))  AS content_checksum
  FROM public.blobbytes;"
```

---

## Operational discipline requirements

Technical tooling is necessary but not sufficient. The following operational practices are load-bearing parts of the backup architecture.

### Disconnect the WD drive after each backup run

An external USB drive that remains mounted is not an offline backup. Ransomware with filesystem write access will encrypt mounted drives along with the primary data. The value of the physical local backup comes entirely from it being disconnected and physically separate when not in active use.

**Procedure:** After the rsync transfer completes and manifest verification passes, unmount and physically disconnect the drive:

```bash
sudo umount /mnt/cnfpg_backup
sudo umount /mnt/cnfwinstorage
# Then physically unplug the USB cable.
```

The drive should live in a location separate from the machine it backs up. A desk drawer in the same office is acceptable; the same desk surface as the machine it backs up is not.

### Encrypt the drive at rest (recommended, not yet implemented)

The WD Elements partition containing PostgreSQL backups holds municipal enforcement records — property owner data, violation histories, inspection photographs. These are personally identifiable records with potential legal standing under Pennsylvania municipal law. An unencrypted drive is a data exposure liability if the physical drive is lost, stolen, or borrowed.

**LUKS (Linux Unified Key Setup)** encrypts at the block device level, making the entire partition ciphertext at rest. The setup is a one-time operation and adds essentially zero I/O overhead on modern hardware (AES-NI hardware acceleration).

LUKS implementation deserves a dedicated how-to document. Key considerations: passphrase management (do not lose it — no recovery path), decrypt-before-mount workflow in the backup script, and the impact on the `nofail` fstab option (LUKS devices require explicit mapping before fstab can mount them).

The exFAT partition for code officer photos is a separate question with different stakeholders. If that partition contains evidentiary material, encryption should be discussed with TCVCOG and potentially Cozza Law.

### Restore testing schedule

| Test | Frequency | Procedure |
|---|---|---|
| Manifest check (automated) | After every transfer | `pg_restore --list` on both dumps |
| Structural spot restore | Monthly | `createdb`, `pg_restore`, row count check, `dropdb` |
| Blob spot restore + checksum | Monthly | `pg_restore` (schema pulled from structural if needed), content-checksum query vs. production, `dropdb` |
| Full WAL-G restore drill | Annually minimum | Spin up a temporary DO droplet, restore from B2, verify data, document RTO achieved, tear down |
| DO snapshot restore test | Annually | Restore from DO snapshot to a temporary droplet, verify PostgreSQL starts cleanly |

Document the results of each restore test. The RTO you achieve in a drill is the RTO you can honestly claim in a business continuity document — not the theoretical estimate.

---

## Evidentiary and records management notes

Several items raised during architecture discussions that have non-technical implications:

**Inspection photographs outside the system:** If code officers are storing inspection photographs on personal laptops or devices outside CodeNforce, those records exist outside the backup architecture described here and outside TCVCOG's records management control. Depending on how Pennsylvania municipalities classify enforcement photographs, this may constitute a records retention issue. The correct remediation is to ingest photographs into CodeNforce (into the `blobbytes` table, covered by the existing backup) rather than maintaining a separate ad hoc backup path.

**Chain of custody for evidentiary material:** A consumer external hard drive with no access controls or integrity verification is not an appropriate long-term store for photographs that may be introduced in enforcement proceedings or appeals. If photographs have evidentiary standing, their storage, integrity verification, and access log should be discussed with TCVCOG and solicitor.

**RTKL implications:** Pennsylvania Right-to-Know Law requests can reach any record in the municipality's possession, including enforcement records stored in CodeNforce. Backup copies of those records are themselves subject to RTKL. The backup architecture does not create new RTKL obligations, but the records custodian should understand that B2 objects and drive backups are legally equivalent to the production records for RTKL purposes.

---

## Decision log

| Date | Decision | Rationale | Status |
|---|---|---|---|
| 2026-09-07 | Use WD Elements Desktop, not My Passport | Elements has no hardware encryption or VCD partition; cleaner on Linux | Adopted |
| 2026-09-07 | GPT partition table on WD drive | MBR 2TB limit; all drives >2TB require GPT | Adopted |
| 2026-09-07 | XFS for PostgreSQL partition | Large sequential file optimization; faster journal recovery than ext4 | Adopted |
| 2026-09-07 | exFAT for second partition | Native Linux (kernel 5.4+) and Windows support; no FAT32 4GB file limit | Adopted |
| 2026-09-07 | Split structural/blob pg_dump | Different change velocity; blob compression is wasteful; faster structural restore | Adopted |
| 2026-09-07 | pg_dump directory format (-Fd) | Only format supporting parallel dump/restore; per-table files enable selective restore | Adopted |
| 2026-09-07 | Backblaze B2 over DO Spaces for WAL archive | Provider diversification; B2 is outside DO failure domain; $6/TB vs DO Spaces pricing | Adopted |
| 2026-09-07 | WAL-G over pgBackRest | pgBackRest archived April 2026, no further security patches; WAL-G is correct fit for single VPS + object storage | Adopted |
| 2026-09-07 | WAL-G over Barman | Barman designed for dedicated backup host managing multiple PostgreSQL servers; adds second VPS cost/complexity for single-server setup | Adopted |
| 2026-09-07 | `archive_timeout = 60` | Forces WAL segment ship every 60 seconds; effective RPO ~1 minute even under low write volume | Pending implementation |
| 2026-09-07 | `rsync --checksum` on all transfers | MD5 hash comparison detects silent corruption that size+mtime check misses | Adopted |
| 2026-09-07 | B2 application key scoped to single bucket | Blast radius reduction if VPS credentials are compromised | Pending implementation |
| 2026-09-07 | Single `cnfprodbak.sh` script with a structural/blobs mode flag, not two scripts | Both modes share the tunnel check, connection vars, and `BACKUP_ROOT`; matches how the pair is actually operated | Adopted |
| 2026-09-07 | Gitignore the real dump script; commit a `.sh.template` twin | Script embeds the real `sylvia` role name and local backup paths — unnecessary recon value if pushed; matches the existing `codenforce.properties`/`.template` convention | Adopted |
| 2026-09-07 | `sylvia` role (SELECT-only), not `postgres`, for dump connections | Least privilege — the dump doesn't need superuser | Adopted |
| 2026-09-07 | High-water-mark (`bytesid`) incremental blob extract via `\copy`, not `pg_dump` | `pg_dump` has no row-filter flag; `blobbytes` verified insert-only in practice (`updateBlobBytes`/`deleteBytes` are dead code) | Proposed, not yet implemented |

---

## Known gaps and next steps

The following items are unresolved and represent implementation or decision debt:

- [ ] **WAL-G installation and configuration** on the production VPS — see `wal-g-setup.md` (forthcoming)
- [ ] **B2 bucket creation and application key scoping** — bucket, key ID, and app key generation in B2 console; Object Lock configuration for immutability
- [ ] **Monitoring for `pg_stat_archiver.failed_count`** — alerting mechanism not yet defined; WAL storm risk is unmitigated until this is in place
- [x] **`cnfprodbak.sh` wrapper script** — structural + blobs modes; first structural run succeeded (76 MB), blob run in progress (150+ GB) as of 2026-09-07
- [x] **Level 1 manifest verification** — `pg_restore --list` against the structural dump passed 2026-09-07 (full, valid TOC); blobs dump not yet checked (still running)
- [ ] **Incremental blob backup** — design proposed above (high-water-mark `\copy`); not yet implemented as a script mode
- [ ] **Automated weekly dump and cron** — manual procedure above; not yet scripted and scheduled
- [ ] **LUKS encryption** on the XFS partition of the WD drive
- [ ] **Formal RPO/RTO negotiation with TCVCOG** — current targets are working baselines, not documented commitments
- [ ] **PostgreSQL 14 → 18 upgrade** — PG 14 upstream support ends November 2026; WAL-G base backup chain should be established after the upgrade, not before, to avoid resetting the archive chain (target bumped from 17 to 18 — see `postgresql-cluster-hygiene.md`)
- [ ] **Restore runbook** — fast-path incident response procedure; currently undocumented
- [ ] **First restore drill** — no restore test has been executed against any backup copy; this is the highest-priority operational gap
