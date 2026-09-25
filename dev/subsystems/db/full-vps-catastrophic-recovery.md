---
title: Full VPS Catastrophic Recovery — Restore CodeNforce Stack from Scratch
description: Step-by-step procedure for rebuilding the entire CodeNforce production stack on a fresh Ubuntu VPS at a non-DigitalOcean provider. Covers OS setup, package installation, PostgreSQL restore from WAL-G, WildFly/Spring Boot deployment, Redis, nginx, and Docker configuration. Used both for DR testing and for genuine catastrophic recovery.
published: true
date: 2026-09-07
tags: [disaster-recovery, restore, postgresql, wildfly, nginx, redis, docker, runbook, infrastructure]
editor: markdown
dateCreated: 2026-09-07
---

# Full VPS Catastrophic Recovery — Restore CodeNforce Stack from Scratch

## How to use this document

This procedure has two modes:

**DR test mode:** You are deliberately validating the recovery process on a temporary VPS. The production system is still running. Take your time, document deviations from expected behavior, and update the procedure afterward.

**Actual catastrophic recovery mode:** Production is down. Work through steps in order without skipping. Communicate status to TCVCOG at each major milestone. Timebox each phase and note actual elapsed time against the RTO target.

---

## Prerequisites

Before starting, confirm you have access to:

- [ ] Backblaze B2 credentials (or know where they are)
- [ ] WAL-G environment config values (from `/etc/wal-g/wal-g.yaml` on the production VPS, or from a secure credential store)

> **⚠ Configuration mechanism changed.** This document still builds `/etc/wal-g.env` and wrapper
> scripts that source it. Current practice is a native YAML config at `/etc/wal-g/wal-g.yaml`
> passed with `--config`, and **no wrapper scripts** — see `wal-g-setup.md` §2.3–2.4, which is the
> authoritative version. The env-var approach below still works (WAL-G supports both), so this
> document is not *wrong*, merely out of step; but a rebuilt VPS should match production. Tracked
> as F13 in the `codenforce` repo.
- [ ] WD Elements drive (for fallback pg_dump restore if B2 is unreachable)
- [ ] SSH private key for the new VPS (generate fresh or use your existing `~/.ssh/your_do_key`)
- [ ] The WildFly deployment artifact (`.war` or `.ear` file) — where does the current version live? This must be answered before a real incident. Options: git repo, artifact server, copy from production VPS if still accessible.
- [ ] nginx configuration — ideally in the git repo; otherwise copy from production before it goes down
- [ ] Redis configuration — note any non-default settings on the production instance
- [ ] Docker container definitions — `docker-compose.yml` or equivalent, in git
- [ ] DNS access — ability to update the A record pointing your domain at the new VPS IP

**The single most important pre-incident action:** ensure all configuration files (nginx, WildFly standalone.xml or domain.xml, Docker compose files) are committed to the git repository. Configuration that exists only on the production VPS is lost when the VPS is lost. This is a gap to close before this runbook is needed for real.

---

## Phase 0: Provision the new VPS

**Estimated time:** 5–10 minutes

```bash
# At the chosen provider's control panel (Vultr recommended per vps-provider-alternatives.md):
# 1. Create new instance:
#    - OS: Ubuntu 24.04 LTS
#    - Plan: 8 GB RAM, closest available to 250 GB storage
#      (attach a block volume if local disk is insufficient)
#    - Region: geographically separate from DigitalOcean
#      (for Vultr: Dallas TX or Atlanta GA are good choices for western PA)
#    - SSH key: inject your public key at provisioning time
#    - Hostname: cnf-recovery-YYYYMMDD
#
# 2. Note the new VPS's public IPv4 address. This is what DNS will point at.
#
# 3. SSH in as root (or ubuntu, depending on provider):
ssh -i ~/.ssh/your_key root@NEW_VPS_IP

# Confirm you are on the new machine, not accidentally on the production VPS:
hostname
uname -a
# Should show a fresh Ubuntu 24.04 system.
```

---

## Phase 1: OS baseline

**Estimated time:** 10–15 minutes

```bash
# --- P1.1: Update the system ---
apt update && apt upgrade -y
# Full upgrade before installing anything else — avoids dependency conflicts
# between freshly installed packages and stale base packages.

# --- P1.2: Set the hostname ---
hostnamectl set-hostname cnf-recovery
# Optional but helps distinguish this machine in logs and shell prompts.

# --- P1.3: Create a non-root user ---
# Running everything as root is a security liability.
# Create a user matching the production convention.
adduser echocdelta
# Follow prompts: set a password, fill in fields or leave blank.

usermod -aG sudo echocdelta
# Add to sudo group so the user can elevate when needed.

# Copy authorized_keys so the same SSH key works for this user:
mkdir -p /home/echocdelta/.ssh
cp /root/.authorized_keys /home/echocdelta/.ssh/authorized_keys
# Adjust the source path depending on how the provider injected your key.
chown -R echocdelta:echocdelta /home/echocdelta/.ssh
chmod 700 /home/echocdelta/.ssh
chmod 600 /home/echocdelta/.ssh/authorized_keys

# --- P1.4: Basic firewall ---
# ufw (Uncomplicated Firewall) wraps iptables for straightforward rule management.
ufw allow OpenSSH
# Allow SSH before enabling the firewall, or you will lock yourself out.
ufw allow 80/tcp
# HTTP — nginx will listen here.
ufw allow 443/tcp
# HTTPS — nginx TLS termination.
# Add additional ports as needed for application-specific access.
# Do NOT open PostgreSQL port (5432) publicly — it should only be accessible
# from localhost on this single-VPS setup.
ufw --force enable
# --force skips the interactive confirmation prompt.
ufw status verbose
# Confirm rules look correct before proceeding.

# --- P1.5: Install essential tools ---
apt install -y \
  curl \
  wget \
  git \
  htop \
  tmux \
  # tmux: run long-duration commands (pg_restore, large downloads) in a
  # session that survives SSH disconnection. Install it before you need it.
  unzip \
  gnupg \
  ca-certificates \
  lsb-release \
  software-properties-common
```

---

## Phase 2: Install PostgreSQL 18

**Estimated time:** 5 minutes

Ubuntu's default apt repositories lag behind PostgreSQL releases. Install from the official PGDG repository to get the correct version.

```bash
# --- P2.1: Add the PGDG apt repository ---
# Import the PostgreSQL signing key:
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg
# -f: fail silently on HTTP errors (don't save error pages as the key file)
# -s: silent mode
# -S: show errors even in silent mode
# -L: follow redirects
# gpg --dearmor: convert ASCII-armored GPG key to binary format
# -o: write to this file

# Add the PGDG repository source:
echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] \
  https://apt.postgresql.org/pub/repos/apt \
  $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list
# $(lsb_release -cs) outputs the Ubuntu release codename (e.g., 'noble' for 24.04)
# This pins the repository to the correct Ubuntu version.

# --- P2.2: Install PostgreSQL 18 ---
apt update
apt install -y postgresql-18

# Verify the cluster was created and is running:
pg_lsclusters
# Should show: 18  main  5432  online  postgres  /var/lib/postgresql/18/main

# --- P2.3: Install WAL-G ---
# The specific version and binary name may change — check GitHub releases.
WALG_VERSION="v3.0.3"
curl -L \
  "https://github.com/wal-g/wal-g/releases/download/${WALG_VERSION}/wal-g-pg-ubuntu-20.04-amd64.tar.gz" \
  -o /tmp/wal-g.tar.gz
tar -xzf /tmp/wal-g.tar.gz -C /tmp/
mv /tmp/wal-g-pg /usr/local/bin/wal-g
chmod +x /usr/local/bin/wal-g
wal-g --version
# Confirm it runs.

# --- P2.4: Create the WAL-G environment file ---
# Copy values from your credential store or the production /etc/wal-g.env.
cat > /etc/wal-g.env << 'EOF'
WALG_S3_PREFIX=s3://cnf-wal-archive/cogdb
AWS_ACCESS_KEY_ID=your_b2_application_key_id_here
AWS_SECRET_ACCESS_KEY=your_b2_application_key_here
AWS_ENDPOINT_URL=https://s3.us-west-004.backblazeb2.com
WALG_COMPRESSION_METHOD=zstd
PGDATA=/var/lib/postgresql/18/main
PGUSER=postgres
PGDATABASE=postgres
EOF

chown root:postgres /etc/wal-g.env
chmod 640 /etc/wal-g.env

# --- P2.5: Install the WAL-G wrapper scripts ---
# These source /etc/wal-g.env before calling wal-g.
# See wal-g-setup.md for the full wrapper script content.
# Create /usr/local/bin/wal-g-archive.sh and /usr/local/bin/wal-g-restore.sh
# as documented in wal-g-setup.md, Part 2.4.
```

---

## Phase 3: Restore PostgreSQL from WAL-G

**Estimated time:** 1–3 hours depending on base backup size and network throughput

This is the most time-consuming phase. Run inside tmux.

```bash
# Start a tmux session so the restore survives any SSH interruption:
tmux new-session -s pg-restore

# --- P3.1: Stop the default PostgreSQL cluster ---
# The package installation created a fresh empty 18/main cluster.
# We are going to replace its data directory with the restored backup.
pg_ctlcluster 18 main stop

# Verify it stopped:
pg_lsclusters
# Status should be 'down'.

# --- P3.2: Remove the empty data directory ---
# WAL-G backup-fetch requires the target data directory to be empty or absent.
# Move rather than delete — keeps the pg_wal subdirectory structure
# intact in case you need to reference it.
mv /var/lib/postgresql/18/main /var/lib/postgresql/18/main.fresh_install_backup

# Create a fresh empty target:
mkdir -p /var/lib/postgresql/18/main
chown postgres:postgres /var/lib/postgresql/18/main
chmod 700 /var/lib/postgresql/18/main
# PostgreSQL requires mode 700 on PGDATA. Any other permission causes startup failure.

# --- P3.3: Restore the base backup ---
sudo -u postgres bash -c '
  set -a
  source /etc/wal-g.env
  set +a
  wal-g backup-fetch /var/lib/postgresql/18/main LATEST
' 2>&1 | tee /var/log/postgresql/wal-g-restore-$(date +%Y%m%d%H%M%S).log

# Monitor progress:
tail -f /var/log/postgresql/wal-g-restore-*.log
# A 200GB base backup at typical datacenter network speeds (100–500 MB/s between
# cloud providers) takes 15–60 minutes. At home internet speeds the WD Elements
# fallback is faster for the base backup.

# Verify the restore produced a valid data directory:
ls /var/lib/postgresql/18/main/
# Must contain: PG_VERSION, base/, global/, pg_wal/, pg_hba.conf
cat /var/lib/postgresql/18/main/PG_VERSION
# Must return: 18

# --- P3.4: Configure PITR recovery ---
# Decide your recovery target. Options:
# a) Latest available WAL (maximum data recovery): omit recovery_target_time
# b) Specific point in time (if recovering from logical corruption):
#    set recovery_target_time to just before the corruption event

# Add recovery configuration to postgresql.conf:
cat >> /etc/postgresql/18/main/postgresql.conf << 'EOF'

# --- RECOVERY CONFIGURATION ---
# Added during restore on $(date -u). Remove after cluster is promoted.
restore_command = '/usr/local/bin/wal-g-restore.sh %f %p'
recovery_target_action = 'promote'
# 'promote': automatically promote to writable primary when WAL replay is complete.
# Change to 'pause' if you want to inspect data before committing to the recovery point.
# --- END RECOVERY CONFIGURATION ---
EOF

# Create the recovery signal file to trigger recovery mode on startup:
sudo -u postgres touch /var/lib/postgresql/18/main/recovery.signal
# Presence of this file tells PostgreSQL 12+ to enter recovery mode.

# --- P3.5: Start PostgreSQL in recovery mode ---
pg_ctlcluster 18 main start

# Monitor the log — this is where you watch WAL replay progress:
tail -f /var/log/postgresql/postgresql-18-main.log

# During recovery you will see one log line per WAL segment fetched:
# LOG: restored log file "000000010000000000000001" from archive
# LOG: redo starts at 0/3000028
# ...
# LOG: database system is ready to accept connections
# (after auto-promotion, the last line indicates normal operation)

# --- P3.6: Verify the database ---
psql -U postgres -c "SELECT version();"
# Must show PostgreSQL 18.

psql -U postgres -c "SELECT pg_is_in_recovery();"
# Must return: f (false) — recovery is complete and cluster is promoted.

psql -U postgres -d cogdb -c "
  SELECT schemaname, tablename, n_live_tup
  FROM pg_stat_user_tables
  ORDER BY n_live_tup DESC
  LIMIT 20;"
# Row counts should be in the expected range. Compare against production
# pg_stat_user_tables output if you have a recent reference.

# --- P3.7: Update pg_hba.conf for application access ---
# The restored pg_hba.conf is a copy from production. It may reference
# specific IP addresses or network ranges that differ on the new VPS.
# Verify the local connection rules allow WildFly to connect:
cat /etc/postgresql/18/main/pg_hba.conf
# The application connects from localhost — this line must be present:
# local   all   all   md5
# or:
# host    all   all   127.0.0.1/32   md5
# If changes are needed, edit pg_hba.conf and reload:
pg_ctlcluster 18 main reload
```

---

## Phase 4: Install Java and WildFly

**Estimated time:** 15–30 minutes

```bash
# --- P4.1: Install Java ---
# WildFly requires Java 11+ (WildFly 26+) or Java 17+ (WildFly 27+).
# Match the Java version running on production.
apt install -y openjdk-17-jdk
java -version
# Confirm version matches production.

# --- P4.2: Create the WildFly system user ---
# WildFly should not run as root.
useradd -r -s /sbin/nologin wildfly
# -r: system account (no home directory, no aging)
# -s /sbin/nologin: cannot be used for interactive login

# --- P4.3: Install WildFly ---
# WildFly version must match production exactly — different major versions
# may have incompatible configuration file formats.
WILDFLY_VERSION="31.0.1.Final"
# Verify production version: on prod VPS, check /opt/wildfly/version.txt
# or the RELEASE-NOTES.md in the WildFly installation directory.

wget "https://github.com/wildfly/wildfly/releases/download/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.tar.gz" \
  -O /tmp/wildfly.tar.gz

tar -xzf /tmp/wildfly.tar.gz -C /opt/
ln -s /opt/wildfly-${WILDFLY_VERSION} /opt/wildfly
# Symlink allows version changes without reconfiguring all paths.

chown -R wildfly:wildfly /opt/wildfly-${WILDFLY_VERSION}

# --- P4.4: Restore WildFly configuration ---
# The standalone.xml (or domain.xml) contains datasource definitions,
# connection pools, and application-specific config.
# Source: git repository (preferred) or copy from production VPS if still accessible.

# If pulling from git:
# git clone your-repo-url /tmp/cnf-config
# cp /tmp/cnf-config/wildfly/standalone.xml /opt/wildfly/standalone/configuration/

# Key items to verify in standalone.xml after restoration:
# 1. PostgreSQL JDBC datasource connection URL — must point to localhost:5432
# 2. Database credentials — must match the cogdb user on this restored cluster
# 3. Any environment-specific paths or hostnames

# --- P4.5: Deploy the application artifact ---
# The .war or .ear file must be placed in WildFly's autodeploy directory.
# Source options in order of preference:
# a) Pull from the git repository (if build artifacts are committed or buildable)
# b) Copy from the production VPS (scp if it is still accessible)
# c) Pull from a Nexus/Artifactory artifact server (if one exists)
cp your-application.war /opt/wildfly/standalone/deployments/
chown wildfly:wildfly /opt/wildfly/standalone/deployments/your-application.war

# --- P4.6: Create WildFly systemd service ---
cat > /etc/systemd/system/wildfly.service << 'EOF'
[Unit]
Description=WildFly Application Server
After=network.target postgresql@18-main.service
Requires=postgresql@18-main.service

[Service]
User=wildfly
Group=wildfly
ExecStart=/opt/wildfly/bin/standalone.sh -c standalone.xml
ExecStop=/opt/wildfly/bin/jboss-cli.sh --connect command=:shutdown
TimeoutStartSec=120
TimeoutStopSec=60
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wildfly
systemctl start wildfly
systemctl status wildfly
# Monitor for startup errors. WildFly logs to:
tail -f /opt/wildfly/standalone/log/server.log
```

---

## Phase 5: Install and configure Redis

**Estimated time:** 5 minutes

```bash
# --- P5.1: Install Redis ---
apt install -y redis-server

# --- P5.2: Restore Redis configuration ---
# Redis's default configuration is typically fine for CodeNforce's use case.
# Verify the production Redis instance has any non-default settings:
# On production: grep -v "^#" /etc/redis/redis.conf | grep -v "^$"
# Common customizations: maxmemory, maxmemory-policy, bind address.

# The critical setting for a single-VPS deployment:
# Redis must bind to localhost only (default). Confirm:
grep "^bind" /etc/redis/redis.conf
# Should show: bind 127.0.0.1 ::1
# If it shows 0.0.0.0, Redis is listening on all interfaces — a security problem.

systemctl enable redis-server
systemctl start redis-server
systemctl status redis-server

# Quick connectivity test:
redis-cli ping
# Should return: PONG
```

---

## Phase 6: Install and configure nginx

**Estimated time:** 10–15 minutes

```bash
# --- P6.1: Install nginx ---
apt install -y nginx

# --- P6.2: Restore nginx configuration ---
# Source: git repository (strongly preferred).
# If nginx config is not in git, this is a gap to close after the incident.

# Remove the default site:
rm /etc/nginx/sites-enabled/default

# Copy your nginx config from git or from a backup:
# cp /path/to/your/nginx-config /etc/nginx/sites-available/codenforce
# ln -s /etc/nginx/sites-available/codenforce /etc/nginx/sites-enabled/

# The key elements your nginx config for CodeNforce should include:
# - server_name pointing to your domain
# - proxy_pass to WildFly's listening port (typically 8080)
# - TLS configuration (see P6.3)

# Validate the configuration before starting:
nginx -t
# Output: nginx: configuration file /etc/nginx/nginx.conf test is successful

# --- P6.3: TLS certificate ---
# If using Let's Encrypt via Certbot on production:
apt install -y certbot python3-certbot-nginx

# Obtain a certificate for your domain:
# (DNS must already point to this VPS's IP for this to work — see Phase 8)
certbot --nginx -d yourdomain.com
# Certbot modifies the nginx config to add TLS directives automatically.
# Follow the prompts.

# If you cannot update DNS yet (DR test mode), obtain a standalone certificate
# or skip TLS for the duration of the test.

systemctl enable nginx
systemctl start nginx
systemctl status nginx
```

---

## Phase 7: Install Docker and restore containers

**Estimated time:** 10–20 minutes

```bash
# --- P7.1: Install Docker ---
# Install from Docker's official repository, not Ubuntu's default packages.
# Ubuntu's docker.io package is often several major versions behind.

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add echocdelta to the docker group (allows running docker without sudo):
usermod -aG docker echocdelta
# Group membership takes effect on next login.

# Verify Docker is running:
systemctl status docker
docker run --rm hello-world
# Should print: Hello from Docker!

# --- P7.2: Restore container definitions ---
# Source: git repository. The docker-compose.yml or individual Dockerfile
# definitions must be in version control.
# If they are not, document which containers are running on production:
# On production VPS: docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
# and docker inspect <container_name> for configuration details.

# Pull and start containers from compose file:
# cd /path/to/compose/directory
# docker compose up -d

# Verify all expected containers are running:
docker ps
```

---

## Phase 8: DNS cutover

**Estimated time:** 5 minutes to update, up to TTL for propagation

This phase completes the cutover to the new VPS. In DR test mode, you may skip this and test via IP address or `/etc/hosts` manipulation on a test client instead.

```bash
# --- P8.1: Confirm all services are healthy before touching DNS ---
systemctl status postgresql@18-main
systemctl status wildfly
systemctl status redis-server
systemctl status nginx
docker ps
# All services must show active (running) before updating DNS.
# A DNS cutover to a broken VPS causes user-facing downtime.

# --- P8.2: Lower DNS TTL in advance (ideally done pre-incident) ---
# If TTL is currently 3600 (1 hour), DNS changes take up to 1 hour to propagate.
# In a production incident, this delay is part of your RTO.
# Best practice: lower TTL to 300 (5 minutes) before any planned maintenance
# or as standing practice for records likely to change during an incident.

# --- P8.3: Update the A record ---
# At your DNS provider's control panel, update the A record for yourdomain.com
# (and any subdomains) to point to the new VPS's public IPv4 address.
# If using DigitalOcean DNS and the DO account is compromised, you need an
# alternative DNS provider with credentials stored outside DO.
# This is a gap to identify and close before an incident.
```

---

## Phase 9: Smoke test

**Estimated time:** 10–15 minutes

```bash
# --- P9.1: Database connectivity from application ---
# Check WildFly logs for successful datasource pool initialization:
grep -i "datasource\|connection\|pool" /opt/wildfly/standalone/log/server.log | tail -20
# Should show successful connection pool establishment, not JDBC errors.

# --- P9.2: Application HTTP response ---
# From the new VPS itself (bypasses DNS):
curl -v http://localhost/
# Should return an HTTP response from nginx, which proxies to WildFly.
# Expected: 200 OK or a redirect to the application's login page.

# From a client machine, after DNS propagates:
curl -v https://yourdomain.com/
# 200 OK with TLS confirms end-to-end stack is working.

# --- P9.3: Application functionality test ---
# Log into CodeNforce via the UI.
# Load a known case record and verify data matches expectations.
# Submit a test workflow action (if a safe test case exists).
# Confirm the action persists after a page reload (verifies write path to PostgreSQL).

# --- P9.4: Record the RTO achieved ---
date -u
# Time from "production down detected" to "smoke test passed" is your measured RTO.
# Compare against the ≤4 hour target. Document the gap if any.
```

---

## Phase 10: Re-establish WAL archiving on the new VPS

This step is critical if the new VPS becomes the ongoing production instance (actual catastrophic recovery, not a DR test).

```bash
# Configure postgresql.conf for WAL archiving:
cat >> /etc/postgresql/18/main/postgresql.conf << 'EOF'

# WAL archiving to Backblaze B2 via WAL-G
wal_level = replica
archive_mode = on
archive_command = '/usr/local/bin/wal-g-archive.sh %p'
archive_timeout = 60
EOF

# Create the wrapper scripts (see wal-g-setup.md Part 2.4).
# Create log directory:
mkdir -p /var/log/wal-g
chown postgres:postgres /var/log/wal-g

# Restart to apply wal_level and archive_mode (restart-required parameters):
pg_ctlcluster 18 main restart

# Immediately push a new base backup to establish a fresh archive chain:
sudo -u postgres bash -c '
  set -a; source /etc/wal-g.env; set +a
  wal-g backup-push /var/lib/postgresql/18/main
'

# Verify archiving is running:
psql -U postgres -c "SELECT archived_count, last_archived_time, failed_count FROM pg_stat_archiver;"
```

---

## DR test teardown

After completing the smoke test in DR test mode, the new VPS has served its purpose. Document findings before destroying it.

```bash
# --- Before destroying the instance ---
# Document:
# 1. Total wall-clock time for each phase (fill in the table below)
# 2. Any steps that required improvisation or clarification
# 3. Any configuration values that were missing or wrong
# 4. The measured RTO vs. the ≤4 hour target
# 5. Services that started correctly on first attempt vs. required debugging

# Destroy the instance at the provider's control panel.
# Confirm the instance is fully deleted (check billing to verify no orphaned resources).
```

---

## Phase timing log (fill in during execution)

Use this table to track actual elapsed time during the procedure. This data feeds RTO documentation and runbook improvement.

| Phase | Description | Start time (UTC) | End time (UTC) | Elapsed | Notes |
|---|---|---|---|---|---|
| 0 | VPS provisioning | | | | |
| 1 | OS baseline | | | | |
| 2 | PostgreSQL + WAL-G install | | | | |
| 3 | Database restore | | | | |
| 4 | WildFly install + deploy | | | | |
| 5 | Redis | | | | |
| 6 | nginx + TLS | | | | |
| 7 | Docker containers | | | | |
| 8 | DNS cutover | | | | |
| 9 | Smoke test pass | | | | |
| **Total** | | | | | vs. ≤4hr target |

---

## Known gaps to resolve before this runbook is needed for real

These items will cause delay or improvisation during an actual incident if not addressed in advance:

- [ ] **WildFly deployment artifact location** — where is the current production `.war`/`.ear`? If only on the VPS, it is lost with the VPS. Must be in git or an artifact server.
- [ ] **nginx configuration in git** — if not committed, it must be reconstructed from memory during an incident.
- [ ] **Docker compose files in git** — list of running containers and their configuration must be version-controlled.
- [ ] **WildFly standalone.xml in git** — datasource definitions, JVM tuning, security realms.
- [ ] **DNS access outside DO** — if DigitalOcean manages DNS and the DO account is compromised, DNS updates are blocked. Use an independent DNS provider (Cloudflare, Namecheap DNS) with credentials stored outside DO.
- [ ] **Redis non-default configuration documented** — if production Redis has any tuned parameters, they must be captured somewhere other than the production filesystem.
- [ ] **Database user passwords** — the cogdb application user password must be stored in the credential manager. pg_restore recreates the user but not the password; WildFly datasource needs the correct password to connect.
- [ ] **Low DNS TTL** — if TTL is 3600, DNS propagation adds up to 1 hour to RTO. Lower to 300 as standing practice.

---

## Runbook revision log

| Date | Change | Author |
|---|---|---|
| 2026-09-07 | Initial version | Echo Darsow |

**Revision trigger conditions:** After every DR test execution, update this document with:
- Actual phase timings vs. estimates
- Steps that required deviation from the written procedure
- Configuration gaps discovered during the test
- Updated RTO measurement
