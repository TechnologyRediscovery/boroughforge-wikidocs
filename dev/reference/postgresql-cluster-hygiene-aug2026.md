# PostgreSQL Cluster Hygiene — CNF Production VPS

**Scope:** Consolidating multiple concurrently running PostgreSQL major-version clusters down to a single production cluster hosting `cogdb`, understanding the Debian/Ubuntu packaging architecture that produced the sprawl, and establishing verification habits so this doc stays true after future upgrades.

**Host:** `cnfcitf` (DigitalOcean VPS). Observed state as of 2026-08-04: postmasters running for versions **13, 14, 16, 17**. No version 18 postmaster observed despite a working belief that cogdb is on 18.4 — resolve this discrepancy in §3 before touching anything.

---

## 1. Architecture: how the pieces fit

### 1.1 The cluster model

Debian/Ubuntu wraps upstream PostgreSQL in the `postgresql-common` framework, which supports **multiple major versions installed side by side**, each hosting one or more **clusters**. A cluster is:

- one data directory: `/var/lib/postgresql/<version>/<name>/` (name is almost always `main`)
- one config directory: `/etc/postgresql/<version>/<name>/` (`postgresql.conf`, `pg_hba.conf`, `start.conf`)
- one postmaster process listening on one port

Ports are assigned at cluster creation time: first cluster gets **5432**, the next gets 5433, and so on. The port is recorded in each cluster's `postgresql.conf` and never reassigned automatically.

**How sprawl happens:** when apt installs a new major version — because the `postgresql` metapackage tracks a new release, or the PGDG repository was added — the postinst script creates a *fresh, empty* cluster for that version on the next free port. It does **not** migrate data and does **not** stop old clusters. Four upgrades over the VPS lifetime → four postmasters, three of them (probably) empty.

### 1.2 Server packages vs. client packages

| Package | Contents |
|---|---|
| `postgresql-<N>` | Server engine: `postgres` binary, backend libraries |
| `postgresql-client-<N>` | `psql`, `pg_dump`, `pg_restore`, `createdb`, etc. |
| `postgresql-common` | Cluster tooling: `pg_lsclusters`, `pg_ctlcluster`, `pg_createcluster`, `pg_dropcluster`, `pg_upgradecluster`, the wrapper machinery |
| `postgresql-client-common` | `pg_wrapper` and `/usr/bin/psql` symlink |

`/usr/bin/psql` is a symlink to `pg_wrapper`, a Perl script that selects a *versioned* client binary (e.g. `/usr/lib/postgresql/17/bin/psql`) at invocation time. Selection order:

1. `--cluster <version>/<name>` flag
2. `PGCLUSTER` environment variable
3. `/etc/postgresql-common/user_clusters` (per-user defaults)
4. Fallback: newest installed client, targeting port 5432

**Compatibility rule:** a newer client against an older server is fully supported. The reverse — notably an *older* `pg_dump` run against a *newer* server — is not. Always dump with the `pg_dump` matching or exceeding the server's major version.

### 1.3 systemd integration

- `postgresql.service` is an **umbrella unit** — it runs nothing itself.
- Real work happens in templated units: `postgresql@13-main.service`, `postgresql@17-main.service`, etc.
- A **systemd generator** (`/lib/systemd/system-generators/postgresql-generator`) runs at boot and daemon-reload, reads each cluster's `start.conf`, and wires clusters with `auto` into the umbrella's dependency graph.

Therefore the authoritative autostart control is the file:

```
/etc/postgresql/<version>/main/start.conf
```

with exactly one of three values:

| Value | Meaning |
|---|---|
| `auto` | Started at boot via the umbrella |
| `manual` | Not auto-started; `pg_ctlcluster` can still start it |
| `disabled` | `pg_ctlcluster` refuses to start it at all |

`systemctl disable postgresql@13-main` alone is insufficient — the generator can re-wire it. Change `start.conf`, then `systemctl daemon-reload`.

---

## 2. Inventory commands

```bash
# Master inventory: version, cluster name, port, status, owner, data dir, log file
pg_lsclusters

# What is actually listening, and on which ports
ss -tlnp | grep postgres

# Disk footprint of each data directory (an empty default cluster is ~40 MB;
# a real database is conspicuously larger)
sudo du -sh /var/lib/postgresql/*/main

# systemd view
systemctl list-units 'postgresql*'
```

`pg_lsclusters` is the single most useful command in this entire domain. Its port column tells you which postmaster to interrogate.

---

## 3. Identify the production cluster (do this before anything else)

Do not trust memory or belief about the version. Three independent evidence sources, in order of authority:

### 3.1 What the application actually connects to (ground truth)

```bash
grep -n 'connection-url' /opt/wildfly/standalone/configuration/standalone.xml
```

The JDBC URL names a host and port. Whatever cluster owns that port **is production**. This overrides every other source of evidence.

### 3.2 Interrogate each cluster directly

For each port reported by `pg_lsclusters`:

```bash
sudo -u postgres psql -p 5432 -c "SHOW server_version;" -c "\l+"
sudo -u postgres psql -p 5433 -c "SHOW server_version;" -c "\l+"
# ... etc.
```

- `SHOW server_version` gives the *server's* true version — unlike `psql --version`, which reports only the client binary and is a classic source of the "I thought I was on 18" belief.
- `\l+` lists databases with sizes. The cluster containing `cogdb` at a plausible size is the candidate.

### 3.3 Check for live traffic on the non-candidates

```bash
sudo -u postgres psql -p <port> -c \
  "SELECT datname, usename, client_addr, state, backend_start
   FROM pg_stat_activity WHERE backend_type = 'client backend';"
```

An empty result (aside from your own session) on a cluster, ideally sampled a few times across days, supports the conclusion that it serves nothing.

### 3.4 The stale-copy trap

If `pg_upgradecluster` was ever run in the past, an "old" cluster may contain a **stale copy of cogdb** under the same name. Do not identify production by database name alone. Discriminate with recency evidence:

```bash
sudo -u postgres psql -p <port> -d cogdb -c \
  "SELECT max(createdts) FROM public.cear;"   -- or any high-churn table
```

The cluster whose data reflects yesterday's activity is production; one frozen at some past date is an upgrade artifact.

**Record the finding here once confirmed:**

> Production cluster: version ____, port ____, data dir ____ (confirmed YYYY-MM-DD via WildFly datasource + pg_stat_activity + recency check)

---

## 4. Safely shut down the non-production clusters

Sequence matters. Stopping is reversible; dropping is not.

### 4.1 Take a backup of production first

Even though the operation shouldn't touch the prod cluster, the cost of a dump is trivial:

```bash
# Use the newest installed pg_dump; -Fc = custom format (compressed, pg_restore-able)
sudo -u postgres pg_dump -p <prod_port> -Fc cogdb > /var/backups/cogdb-$(date +%F).dump
```

### 4.2 Stop each non-production cluster

```bash
sudo pg_ctlcluster 13 main stop
sudo pg_ctlcluster 14 main stop
# ... whichever are non-production
```

`pg_ctlcluster <ver> <name> stop` is the packaging-aware equivalent of `pg_ctl stop`; it knows the Debian directory layout. This is fully reversible with `start`.

### 4.3 Prevent autostart

```bash
sudo sed -i 's/^auto$/manual/' /etc/postgresql/13/main/start.conf
sudo sed -i 's/^auto$/manual/' /etc/postgresql/14/main/start.conf
# ...
sudo systemctl daemon-reload
```

Use `manual` during the quarantine period (§4.4) rather than `disabled` — it keeps the escape hatch of a one-command restart if something unexpected depended on a cluster.

### 4.4 Quarantine period

Run with the extra clusters stopped-but-intact for **at least one full business cycle** (a week that includes municipal reporting activity is a reasonable bar). If nothing breaks — WildFly connects, CEARs flow, no service falls over at boot — the hypothesis "these clusters were unused" has survived a real falsification attempt rather than mere inspection.

### 4.5 Verify the survivor after a reboot

```bash
sudo reboot
# after boot:
pg_lsclusters                    # exactly one cluster 'online'
ss -tlnp | grep postgres         # exactly one listener, on the prod port
sudo -u postgres psql -p <prod_port> -d cogdb -c "SELECT now();"
# and confirm the application itself: hit a CNF page that requires a DB round-trip
```

---

## 5. Permanent removal (after quarantine passes)

### 5.1 Optional belt-and-suspenders: archive the doomed data dirs

```bash
sudo tar -C /var/lib/postgresql -czf /var/backups/pg13-main-$(date +%F).tar.gz 13/main
```

Cheap insurance; delete the tarball in a month.

### 5.2 Drop the clusters

```bash
sudo pg_dropcluster 13 main --stop
sudo pg_dropcluster 14 main --stop
# ...
```

**`pg_dropcluster` destroys the data directory and config directory.** This is the irreversible step. It removes only the named cluster, not the packages.

### 5.3 Purge the packages

```bash
sudo apt purge postgresql-13 postgresql-client-13 \
               postgresql-14 postgresql-client-14   # etc.
sudo apt autoremove --purge
```

Keep `postgresql-common` and `postgresql-client-common` — the surviving cluster depends on them. After purging, re-run `pg_lsclusters` and `dpkg -l | grep postgresql` to confirm exactly one major version remains.

### 5.4 Verify client wrapper behavior

```bash
psql --version          # should report the surviving major version
psql -U postgres -l     # wrapper defaults to port 5432; if prod is NOT on 5432,
                        # either note that every psql invocation needs -p <port>,
                        # or set a default in /etc/postgresql-common/user_clusters
```

If production ended up on a non-default port (e.g. 5435 because it was the fourth cluster created), consider whether to leave it — the WildFly datasource doesn't care — or normalize to 5432 by editing `port` in `postgresql.conf` **and** the WildFly `connection-url` in the same maintenance window. Normalizing removes a permanent source of "wait, which port" friction; leaving it avoids a coordinated two-config change. Either is defensible; pick one and record it.

---

## 6. If a major-version upgrade is actually wanted

Separate operation from cleanup; do not conflate them. If, after §3, production turns out to be on an old version (e.g. 13) and moving to 17/18 is desired:

```bash
sudo pg_upgradecluster -v 17 13 main
```

- Creates a new v17 cluster, migrates data, moves the **old** cluster to port 5433+ and marks it `manual`, and puts the **new** cluster on the old cluster's port — so the application config usually needs no change.
- The old cluster is left intact as a rollback path. This is exactly the mechanism that produces stale-copy clusters (§3.4) — after validating the upgrade, come back through §4–§5 for the old cluster.
- Dump first regardless. `pg_upgradecluster` is reliable, but PostGIS adds an extension-version dimension: confirm the target server's `postgresql-<N>-postgis-3` package is installed *before* upgrading, and run `SELECT postgis_full_version();` afterward.

---

## 7. Standing hygiene rules

1. **After any apt operation that touches postgresql packages**, run `pg_lsclusters`. A new empty cluster appearing on a new port is the expected failure mode; catch it same-day.
2. **Never identify a cluster by database name alone** — stale upgrade copies share names. Use port + recency evidence.
3. **`psql --version` describes the client, not the server.** `SHOW server_version;` is the only trustworthy version claim.
4. **`start.conf` is the autostart switch**, not `systemctl enable/disable`.
5. **Dump with the newest `pg_dump` available**, never an older one against a newer server.
6. One cluster, one port, one line in `pg_lsclusters` — anything more requires a written reason in this doc.

---

## Appendix: command quick reference

| Task | Command |
|---|---|
| Inventory all clusters | `pg_lsclusters` |
| Start / stop / restart a cluster | `sudo pg_ctlcluster <ver> main start\|stop\|restart` |
| Server's true version | `psql -p <port> -c "SHOW server_version;"` |
| List DBs with sizes | `psql -p <port> -c "\l+"` |
| Live client sessions | query `pg_stat_activity` |
| Autostart control | edit `/etc/postgresql/<ver>/main/start.conf`, then `systemctl daemon-reload` |
| Destroy a cluster (irreversible) | `sudo pg_dropcluster <ver> main --stop` |
| Migrate data to a new major version | `sudo pg_upgradecluster -v <new> <old> main` |
| Which listener owns which port | `ss -tlnp \| grep postgres` |
| Data dir sizes | `sudo du -sh /var/lib/postgresql/*/main` |
