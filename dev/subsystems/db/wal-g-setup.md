---
title: WAL-G Setup — Installation and Backblaze B2 Configuration
description: Step-by-step how-to for installing WAL-G on the production VPS, configuring Backblaze B2 as the WAL archive target, modifying postgresql.conf, pushing the initial base backup, establishing the cron schedule, and verifying the archive is healthy. Run this procedure after the PostgreSQL 14→18 upgrade is complete and verified.
published: true
date: 2026-09-13
tags: [walg, backup, postgresql, backblaze, infrastructure, disaster-recovery]
editor: markdown
dateCreated: 2026-09-07
---

# WAL-G Setup — Installation and Backblaze B2 Configuration

## Prerequisites and ordering constraints

**Complete these before starting this procedure:**

- [X] PostgreSQL 14→18 upgrade complete and PG 18 cluster verified (see `postgresql-cluster-hygiene.md`)
- [X] PG 18 cluster running on port 5432, `cogdb` accessible
- [X] PostGIS confirmed healthy on PG18 (`postgis_full_version()`) — a broken extension after the
      upgrade is a bigger problem than a missing archive, so fix it first
- [X] `update_extensions.sql` (emitted by `pg_upgrade`) reviewed and applied
- [X] Backblaze account created and B2 Cloud Storage enabled
- [X] **`$PGDATA` read off `pg_lsclusters`, not assumed** — see the callout below
- [X] Outbound HTTPS from the VPS is unblocked (WAL-G uploads to B2 over HTTPS port 443)
- [X] B2 bucket's **default Object Lock retention confirmed at 14 days**, not 30 (Part 1.1). If the
      bucket was created with a 30-day default, change it *before* the first upload — Compliance
      mode cannot retroactively unlock objects already written under it. ECD just set this to 14d @23:51h

**Why after the upgrade:** WAL segments produced by PostgreSQL 14 cannot be replayed against a PostgreSQL 18 data directory. Setting up WAL-G archiving before the upgrade and then upgrading creates a broken archive chain. Establish the archive fresh against PG 18.

**Companion documents:**
- `cnf-backup-strategy.md` — why WAL-G, what WAL archiving is, S3/object storage primer
- `postgresql-cluster-hygiene.md` — upgrade procedure and cluster management
- `backup-restore-runbook.md` — how to use the archive to restore

## Ratified configuration for this deployment

The values below are decided, and are what this document now uses throughout. They supersede the
earlier draft defaults (Object Lock 30 days, `WALG_DELTA_MAX_STEPS=6`, `archive_timeout=60`),
which conflicted with each other. Full rationale for each is in the `codenforce` repo:
`docs/subsystems/db/mw1-pg18-maintenance-window.md` §7.

| Setting | Value | Set in |
|---|---|---|
| `PGDATA` | **`/mnt/vol_pg18data/pgdata/18/main`** | `/etc/wal-g/wal-g.yaml`, `backup-push` argument, cron, monitoring |
| B2 Object Lock | **Compliance, 14 days** | B2 bucket settings (Part 1.1) |
| `WALG_DELTA_MAX_STEPS` | **`0`** — every backup is a full | `/etc/wal-g/wal-g.yaml` (Part 2.3) |
| `wal-g delete retain` | **`FULL 4`** — ~28 days of history | cron (Part 5) |
| `archive_timeout` | **`900`** — 15-minute worst-case RPO | `postgresql.conf` (Part 3) |
| `WALG_COMPRESSION_METHOD` | `zstd` | `/etc/wal-g/wal-g.yaml` (Part 2.3) |
| logrotate | required | `/etc/logrotate.d/wal-g` (Part 5.1) |

**The two settings that must be reasoned about together:** Object Lock retention has to sit
*below* the `delete retain` horizon. 14 days of immutability against a ~28-day retention horizon
means the weekly cleanup job only ever targets objects that unlocked roughly two weeks ago. Set
the lock *above* the horizon — as the earlier 30-day draft did — and the cleanup job fails every
single week, into a log nobody reads, while storage grows without bound.

> ### ⚠ `PGDATA` is on a block volume, not the packaged default
>
> The PG18 cluster on this host was created by `pg_upgradecluster` with an explicit `newdatadir`
> on a DigitalOcean block volume. **`/var/lib/postgresql/18/main` does not exist here.**
>
> ```
> PGDATA=/mnt/vol_pg18data/pgdata/18/main
> ```
>
> Confirm it yourself before writing any config — the *Data directory* column is authoritative:
>
> ```bash
> pg_lsclusters
> ```
>
> Getting this wrong either fails outright or, worse, silently archives the wrong directory.
> This is a **temporary arrangement**: after the soak period the cluster moves back to
> `/var/lib/postgresql/18/main`, and every path in this document must be revisited as part of that
> same change.
>
> **Second-order consequence while it lasts:** `pg_wal/` lives inside `PGDATA`, so it is on the
> volume too — which has ~47 GB free, not the droplet's ~75 GB. A broken `archive_command` with
> `archive_mode = on` fills that volume and stops production. That is exactly the failure this
> document's ordering (test the archive command in 6.3 *before* enabling `archive_mode` in Part 3)
> exists to prevent.

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
- **Retention period:** **14 days**

This means any WAL segment or base backup uploaded to the bucket cannot be deleted for 14 days from upload, regardless of credentials presented.

**Why 14 and not 30.** The lock period must be shorter than the backup retention horizon, or the
weekly cleanup job (Part 5) spends every run trying to delete objects that are still immutable.
`delete retain FULL 4` against weekly full backups is a ~28-day horizon, so anything the cleanup
job targets has been unlocked for roughly two weeks. 14 days of true immutability still
comfortably exceeds any realistic ransomware detection window, which is what the control is
actually for.

**Compliance mode binds you too.** There is no override, for anyone, including Backblaze support.
If the first `backup-push` goes to a mistyped prefix, you store that garbage — and pay for it —
for the full retention period. Verify `WALG_S3_PREFIX` (Part 2.3) before the first upload.

### 1.2 Create a scoped application key

**Why a scoped key, not the master key:** The master account key has full access to all B2 buckets and account settings. If it is compromised, the attacker controls your entire B2 account. A scoped application key with minimum necessary permissions limits blast radius to the WAL archive bucket only.

> **The master key also simply does not work here.** Backblaze's S3-compatible API does not accept
> the master application key at all — only application keys created under it. So this is not merely
> best practice; a master key produces authentication failures no amount of config will fix.

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

**Which value goes where** — the naming collision between B2 and AWS causes real confusion:

| B2 console calls it | Goes into | Notes |
|---|---|---|
| `keyID` / **applicationKeyId** | `AWS_ACCESS_KEY_ID` | The public half. Safe to read back from the console later |
| **applicationKey** | `AWS_SECRET_ACCESS_KEY` | The secret. Displayed exactly once |
| **bucket name** (`cnf-wal-archive`) | inside `WALG_S3_PREFIX` | The S3 API addresses buckets by name |
| **bucketId** (a long hex string) | **nowhere** | A B2-native-API concept. WAL-G speaks S3 and never uses it |
| **Endpoint** (`s3.us-west-004.backblazeb2.com`) | `AWS_ENDPOINT` *and* `AWS_REGION` | See 1.3 |

Step 4 above ("Allow List All Bucket Names: No") has a consequence worth carrying forward: a
bucket-scoped key may be refused the `s3:GetBucketLocation` call WAL-G would otherwise use to
discover the region. That is why `AWS_REGION` is set explicitly in 2.3 rather than left to
auto-detection.

### 1.3 Note the B2 endpoint URL

In the bucket details, find the **Endpoint** field. It looks like:
```
s3.us-west-004.backblazeb2.com
```
The subdomain encodes your B2 region. This varies by account; use the value shown in your console, not the example here.

**Two settings come out of this one string**, and both are needed in 2.3:

```yaml
AWS_ENDPOINT: "https://s3.us-west-004.backblazeb2.com"   # the whole hostname, with scheme
AWS_REGION:   "us-west-004"                              # just the middle segment
```

The scheme (`https://`) is part of `AWS_ENDPOINT` and is not shown in the console field — add it.

---

## Part 2: WAL-G installation on the VPS

All commands in this section run on the production VPS as a user with sudo access.

### 2.1 Download the WAL-G binary

WAL-G distributes pre-compiled binaries via GitHub Releases. The binary is statically linked — no dependencies beyond libc, no pip installs, no virtualenvs.

```bash
#!/bin/bash
# Abort on the first failure. Without this, a failed download cascades into a
# failed extract, a failed move, and a "command not found" - five misleading
# errors for one root cause.
set -euo pipefail

# ---------------------------------------------------------------------------
# Release and asset selection.
#
# VERIFIED WORKING 2026-09-13 (v3.0.9, HTTP 200, 18,848,388 bytes).
#
# !! The asset naming scheme has CHANGED between releases. Older releases used
#    'wal-g-pg-ubuntu-22.04-amd64.tar.gz'; current releases drop the 'ubuntu-'
#    segment entirely. Do not carry an old filename forward to a new tag -
#    confirm it against the release's own Assets list, or via the API:
#      curl -s https://api.github.com/repos/wal-g/wal-g/releases/tags/v3.0.9 \
#        | grep -oE '"name": "wal-g-pg[^"]*"' | sort
# ---------------------------------------------------------------------------
WALG_VERSION="v3.0.9"

# Ubuntu release is read from the host rather than hardcoded, so this does not
# silently 404 after a distro upgrade. Upstream publishes 20.04, 22.04, 24.04.
. /etc/os-release
UBUNTU_VER="${VERSION_ID}"          # 22.04 on this host (jammy)

# The bare binary, NOT the .tar.gz. There is nothing inside that archive except
# this same file, and taking it directly removes both the extract step and any
# question about what the binary is named inside the tarball.
ASSET="wal-g-pg-${UBUNTU_VER}-amd64"
BASE="https://github.com/wal-g/wal-g/releases/download/${WALG_VERSION}"

# ---------------------------------------------------------------------------
# Download.
#
# -f is NOT optional. Without it, curl treats an HTTP 404 as a success: it
#    writes the 9-byte body "Not Found" into your output file and exits 0.
#    Everything downstream then fails with nonsense ("not in gzip format",
#    "no properly formatted SHA256 checksum lines found") that points nowhere
#    near the real problem. With -f, curl writes nothing and exits 22.
# -L follow redirects (GitHub redirects release assets to its asset storage).
# -O keep the remote filename - which the checksum step depends on, below.
#
# Do NOT put comments between backslash-continued lines: the continuation
# joins them into one logical line, so a '#' swallows the rest of it,
# including the URL.
# ---------------------------------------------------------------------------
cd "$(mktemp -d)"

curl -fLO "${BASE}/${ASSET}"
curl -fLO "${BASE}/${ASSET}.sha256"

# Verify against upstream's published checksum. The sidecar is a standard
# sha256sum line - "<hash>  <filename>" - so 'sha256sum -c' looks that exact
# filename up on disk. That is why -O above matters: rename the download and
# this check can no longer find it.
sha256sum -c "${ASSET}.sha256"
# Expect exactly: "wal-g-pg-22.04-amd64: OK"
# Anything else - stop. Do not install the binary.

# Install in one step: correct owner, group, and mode, no separate chmod.
sudo install -o root -g root -m 0755 "${ASSET}" /usr/local/bin/wal-g

# Verify:
wal-g --version
# Should print a version string matching WALG_VERSION above.
```

> **If `curl` exits 22**, the asset name is wrong for this release — that is the *only* thing it
> means. Re-read the Assets list for your tag (the API one-liner in the comments above prints just
> the PostgreSQL ones) and fix `ASSET`. Do not work around it by dropping `-f`; that is what
> produced the original cascade of unrelated-looking errors.

### 2.2 Create the log directory

```bash
sudo mkdir -p /var/log/wal-g
sudo chown postgres:postgres /var/log/wal-g
# WAL-G runs as the postgres OS user (called by PostgreSQL's archive_command).
# The log directory must be writable by the postgres user.
```

### 2.3 Create the configuration file

WAL-G supports **two** configuration mechanisms, and they are equivalent: environment variables,
or a config file passed with `--config /path`. Upstream: *"Every configuration variable mentioned
in the following documentation can be specified either as an environment variable or a field in
the config file."* Configuration is read through the Go [viper](https://github.com/spf13/viper)
package, so JSON, YAML and envfile all work.

**This deployment uses a YAML config file.** It is the cleaner of the two here:

- The configuration is **readable** (`sudo cat /etc/wal-g/wal-g.yaml`) rather than reconstructed
  by sourcing a file into a shell.
- Access is controlled by **ordinary file ownership**, not by whether some wrapper remembered to
  export the right variables.
- `--config` is **explicit at every call site**, so there is no invisible dependency on the
  ambient environment — which matters a great deal for `archive_command`, which PostgreSQL runs
  with a minimal environment of its own.
- It removes three wrapper scripts (see [2.4](#24-no-wrapper-scripts-how-the-commands-are-invoked)).

Either way, the important property is unchanged and non-negotiable: **credentials must not go in
`postgresql.conf`**, which is world-readable through `pg_settings` to anyone who can connect to
the database.

```bash
sudo mkdir -p /etc/wal-g

sudo tee /etc/wal-g/wal-g.yaml > /dev/null << 'EOF'
# WAL-G configuration for the CodeNforce production cluster.
# Passed explicitly via: wal-g --config /etc/wal-g/wal-g.yaml <command>
# CONTAINS CREDENTIALS - see the chown/chmod below.

# S3 prefix: bucket plus path prefix under which WAL-G stores every object.
# Format: s3://<bucket-name>/<prefix>
# Never share a prefix between two PostgreSQL clusters.
WALG_S3_PREFIX: "s3://cnf-wal-archive/cogdb"

# Backblaze B2 application key. These are B2 credentials, not AWS ones -
# WAL-G speaks the S3 API, so the settings carry AWS names.
#   AWS_ACCESS_KEY_ID     <- B2 "keyID" / applicationKeyId
#   AWS_SECRET_ACCESS_KEY <- B2 "applicationKey" (shown once, at creation)
# The bucket ID is NOT used anywhere: the S3 API addresses buckets by NAME
# (it appears in WALG_S3_PREFIX above). Bucket IDs belong to B2's own native
# API, which WAL-G never calls.
# Must be a scoped application key, NOT the master key - see 1.2.
AWS_ACCESS_KEY_ID: "CHANGEME_b2_keyID"
AWS_SECRET_ACCESS_KEY: "CHANGEME_b2_applicationKey"

# B2's S3-compatible API endpoint, from the bucket's Endpoint field (1.3).
#
# !! The setting is AWS_ENDPOINT. It is NOT AWS_ENDPOINT_URL - that is the
#    AWS CLI v2 name, and WAL-G does not recognise it. Using the wrong name
#    is NOT a hard error: WAL-G logs "AWS_ENDPOINT_URL is unknown", ignores
#    the value, and then talks to real Amazon S3, where your Backblaze key
#    naturally does not exist. The resulting 403 InvalidAccessKeyId points at
#    your credentials, which are fine. See Part 8.
AWS_ENDPOINT: "https://s3.us-west-004.backblazeb2.com"

# Region. Set it EXPLICITLY - it is effectively mandatory here.
# Without it WAL-G calls s3:GetBucketLocation to discover the region, and the
# application key in 1.2 is deliberately scoped to one bucket with "Allow List
# All Bucket Names: No", so that call can fail. Upstream: set AWS_REGION "if
# you wish to avoid this API call or forbid it from the applicable IAM policy."
# The value is the region segment of your endpoint hostname:
#   s3.<REGION>.backblazeb2.com  ->  us-west-004
# Read it off YOUR endpoint; do not copy 004 from this example.
AWS_REGION: "us-west-004"

# Compression. zstd is a good speed/ratio trade-off and crushes the
# mostly-empty segments that archive_timeout produces (~90%).
# Alternatives: lz4 (faster, worse ratio), lzma (better ratio, much slower),
#               brotli (good ratio, slower than zstd).
WALG_COMPRESSION_METHOD: "zstd"

# Delta backup chain depth. RATIFIED VALUE: 0 (which is also upstream's
# default, stated explicitly here because it is a deliberate choice).
# A non-zero value takes up to N delta backups before forcing a full one -
# attractive in principle, since blobbytes is write-once so most pages never
# change. But the value only means anything relative to CADENCE, and the cron
# in Part 5 runs backup-push WEEKLY. At N=6 that yields a genuine full backup
# only every 7 weeks, and 'delete retain FULL 4' would then pin roughly
# 28 WEEKS of WAL instead of the intended ~4, with restores walking a 7-link
# delta chain. 0 = every weekly run is a real full backup.
# Revisit only together with the cron schedule, never in isolation: N=6
# becomes correct the day a DAILY delta cron is added alongside the weekly full.
WALG_DELTA_MAX_STEPS: 0

# PostgreSQL data directory.
# NOT the packaged default - this cluster lives on a DO block volume.
# backup-push is ALSO given this path as an argument (Part 4). WAL-G compares
# the argument, the PGDATA env var and this setting and errors if they
# disagree - so listing it here turns a stale path into a loud failure rather
# than a silent backup of the wrong directory. Keep both; they cross-check.
PGDATA: "/mnt/vol_pg18data/pgdata/18/main"

# Connection settings. These are a CONTROL CHANNEL, not a selection of what
# gets backed up - see the note below the code block. Deliberately NOT the
# application's cogdb/sylvia pairing.
#
# A path (not an IP) makes WAL-G use the UNIX socket, which upstream prefers
# for localhost. Combined with PGUSER=postgres and Debian's default peer auth,
# this authenticates with no password and no .pgpass entry, because the
# process already runs as the postgres OS user.
PGHOST: "/var/run/postgresql"
PGUSER: "postgres"
PGDATABASE: "postgres"

# Explicit, because PG14 is still installed on 5433 until MW2 and a port
# mix-up between two live clusters is a bad way to find out libpq defaults
# to 5432.
PGPORT: "5432"
EOF

# Lock it down. The postgres OS user must be able to READ it - archive_command
# and the cron jobs both run as postgres - but nothing more.
sudo chown root:postgres /etc/wal-g/wal-g.yaml
sudo chmod 640 /etc/wal-g/wal-g.yaml      # root rw, postgres r, others none
sudo chown root:postgres /etc/wal-g
sudo chmod 750 /etc/wal-g                 # postgres needs +x to traverse

# Confirm the postgres user can actually read it - do this now, not after
# archive_mode is on:
sudo -u postgres head -1 /etc/wal-g/wal-g.yaml
```

> **YAML gotcha:** quote the credential values. B2 keys are alphanumeric today, but an unquoted
> scalar beginning with `%`, `*`, `&`, `@` or `` ` `` is a YAML syntax error, and one containing
> `: ` silently becomes a nested mapping. Quoting costs nothing and removes the class of problem.

#### Why `postgres`/`postgres` and not `sylvia`/`cogdb`

This looks wrong at first glance — every other connection on this host is `sylvia` → `cogdb` — so
it is worth being explicit that it is deliberate.

**`PGDATABASE` does not select what gets backed up.** WAL-G's `backup-push` is a **physical**
backup: it copies the data directory, so it captures the *entire cluster* — `cogdb`,
`cogdbpytest`, `mobiletestdb`, `postgres` and `template1` alike — no matter which database the
connection is made to. That connection exists only as a control channel, to call
`pg_backup_start()` / `pg_backup_stop()` and read cluster-level state. `postgres` is the
conventional choice because it is tiny, always present, and never dropped; pointing it at `cogdb`
would behave identically while needlessly coupling the backup to the application database being
reachable. `wal-push` needs no database connection at all.

**`PGUSER` must be a superuser, and `sylvia` isn't one.** `pg_backup_start()`/`pg_backup_stop()`
are restricted to superusers by default, and the role inventory taken during the upgrade confirmed
`sylvia` is `rolsuper = f` — it merely *owns* every object. `postgres` is the only superuser on
this cluster.

**Using a lesser role here would be security theatre anyway.** WAL-G has to read every file in
`$PGDATA`, so it runs as the `postgres` **OS** user regardless — meaning the process already has
raw filesystem access to all data in every database. Narrowing its *SQL* role would not reduce
what it can reach by one byte. Running as the postgres OS user over the socket is also what makes
peer authentication work, which is why no password or `.pgpass` entry appears anywhere in this
procedure.

**The useful contrast — this project has two backup identities, by design:**

| Layer | Kind | Connects as | To | Why |
|---|---|---|---|---|
| WAL-G (Layer 2) | **physical** — whole cluster, file-level | `postgres` superuser, peer auth over the socket | `postgres` (irrelevant) | Needs the backup-control functions; database choice has no effect on contents |
| `cnfprodbak.sh` / `pg_dump` (Layer 3) | **logical** — one database, row-level | a read-only role (`cnf_backup`, tracked as ROL.1) | **`cogdb`** | Must actually read every table *inside* that database |

So the `sylvia`/`cogdb` instinct is right — for the *logical* dump path, where the connection is
doing the work. It just doesn't apply to the physical one, where the connection is only issuing
two function calls.

### 2.4 No wrapper scripts — how the commands are invoked

Earlier revisions of this document wrapped every invocation in a shell script whose only job was
`set -a; source /etc/wal-g.env; set +a`. **That was compensating for a problem WAL-G does not
have.** With `--config`, each call site names its own configuration and needs no environment at
all:

| Call site | Invocation |
|---|---|
| `archive_command` | `wal-g --config /etc/wal-g/wal-g.yaml wal-push %p` |
| `restore_command` | `wal-g --config /etc/wal-g/wal-g.yaml wal-fetch %f %p` |
| cron — base backup | `wal-g --config /etc/wal-g/wal-g.yaml backup-push <PGDATA>` |
| cron — retention | `wal-g --config /etc/wal-g/wal-g.yaml delete retain FULL 4 --confirm` |
| interactive | same, prefixed with `sudo -u postgres` |

`--config` is a global flag, so it goes **before** the subcommand.

**Nothing else is needed.** There are no `wal-g-archive.sh` / `wal-g-restore.sh` /
`wal-g-backup.sh` / `wal-g-retention.sh` scripts in this setup; if you are reading an older copy
of this procedure that creates them, they can be deleted along with `/etc/wal-g.env`.

> #### The one place a wrapper still has a real justification — `restore_command`
>
> This is not about the environment; it is about **exit codes**, and it only affects recovery.
>
> PostgreSQL treats *any* non-zero exit from `restore_command` as "that segment isn't available,
> so recovery is finished" — which is correct at the end of a PITR, and catastrophic if the real
> cause was a network failure or bad credentials, because the cluster then promotes having
> replayed less WAL than exists. Upstream is explicit about the distinction: `wal-fetch` exits
> **74** when the segment genuinely isn't in the archive, and **1** for every other error, adding
> that anything other than 74 *"should stop PostgreSQL rather than ending PostgreSQL recovery. For
> PostgreSQL that should be any error code between 126 and 255, which can be achieved with a
> simple wrapper script."*
>
> The bare `restore_command` above is acceptable and is what most deployments run. If you want the
> safer behaviour, this is the wrapper — and note it is used **only during a restore**, so it has
> no bearing on steady-state archiving:
>
> ```bash
> sudo tee /usr/local/bin/wal-g-restore.sh > /dev/null << 'EOF'
> #!/bin/bash
> # restore_command wrapper. Maps "real failure" to an exit code that makes
> # PostgreSQL ABORT recovery rather than quietly declare it complete.
> #   74 = segment legitimately absent -> pass through, ends recovery normally
> #   anything else = a real error     -> 255, which halts recovery
> /usr/local/bin/wal-g --config /etc/wal-g/wal-g.yaml wal-fetch "$1" "$2"
> rc=$?
> [ "$rc" -eq 0 ] && exit 0
> [ "$rc" -eq 74 ] && exit 74
> exit 255
> EOF
> sudo chmod 0755 /usr/local/bin/wal-g-restore.sh
> ```
>
> Then `restore_command = '/usr/local/bin/wal-g-restore.sh %f %p'`. Deliberately no `set -e` here
> — the whole point is to inspect `$?` rather than abort on it.

---

## Part 3: PostgreSQL configuration

> ### ⚠ STOP — run [§6.3](#63-test-a-wal-segment-archive-manually) before this Part
>
> **This document's section order is not its execution order.** Part 3 turns `archive_mode` on;
> §6.3 proves the `archive_command` actually works. **§6.3 must come first**, and it lives in Part 6
> only because that is where the rest of the verification lives.
>
> The reason is asymmetric risk. With `archive_mode = on` and a broken `archive_command`,
> PostgreSQL does the correct thing — it refuses to recycle any WAL segment it could not archive —
> and `pg_wal/` grows without bound until the filesystem fills and **the database stops**. On this
> host that is the block volume's ~47 GB. Before flipping the switch, the command is harmless to
> run and a failure costs nothing.
>
> ```bash
> # The whole gate, in one line. Exit code 0 and nothing else will do.
> sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml wal-push \
>   /mnt/vol_pg18data/pgdata/18/main/pg_wal/<any-existing-segment>
> ```
>
> This proves the binary, the config path, the `postgres` user's read access to it, the B2
> credentials, the endpoint and region, and the network path — all at once, while nothing is at
> stake. Only then apply Part 3.

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
#
# --config makes this self-contained: PostgreSQL runs archive_command with a
# minimal environment of its own, and with an explicit config path that does
# not matter. No wrapper script, no sourcing, nothing to export.
# The config file must be readable by the postgres OS user (2.3).
#
# NOTE the redirect: wal-g's output goes to its own log, which keeps ~96
# INFO lines a day out of the PostgreSQL log. The trade-off is that a FAILING
# archive_command shows up in the PostgreSQL log only as an exit code - the
# error text is in /var/log/wal-g/archive.log. Those two places, plus
# pg_stat_archiver, are where you look (Part 6).
#
# A literal % must be written %% in archive_command. There are none here.
archive_command = 'wal-g --config /etc/wal-g/wal-g.yaml wal-push %p >> /var/log/wal-g/archive.log 2>&1'

# Maximum time between WAL segment archives, even if the segment is not full.
# A 16MB WAL segment at low transaction volume could take hours to fill.
# archive_timeout forces a segment switch (and therefore an archive call)
# at least every N seconds, bounding the worst-case RPO.
#
# RATIFIED VALUE: 900 (15 minutes).
# Worst-case data loss is the last 15 minutes of work - which is the sentence
# a code officer would actually hear. Against the <=4h RPO target in
# cnf-backup-strategy.md that is 16x better than requirement.
#
# Each forced segment is a full 16MB file no matter how little real data it
# holds, so the raw daily ceiling is:
#     86400 / 900 = 96 segments/day  x  16MB  =  ~1.5 GB/day
# That ceiling is never reached in practice: writes are confined to roughly a
# 10-hour window Mon-Fri, so most of those 96 segments are near-empty, and
# zstd compresses near-empty WAL by roughly 90%. Realistic B2 ingest is on
# the order of 150-300 MB/day - single-digit GB/month, which is noise.
#
# The earlier 60s draft was not wrong, just wildly over-bought: 1440 segments
# a day, 15x the object count and request volume, for an RPO improvement
# nobody had asked for.
# Requires reload only (sighup-level parameter).
archive_timeout = 900

# Store the restore_command here for reference.
# This is used during recovery, not during normal operation.
# It can be set here (PostgreSQL 12+) instead of in a recovery.conf file.
# Commented out during normal operation; uncomment only during a restore.
# See 2.4 for why you may prefer the exit-code-mapping wrapper here -
# it is the one place in this setup where a wrapper earns its keep.
# restore_command = 'wal-g --config /etc/wal-g/wal-g.yaml wal-fetch %f %p'
```

Apply the changes:

```bash
# wal_level and archive_mode require a restart:
sudo pg_ctlcluster 18 main restart

# Verify the restart succeeded:
pg_lsclusters
sudo -u postgres psql -c "SELECT version();"

# Verify the archive parameters took effect:
sudo -u postgres psql -c "
  SELECT name, setting
  FROM pg_settings
  WHERE name IN ('wal_level','archive_mode','archive_command','archive_timeout');"
```

> **Restarting PostgreSQL drops every pooled application connection.** WildFly will keep handing
> out the dead sockets until its pool is refreshed, so expect the application to fail on the first
> statement of every request until it is restarted. That is not a database fault — see
> [§8.6](#86-the-cluster-is-online-but-the-application-cannot-query-it). Plan the application
> restart into the same window.

> **Backing these settings out** — if you need to return to baseline, comment the lines out and
> **restart**, not reload: `archive_mode` is postmaster-level, so a reload leaves it *on*. Confirm
> with `SHOW archive_mode;` rather than by reading the file.

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
# The cluster is ~95GB on disk. At typical VPS uplink speed that is roughly
# 45 minutes to 3 hours, bounded by upload throughput rather than by disk.
# It is also the most interruptible step here: nothing else depends on it,
# so it is safe to leave running while you do something else.
#
# !! PASS THE DATA DIRECTORY. Omitting it does NOT fall back to the PGDATA in
#    the config file - upstream: "To stream the backup data, leave out the
#    data directory." A bare `backup-push` switches to REMOTE mode over the
#    BASE_BACKUP protocol, which is single-threaded, needs replication
#    privileges, and does not support delta backups. Not what we want.
#    With the path given, WAL-G checks it against the config's PGDATA and the
#    PGDATA env var and errors if they disagree - a free stale-path check.

sudo -u postgres /usr/local/bin/wal-g --config /etc/wal-g/wal-g.yaml \
  backup-push /mnt/vol_pg18data/pgdata/18/main \
  >> /var/log/wal-g/backup-push.log 2>&1

# Monitor progress:
tail -f /var/log/wal-g/backup-push.log

# Verify the backup appears in B2:
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml backup-list
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
# With WALG_DELTA_MAX_STEPS=0 this is always a genuine full backup.
# --config carries the whole configuration, so the cron environment is
# irrelevant. Run as the postgres user, who owns PGDATA.
# The data directory MUST be passed: omitting it selects remote BASE_BACKUP
# streaming mode, not the config's PGDATA (see Part 4). WAL-G cross-checks the
# argument against the config, so a stale path here fails loudly.
0 2 * * 0 postgres /usr/local/bin/wal-g --config /etc/wal-g/wal-g.yaml backup-push /mnt/vol_pg18data/pgdata/18/main >> /var/log/wal-g/backup-push.log 2>&1

# Retention management: runs after the backup-push window.
# 'delete retain FULL 4' keeps the 4 most recent full backups and all WAL
# segments needed to restore any of them. Anything older is deleted from B2.
# --confirm is required; without it, delete only reports what it would do.
# 04:00 rather than 03:00: a 95GB backup-push can legitimately run for hours,
# and starting cleanup while it is still uploading is asking for trouble.
0 4 * * 0 postgres /usr/local/bin/wal-g --config /etc/wal-g/wal-g.yaml delete retain FULL 4 --confirm >> /var/log/wal-g/delete.log 2>&1
EOF

# Verify cron is installed:
cat /etc/cron.d/wal-g
```

**Two cron-specific details worth knowing.** Cron runs jobs with a near-empty environment and a
`PATH` of roughly `/usr/bin:/bin` — which is exactly why the historical
`. /etc/wal-g.env && wal-g …` formulation was such a trap, and why `--config` plus the **absolute**
`/usr/local/bin/wal-g` is the robust shape. Also, `%` is special in crontab files (it means
newline) and must be escaped as `\%` — none of these lines contain one, but remember it if you
ever add a `date +%F` to a log filename.

Prove the retention job by hand before trusting the schedule:

```bash
sudo -u postgres /usr/local/bin/wal-g --config /etc/wal-g/wal-g.yaml \
  delete retain FULL 4 --confirm
# On a fresh archive this deletes nothing - there is only one backup to retain -
# but it does prove the credentials, the config path, and the DELETE permission
# on the B2 application key all work. Better to learn that now than from a
# silently failing cron job five weeks from now.
```

### 5.1 Log rotation (do not skip)

`archive_command` fires ~96 times a day and appends every time, so `/var/log/wal-g/archive.log`
grows forever otherwise.

```bash
sudo tee /etc/logrotate.d/wal-g > /dev/null << 'EOF'
/var/log/wal-g/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0640 postgres postgres
}
EOF

# Dry run - prints what it WOULD do, changes nothing:
sudo logrotate -d /etc/logrotate.d/wal-g
```

**`create 0640 postgres postgres` is the load-bearing line.** WAL-G runs as the `postgres` OS user
via `archive_command`. If logrotate creates the replacement log owned by root, the next
`wal-g wal-push` cannot write to it, `archive_command` returns
non-zero — at which point PostgreSQL, correctly, refuses to recycle WAL segments. `pg_wal/` then
grows until the filesystem fills and the database stops. A log-rotation permission bug is a
genuine path to an outage here, which is why the dry run is worth the thirty seconds.

**Note on daily vs. weekly base backups:** weekly fulls with continuous WAL archiving is the right
starting point for this workload, and with `WALG_DELTA_MAX_STEPS=0` every weekly run is a genuine
full backup rather than a link in a chain. The natural next step — once the archive has proven
itself — is daily deltas alongside the weekly full: set `WALG_DELTA_MAX_STEPS=6` **and** add a
Mon–Sat `backup-push` cron in the same change. That gives a daily recovery anchor instead of a
weekly one, tightening RTO, and the deltas are cheap because `blobbytes` is write-once. Change
both together or not at all — the step count and the cron cadence are a single decision.

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

# Monitor pg_wal/ size as a leading indicator.
# NOTE the volume path: pg_wal lives inside PGDATA, so it is on the block
# volume, NOT under /var/lib/postgresql.
du -sh /mnt/vol_pg18data/pgdata/18/main/pg_wal/
df -h /mnt/vol_pg18data
# Normal: stable at a few hundred MB
# Problem: growing continuously toward GB scale. The volume has ~47GB free,
# so a stalled archive has a finite - and not especially long - runway before
# it takes the database down.
```

### 6.2 Verify the archive has no gaps

```bash
# wal-g wal-show inspects the WAL segment sequence in B2.
# It reports all timelines, associated backups, and checks for missing segments.
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml wal-show
# Output status:
#   OK: continuous WAL chain, no gaps. PITR is possible across the full range.
#   LOST_SEGMENTS: gap in the WAL sequence. PITR is not possible across the gap.
#                  Segments before the gap may still be restorable to a point
#                  within the pre-gap window.
```

### 6.3 Test a WAL segment archive manually

Before enabling `archive_mode`, run the exact command `archive_command` will run. This is the
single most valuable check in Part 6 — it proves the binary, the config path, the postgres user's
read access to the config, the B2 credentials, and the network path, all at once, while a failure
is still harmless.

```bash
# Find a recent WAL segment to test with:
ls /mnt/vol_pg18data/pgdata/18/main/pg_wal/ | head -5
# Note a segment filename, e.g.: 000000010000000000000005

# Run it exactly as PostgreSQL will - same user, same config, same argument
# shape (%p is an absolute path here):
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml wal-push \
  /mnt/vol_pg18data/pgdata/18/main/pg_wal/000000010000000000000005

# Exit code 0 is the thing being tested - it is precisely what PostgreSQL
# looks at once archive_mode is on:
echo "exit: $?"

# If it fails and the reason is not obvious, this prints the configuration
# WAL-G actually loaded, which settles "is it reading my config file at all?":
sudo -u postgres WALG_LOG_LEVEL=DEVEL wal-g --config /etc/wal-g/wal-g.yaml wal-show

# Verify the segment appears in B2:
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml wal-show
```

### 6.4 Test the restore path (critical)

Verify that WAL segments can be fetched back from B2. This exercises the credentials, the network path, and the whole restore direction before you need them in an actual incident.

```bash
# Fetch a specific WAL segment from B2 to a temporary location:
SEGMENT="000000010000000000000005"
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml \
  wal-fetch "${SEGMENT}" "/tmp/test_fetch_${SEGMENT}"

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
3. Confirm **Default Retention** is set to Compliance mode, **14 days**

Test immutability (optional, requires a throwaway object):
1. Upload a test file to the bucket via the console or B2 CLI
2. Attempt to delete it within the retention window — it should be rejected
3. Then wait for the test object to expire naturally (14 days). Under Compliance mode not even B2 support can remove it early — which is the whole point, and also the reason to keep the test object small

---

## Part 8: Troubleshooting

### 8.1 "PostgreSQL is down" — check that claim before acting on it

On Debian and Ubuntu, `postgresql.service` is a **do-nothing meta-unit** (`Type=oneshot`,
`RemainAfterExit=yes`). It starts the real per-cluster units and exits. So this output:

```
● postgresql.service - PostgreSQL RDBMS
     Active: active (exited) since Sun 2026-09-13 22:40:47 EDT; 2h 11min ago
   Main PID: 1782 (code=exited, status=0/SUCCESS)
```

is the **normal, healthy** state. It says nothing whatsoever about whether the cluster is running,
and `sudo service postgresql start` against it is usually a silent no-op, because systemd sees the
meta-unit as already active.

**Ask the right things instead:**

```bash
pg_lsclusters                                                   # THE answer: online / down, port
sudo systemctl status postgresql@18-main.service --no-pager -l  # the real unit
```

> **`Owner` showing `<unknown>` in `pg_lsclusters` is a display artifact, not a fault.**
> `pg_lsclusters` reports the owner by `stat`-ing the data directory, and `$PGDATA` is mode `0700`
> owned by `postgres`. An unprivileged user cannot traverse into it, so the lookup fails and the
> column reads `<unknown>`. Run `sudo pg_lsclusters` and it says `postgres`.
>
> The logic is airtight in the other direction too: PostgreSQL **refuses to start** unless
> `$PGDATA` is owned by the server user and mode `0700`/`0750`. If the cluster shows `online`,
> its ownership is by definition correct.

Also note that **nothing in `/etc/wal-g/wal-g.yaml` can affect PostgreSQL.** It is an inert file
that only the `wal-g` binary reads. If the cluster genuinely will not start after working through
this procedure, the cause is in `postgresql.conf` (Part 3), not the WAL-G config.

### 8.2 Where the logs are

| What | Where |
|---|---|
| **PostgreSQL server log** — startup failures, config syntax errors, archive-command exit codes | `/var/log/postgresql/postgresql-18-main.log` |
| systemd's view of the cluster unit | `sudo journalctl -u postgresql@18-main.service -n 80 --no-pager` |
| WAL-G `archive_command` output | `/var/log/wal-g/archive.log` |
| WAL-G `backup-push` output | `/var/log/wal-g/backup-push.log` |
| WAL-G retention output | `/var/log/wal-g/delete.log` |

```bash
# Most useful single command when something just broke:
sudo tail -n 100 /var/log/postgresql/postgresql-18-main.log

# Follow it live while starting the cluster in another shell:
sudo tail -f /var/log/postgresql/postgresql-18-main.log

# Just the bad news:
sudo grep -E 'FATAL|PANIC|ERROR' /var/log/postgresql/postgresql-18-main.log | tail -40
```

**Start the cluster the way that tells you why it failed.** `pg_ctlcluster` reports the actual
error; `service postgresql start` hides it:

```bash
sudo pg_ctlcluster 18 main start
```

A bad `postgresql.conf` value yields `FATAL: configuration file ... contains errors` with a line
number.

**"We edited `postgresql.conf` and didn't take a backup."** You almost certainly have one anyway,
and you do not need to guess at what changed:

```bash
# 1. The PG14 config still exists and is untouched by any PG18 edit. pg_upgradecluster
#    COPIED it into the 18 tree at upgrade time, so diffing the two shows your edits
#    (plus a handful of genuine version-default differences).
sudo diff -u /etc/postgresql/14/main/postgresql.conf \
             /etc/postgresql/18/main/postgresql.conf

# 2. Better still - ask the running server what it actually loaded, with file and
#    line number for every non-default setting. This is authoritative; the file on
#    disk may contain lines that were never applied.
sudo -u postgres psql -c "
  SELECT name, setting, sourcefile, sourceline
  FROM pg_settings
  WHERE source = 'configuration file'
  ORDER BY sourcefile, sourceline;"

# 3. The packaged pristine default, if you want a clean reference:
ls /usr/share/postgresql/18/postgresql.conf.sample
```

### 8.3 `psql` "Peer authentication failed" is not an outage

```
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed:
FATAL:  Peer authentication failed for user "postgres"
```

Expected. The local socket uses **peer** auth, which requires the OS user to match the database
role. Use:

```bash
sudo -u postgres psql -p 5432 -c "SELECT version();"
```

### 8.4 `WARNING: <SETTING> is unknown` — the value is being ignored

WAL-G validates setting *names* and warns about ones it does not recognise, but **it does not
stop**. An unrecognised setting is silently dropped, and WAL-G proceeds with the default for
whatever that setting controlled. Treat this warning as an error.

The one that bites hardest:

| Wrong | Right | Why it happens |
|---|---|---|
| `AWS_ENDPOINT_URL` | **`AWS_ENDPOINT`** | `AWS_ENDPOINT_URL` is the AWS CLI v2 / SDK convention. WAL-G uses `AWS_ENDPOINT` |

**The failure signature, in full**, because none of it points at the real cause:

```
WARNING: AWS_ENDPOINT_URL is unknown
WARNING: We found that some variables in your config file detected as 'Unknown'.
ERROR: Failed to configure multi-storage: ... AWS region isn't configured explicitly:
       detect region: detect region by bucket: InvalidAccessKeyId: The AWS Access Key Id
       you provided does not exist in our records. status code: 403
```

Read that chain backwards: the endpoint was dropped → WAL-G used the **default AWS endpoint** →
it tried to auto-detect the region via `GetBucketLocation` **against Amazon** → Amazon correctly
reported that a *Backblaze* key ID does not exist in its records. **The credentials are almost
certainly fine.** Fix `AWS_ENDPOINT`, set `AWS_REGION`, retry.

Confirm what WAL-G actually loaded:

```bash
sudo -u postgres WALG_LOG_LEVEL=DEVEL wal-g --config /etc/wal-g/wal-g.yaml backup-list
# DEVEL prints the effective configuration. Check the endpoint is present
# and that no line is reported as Unknown.
```

### 8.5 Emergency brake — `archive_mode = on` with a broken `archive_command`

If archiving is enabled and failing, PostgreSQL refuses to recycle WAL segments and `pg_wal/`
grows until the filesystem fills and the database stops. On this host that filesystem is the block
volume, with roughly 47 GB of headroom.

```bash
sudo -u postgres psql -c \
  "SELECT failed_count, last_failed_wal, last_failed_time FROM pg_stat_archiver;"
du -sh /mnt/vol_pg18data/pgdata/18/main/pg_wal/
df -h /mnt/vol_pg18data
```

If `failed_count` is climbing, neutralise it. `archive_command` is **sighup-level**, so this is a
reload, not a restart:

```ini
archive_command = '/bin/true'
```

```bash
sudo pg_ctlcluster 18 main reload
```

> **Know what that costs.** `/bin/true` tells PostgreSQL every segment was archived successfully
> when it was not, so those segments are recycled and lost from the archive — a permanent,
> unrepairable gap. That is acceptable **only before the first successful `backup-push`**, when
> there is no archive to put a hole in. Once a base backup exists, do not do this: fix the real
> problem, or accept the WAL growth while you fix it and watch `df` closely.

### 8.6 The cluster is online but the application cannot query it

If `pg_lsclusters` says `online` and `sudo -u postgres psql -c "SELECT 1"` works, but WildFly
fails on its first statement of every request, the database is not the problem — the **connection
pool** is.

**A PostgreSQL restart invalidates every pooled connection.** Part 3 requires a restart
(`wal_level` and `archive_mode` are postmaster-level), and unless the datasource is configured to
validate connections before handing them out, WildFly will keep serving sockets that are already
dead. Every request then fails immediately, on whatever its first query happens to be — which
makes it look like a query or permissions problem rather than a plumbing one.

Distinguish the two in one step, from the database side:

```bash
# Is anything actually connected, and what is it doing?
sudo -u postgres psql -c "
  SELECT pid, usename, datname, state, backend_start,
         left(query, 60) AS query
  FROM pg_stat_activity
  WHERE backend_type = 'client backend';"

# Did the server reject or error on anything recently? The application's own
# exception text is usually its own wrapper message - the real SQLSTATE and
# message are here:
sudo grep -E 'FATAL|ERROR' /var/log/postgresql/postgresql-18-main.log | tail -30
```

- **PostgreSQL log shows the failing statement** → a real SQL/permissions problem. Fix that.
- **PostgreSQL log shows nothing at all** → the queries never reached the server. Stale pool.
  Restarting the application (or flushing the datasource pool) clears it.

**Worth fixing properly once seen:** enable background validation on the datasource so a database
restart degrades into a few retried connections instead of a hard application outage.

### 8.7 `Failed to find any configured storage`

```
ERROR: Failed to find any configured storage
```

**You omitted `--config`.** Nothing else produces this. WAL-G found no storage settings at all, so
it never attempted to contact B2 — this is not a credentials, endpoint or network problem.

Without `--config`, WAL-G looks only at environment variables and its default config location
(`~/.walg.json`). It has no knowledge of `/etc/wal-g/wal-g.yaml`. Every invocation must name it:

```bash
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml backup-list
```

Use `sudo -u postgres`, not bare `sudo`. Running as root works — root can read any file — but it
skips the check that matters: whether the **`postgres`** user can read the config, which is exactly
how `archive_command` and the cron jobs will invoke it. A `0640 root:postgres` file that got its
group wrong will pass as root and fail in production.

### 8.8 What can be tested before touching `postgresql.conf`

Everything that matters, which is why the Part 3 gate is cheap to respect. None of these require
`archive_mode`, and none of them can disturb a running cluster:

| Test | Proves |
|---|---|
| `wal-g --config … backup-list` | Config path, credentials, endpoint, region, network. Touches PostgreSQL not at all |
| `wal-g --config … wal-push <segment>` ([§6.3](#63-test-a-wal-segment-archive-manually)) | The exact command `archive_command` will run, end to end |
| `wal-g --config … wal-fetch <segment> /tmp/x` ([§6.4](#64-test-the-restore-path-critical)) | The restore direction |

On a fresh bucket, `backup-list` returning an **empty list** — or a "no backups found" notice — is
**success**. You are not looking for backups; you are looking for the absence of a `403` or an
endpoint error. A healthy first run looks like this:

```
INFO: List backups from storages: [default]
INFO: No backups found
```

That is the config being read, B2 answering, and credentials accepted — plus, just as importantly,
**no `WARNING: ... is unknown` lines**, which is how you know every key in the YAML is spelled in
WAL-G's vocabulary rather than the AWS CLI's.

> **Two things `backup-list` does not prove.**
>
> **Write access.** It is a read. A key provisioned read-only passes this and fails at `wal-push`.
>
> **That `WALG_S3_PREFIX` is correct.** An empty result is indistinguishable between the right
> prefix and a mistyped one — both contain nothing. Confirm the prefix by eye *before* the first
> write, because under Compliance-mode Object Lock a typo becomes undeletable for the full
> retention period, by anyone, including Backblaze:
>
> ```bash
> sudo grep WALG_S3_PREFIX /etc/wal-g/wal-g.yaml
> ```

---

## Monitoring checklist (ongoing)

Add the following to whatever monitoring practice applies to the VPS:

| Check | Frequency | Healthy condition | Action if unhealthy |
|---|---|---|---|
| `pg_stat_archiver.failed_count` | Daily | 0 | Investigate `archive_command` failures; check `/var/log/wal-g/archive.log` |
| `pg_stat_archiver.last_archived_time` | Hourly | Within last 2 minutes | Archive may be stalled; check `pg_wal/` size |
| `pg_wal/` directory size | Hourly | Stable, <1GB | Growing size = archive backlog; risk of WAL storm |
| `wal-g --config /etc/wal-g/wal-g.yaml backup-list` | Weekly | New backup present after cron window | Cron may have failed; check `/var/log/wal-g/backup-push.log` |
| `wal-g --config /etc/wal-g/wal-g.yaml wal-show` | Weekly | Status: OK | LOST_SEGMENTS means a gap; PITR may be limited |
| B2 bucket size | Monthly | Growing as expected, within budget | Unexpected growth may indicate retention deletion failing |

---

## Operational notes

**Credential rotation:** The B2 application key lives in `/etc/wal-g/wal-g.yaml` and should be rotated annually, or immediately on any suspicion of compromise. To rotate: create a new application key in the B2 console with the same scope and permissions, edit the two values in the YAML, and you are done — **no service restart or reload is required anywhere.** Both `archive_command` and the cron jobs read the file fresh on every single invocation, because `--config` is resolved per-process. Verify the new key before deleting the old one in B2: `sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml backup-list`.

**WAL-G binary updates:** When a new release is published, repeat Part 2.1 — and **re-derive the asset filename from that release's own Assets list rather than reusing the one above.** Upstream has changed the naming scheme at least once (older releases carried an `ubuntu-` segment that current ones do not), and a stale filename returns a 404 that `curl -f` will catch and a bare `curl -L` will not. WAL-G is backward-compatible: a newer binary reads archives written by older versions. After each update, confirm the new binary can read the existing archive:

```bash
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml backup-list
sudo -u postgres wal-g --config /etc/wal-g/wal-g.yaml wal-show
```

**B2 egress costs:** Recovery operations that fetch WAL segments and base backups from B2 incur egress charges above Backblaze's free allowance of 3× the monthly average stored. At ~95 GB stored per full backup that allowance is comfortably larger than a single full restore. Several restores in one month could exceed it; at $0.01/GB the overage stays small (a 95 GB restore beyond the free tier is under $1). Do not let egress anxiety discourage restore drills — an untested backup is not a backup.
