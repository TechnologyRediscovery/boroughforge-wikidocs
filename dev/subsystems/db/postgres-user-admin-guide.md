---
title: PostgreSQL User and Role Administration — CodeNforce Production
description: The PostgreSQL permission model explained from first principles, a recipe for a read-only backup role covering every schema in cogdb, a safe procedure for removing departed users without risking data loss, and a target role design for separating application writes from object ownership.
published: true
date: 2026-09-13
tags: [postgresql, security, roles, permissions, dba, wildfly, infrastructure]
editor: markdown
dateCreated: 2026-09-13
---

# PostgreSQL User and Role Administration — CodeNforce Production

## Purpose and scope

This document exists because the production database is currently operated with a single
role, `sylvia`, that both **owns every object** and is used by **every WildFly connection
pool** and every ad hoc script. That is a single point of catastrophic failure for a decade of
municipal enforcement records, and the immediate trigger for writing it down was a reasonable
instinct: running generated backup scripts against production as the object owner is playing
with fire.

Four sections:

1. The permission model — roles, users, ownership, and the parts that surprise people
2. Creating a read-only role for backups and reporting
3. Removing departed users without destroying anything
4. A target role design for production, and how to implement it in WildFly

**Companion documents:**
- [Backup strategy](/dev/subsystems/db/cnf-backup-strategy) — the scripts this read-only role is for
- `postgresql-cluster-hygiene.md` — cluster inventory and version management

---

## What is verified here, and what you must check live

Everything about the *current* state below was read from a real production schema dump
(`codeconnect/database/schemas/prodschemas/cogdb_prod_schemaonly_9AUG2026_plain.sql` in the
`codenforce` repo, 2026-08-09) and from the committed WildFly configuration
(`codeconnect/server/standalone-full.xml`). Confirmed from those sources:

| Fact | Evidence |
|---|---|
| `sylvia` owns essentially every object | 455 `TO sylvia` grants; `ALTER TABLE … OWNER TO sylvia` throughout |
| Three additional grantee roles exist: `saylords`, `jsettel`, `projectjay` | 372 / 192 / 163 grants respectively |
| `saylords` has `USAGE` on `logging`, `public`, `settingsconfig`, `westmc` | `GRANT USAGE ON SCHEMA …` lines |
| `jsettel` has `USAGE` on `public` only | same |
| `projectjay` has **no schema-level `USAGE` grant at all** | absence in the dump — it reaches `public` only via the `PUBLIC` grant below |
| `GRANT ALL ON SCHEMA public TO PUBLIC` is in effect | explicit in the dump; this is the PostgreSQL ≤14 default |
| The app connects through one datasource, `java:jboss/postgresDS` → `cogdb` | `standalone-full.xml`, `dbconnection.properties` (`jndi_name=postgresDS`) |

**Not verified, and you must check before acting:** whether `sylvia` actually holds the
`SUPERUSER` attribute. Role attributes live in the cluster-wide catalog and are **not** part
of a per-database `pg_dump`, so no dump can answer this. Run:

```sql
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolbypassrls
FROM pg_roles
WHERE rolname NOT LIKE 'pg\_%'
ORDER BY rolname;
```

The distinction matters for everything below: a *superuser* bypasses all permission checks,
while a mere *owner* has full rights over its own objects only. For CodeNforce the practical
difference is small — `sylvia` owns everything that matters — but the fix is different in each
case, so find out which you are dealing with.

---

## 1. The PostgreSQL permission model

### Roles and users are the same thing

PostgreSQL has exactly one concept: the **role**. `CREATE USER` is a legacy alias for
`CREATE ROLE … LOGIN`, and nothing else distinguishes them. There is no separate "user" object
in the catalog — `pg_user` is a view over `pg_roles` filtered to those with `rolcanlogin`.

```sql
CREATE ROLE reporting;                 -- cannot log in; a container for privileges
CREATE ROLE alice LOGIN PASSWORD '…';  -- can log in; identical in every other respect
```

The useful convention that falls out of this: use **group roles** (`NOLOGIN`) to hold sets of
privileges, and **login roles** to identify humans and services. Grant the group to the login
role. When a person leaves, you drop one login role and the privilege set survives untouched
for their successor. Grant privileges directly to individual humans and you get exactly the
situation this database is in now — three interns' names scattered across 727 grant statements
with no way to reason about them as a set.

### Roles are cluster-wide; privileges are per-database

A role exists once for the whole PostgreSQL **cluster** (the server), but the privileges it
holds are recorded **inside each database** it has access to. This asymmetry is the single
biggest source of surprise during cleanup, and section 3 depends on it: `DROP ROLE` is a
cluster-level operation that will refuse to run while *any* database still records a privilege
or ownership for that role. You cannot see those dependencies from inside one database alone.

### Ownership is not a privilege

Every object has an **owner**. Ownership is not in the grant system and cannot be granted away
piecemeal — it is reassigned wholesale. The owner implicitly holds every privilege on the
object *and* the rights that are not grantable at all:

- `DROP` the object
- `ALTER` it — add/drop columns, rename, change constraints
- `TRUNCATE` it
- `GRANT` privileges on it to others

**This is the crux of the current risk.** Because WildFly connects as `sylvia`, and `sylvia`
owns every table, an SQL injection flaw or a mistaken statement in application code is not
limited to reading or corrupting rows — it can `DROP TABLE cecase`. Revoking privileges from
an owner does not help; owners can re-grant to themselves. **The only fix is to stop connecting
as the owner.** That single change, independent of everything else in section 4, removes all
DDL from the application's reach.

### The two-key rule: schema USAGE plus object privilege

Reaching a table requires **both**:

1. `USAGE` on the schema that contains it, and
2. the relevant privilege (`SELECT`, `INSERT`, …) on the table itself

Miss either and access fails, often confusingly — a `SELECT` grant on a table in a schema you
lack `USAGE` on produces "permission denied for schema", which reads like the table is missing
rather than the grant being half-finished. Conversely `USAGE` alone gets you nothing.

`projectjay` in the table above is a live example: it has 163 table grants and no schema
`USAGE` grant of its own. It works only because of the next item.

### PUBLIC is a pseudo-role meaning "everyone"

`PUBLIC` is not a group you can drop; it is an implicit grantee that every role inherits.
Production currently has:

```sql
GRANT ALL ON SCHEMA public TO PUBLIC;
```

`ALL` on a schema is `USAGE` + **`CREATE`**. So every role in the cluster — including any
read-only role you create today — can create tables in the `public` schema. This was the
PostgreSQL default through version 14 and was **removed as a default in PostgreSQL 15**
precisely because it surprised people. Section 2 covers tightening it, and the PG14→18 upgrade
is the natural moment to deal with it.

`PUBLIC` also holds `CONNECT` on every database and `EXECUTE` on every function by default.

### Default privileges apply only to future objects, per creating role

`GRANT SELECT ON ALL TABLES IN SCHEMA public TO x` is a one-time operation over the tables
that exist **at that instant**. Tables created tomorrow are not covered. For those you need:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE sylvia IN SCHEMA public
    GRANT SELECT ON TABLES TO reporting;
```

The `FOR ROLE` clause is the trap. Default privileges are keyed to **the role that creates the
object**, not to the schema in the abstract. Production contains a working demonstration of
getting this wrong:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO jsettel;
```

That rule fires only for tables created by `postgres`. CodeNforce tables are created by
`sylvia`, so `jsettel` has silently missed every table added since that line was written. The
grant looks present and correct in the catalog and does nothing. If you write default
privileges, write them `FOR ROLE sylvia` — or avoid the whole mechanism, as section 2 does.

### Inheritance

By default a role created with `INHERIT` (the default) automatically uses the privileges of
roles it is a member of. With `NOINHERIT`, the member must explicitly `SET ROLE` to use them.
Inheritance is the convenient default and is what makes the group-role pattern work without
any application awareness.

### Reading the current state

```sql
-- Roles and their attributes, plus group memberships
\du

-- Schemas, owners, and access privileges
\dn+

-- Privileges on tables in a schema
\dp public.*

-- Same thing as a query, filtered to one grantee
SELECT table_schema, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'jsettel'
ORDER BY table_schema, table_name;

-- Default privilege rules (the mechanism described above)
SELECT pg_get_userbyid(defaclrole) AS creating_role,
       n.nspname AS schema, defaclobjtype, defaclacl
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace;
```

---

## 2. Creating a read-only role for backups

Goal: a login role that can `SELECT` from every object in every schema of `cogdb`, that
automatically covers objects added in future, and that cannot write anything under any
circumstance. This is what the backup scripts should authenticate as instead of `sylvia`.

### Option A (recommended): the `pg_read_all_data` predefined role

PostgreSQL 14 introduced the predefined role **`pg_read_all_data`**, and production runs
14.24, so this is available today. Membership grants `SELECT` on all tables, views, materialized
views, and sequences, plus `USAGE` on all schemas — **dynamically**. Objects created next year
are covered with no maintenance, which sidesteps the entire default-privileges trap above.

```sql
-- 1. The login role the backup client authenticates as.
--    Use a long random password; store it in ~/.pgpass, never in a script.
CREATE ROLE cnf_backup LOGIN PASSWORD 'REPLACE_WITH_GENERATED_SECRET';

-- 2. Read everything, forever, with no per-schema bookkeeping.
GRANT pg_read_all_data TO cnf_backup;

-- 3. Belt and braces: every session this role opens is read-only at the
--    transaction level, so even a bug that hands it a write statement fails.
ALTER ROLE cnf_backup SET default_transaction_read_only = on;

-- 4. A dump holds one long transaction; don't let a global idle-timeout kill it.
ALTER ROLE cnf_backup SET idle_in_transaction_session_timeout = 0;
ALTER ROLE cnf_backup SET statement_timeout = 0;
```

`CONNECT` on `cogdb` is already held via `PUBLIC`, so no explicit grant is needed — but if you
ever revoke `CONNECT` from `PUBLIC` (a good idea eventually), remember to grant it here.

Step 3 is worth dwelling on. `default_transaction_read_only` makes the *server* refuse writes
from this role regardless of what privileges it may accidentally accumulate later. It is a
second, independent control from a different mechanism than the grant system — exactly the
property you want from a safety net, since it does not fail in the same way the first one does.

### Option B: explicit grants

Use this if you want the backup role to see only some schemas, or if you need to reproduce the
setup on a pre-14 cluster. It loops over every non-system schema:

```sql
CREATE ROLE cnf_readonly NOLOGIN;
CREATE ROLE cnf_backup LOGIN PASSWORD 'REPLACE_WITH_GENERATED_SECRET' IN ROLE cnf_readonly;

GRANT CONNECT ON DATABASE cogdb TO cnf_readonly;

DO $$
DECLARE s text;
BEGIN
  FOR s IN
    SELECT nspname FROM pg_namespace
    WHERE nspname NOT IN ('pg_catalog', 'information_schema')
      AND nspname NOT LIKE 'pg\_toast%'
      AND nspname NOT LIKE 'pg\_temp%'
  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO cnf_readonly', s);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO cnf_readonly', s);
    EXECUTE format('GRANT SELECT ON ALL SEQUENCES IN SCHEMA %I TO cnf_readonly', s);
    -- FOR ROLE sylvia, not the default: CodeNforce objects are created by sylvia.
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE sylvia IN SCHEMA %I GRANT SELECT ON TABLES TO cnf_readonly', s);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE sylvia IN SCHEMA %I GRANT SELECT ON SEQUENCES TO cnf_readonly', s);
  END LOOP;
END $$;

ALTER ROLE cnf_backup SET default_transaction_read_only = on;
```

Two notes on running this: the `GRANT … ON ALL TABLES` statements must be executed by the
tables' owner or a superuser, and `ALTER DEFAULT PRIVILEGES FOR ROLE sylvia` requires you to
*be* `sylvia` or a member of it. Run the whole block as `sylvia`.

This covers all ten schemas currently in `cogdb` — `public`, `westmc`, `workflow`,
`settingsconfig`, `external_wprdc`, `logging`, `mapping`, `finance`, `worldfacing`,
`external_munispecific` — including the three that are presently empty, so newly populated
schemas are handled without a follow-up.

### The `PUBLIC` CREATE loophole

Neither option above prevents the new role from creating objects in `public`, because
`GRANT ALL ON SCHEMA public TO PUBLIC` grants `CREATE` to everyone. To close it:

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

**Weigh the blast radius before running this on production.** It applies to every role, not
just the new one, so any code path that creates a permanent object in `public` at runtime will
start failing. Temporary tables are unaffected — those live in per-session `pg_temp` schemas —
and DB patches run as `sylvia`, who retains `CREATE` as schema owner. The realistic risk is
some forgotten utility or reporting script. Grep the codebase for runtime `CREATE TABLE` before
deciding, and treat it as a candidate to bundle with the PostgreSQL 14→18 upgrade, where it is
the default behaviour anyway.

### Authentication plumbing

The backup scripts connect over an SSH tunnel, so from the server's perspective the connection
arrives on its own loopback. That needs a `pg_hba.conf` entry — placed **above** any broader
rule, since PostgreSQL uses the first matching line and stops:

```
# TYPE  DATABASE  USER        ADDRESS       METHOD
host    cogdb     cnf_backup  127.0.0.1/32  scram-sha-256
```

Reload with `SELECT pg_reload_conf();` — `pg_hba.conf` does not need a restart.

Store the password in `~/.pgpass` on the workstation, never in the script:

```
localhost:32000:cogdb:cnf_backup:the_generated_password
```

`chmod 600 ~/.pgpass` or libpq silently ignores it. Note the host field must match the string
the script actually passes to `psql` — the backup scripts deliberately use `localhost` rather
than `127.0.0.1` for exactly this reason.

### Verify it — both directions

A read-only role is only proven by a **failed write**, not by a successful read.

```bash
# Positive: can it read the biggest and the newest things?
psql -h localhost -p 32000 -U cnf_backup -d cogdb -c "SELECT count(*) FROM public.blobbytes;"
psql -h localhost -p 32000 -U cnf_backup -d cogdb -c "SELECT count(*) FROM workflow.workflowstepdef;"

# Negative: these MUST fail.
psql -h localhost -p 32000 -U cnf_backup -d cogdb -c "CREATE TABLE public.should_not_exist (x int);"
psql -h localhost -p 32000 -U cnf_backup -d cogdb -c "UPDATE public.municipality SET muniname = muniname;"
psql -h localhost -p 32000 -U cnf_backup -d cogdb -c "DROP TABLE public.blobbytes;"
```

Then confirm nothing is invisible to it — a dump that silently omits a table is worse than one
that fails. Compare the table count the new role can see against the owner's view:

```sql
SELECT count(*) FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');
```

Run it as `cnf_backup` and as `sylvia`; the numbers must match. Finally run a real
`cnfprodbak.sh structural` as the new role and diff the output against the last dump taken as
`sylvia` before trusting it.

### Then change the scripts

In the backup scripts, `DB_USER="sylvia"` becomes `DB_USER="cnf_backup"`. Nothing else changes
— every script in `codeconnect/database/scripts/` except `restore-blob-increments.sh` is
read-only by design, and that one writes only to a local scratch database and has its own guard
against pointing at production.

One consequence to accept deliberately: dumps taken as `cnf_backup` still record `sylvia` as
the object owner in the archive TOC, because ownership is a property of the object, not of the
dumping role. The existing local-`sylvia`-role trick in the verification scripts continues to
work unchanged.

---

## 3. Removing departed users safely

The three non-owner roles in production — `saylords`, `jsettel`, `projectjay` — appear to be
former interns or collaborators. Removing them is worth doing: every unused login role is an
unmonitored credential. But this is the operation where haste destroys data, so the order of
steps below is not negotiable.

### Why `DROP ROLE` refuses

```
ERROR:  role "jsettel" cannot be dropped because some objects depend on it
DETAIL: 192 objects in database cogdb
```

A role cannot be dropped while anything in any database still references it — either because
it **owns** objects or because it **holds privileges** on them. The error is deliberately
conservative and is doing you a favour.

### The dangerous shortcut

The first answer most searches return is:

```sql
DROP OWNED BY jsettel;   -- DO NOT run this first
```

Read the name carefully. `DROP OWNED BY` **drops every object that role owns** — tables and
all the rows in them — and additionally revokes its privileges. On a role that happens to own
nothing it is harmless; on a role that owns a single forgotten table holding a decade of notes,
it is silent, immediate, irreversible data loss. There is no confirmation prompt and no undo.

The safe sequence inverts this: **change ownership first, so that by the time you run
`DROP OWNED BY` there is nothing left for it to drop.**

### Step 0 — take a fresh dump

Not optional. A current structural dump plus the most recent blob baseline is the only thing
standing between a mistake and a decade of records. See the
[backup strategy](/dev/subsystems/db/cnf-backup-strategy).

### Step 1 — inventory what the role actually holds

Run all of these **in every database**, not just `cogdb`:

```sql
-- Objects OWNED by the role. If this returns rows, DROP OWNED BY would destroy them.
SELECT n.nspname AS schema, c.relname AS object, c.relkind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relowner = 'jsettel'::regrole
ORDER BY 1, 2;

-- Schemas owned by the role
SELECT nspname FROM pg_namespace WHERE nspowner = 'jsettel'::regrole;

-- Functions owned by the role
SELECT n.nspname, p.proname
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proowner = 'jsettel'::regrole;

-- Privileges the role merely HOLDS (safe to revoke; nothing is destroyed)
SELECT table_schema, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'jsettel';

-- Every database that records a dependency — tells you where to repeat this
SELECT d.datname, count(*)
FROM pg_shdepend s JOIN pg_database d ON d.oid = s.dbid
WHERE s.refobjid = 'jsettel'::regrole::oid
GROUP BY d.datname;
```

The critical question is the first query. **Empty result = the role owns nothing and the
cleanup is purely a revocation.** Non-empty = stop and decide, object by object, what should
happen to each one before going further.

### Step 2 — confirm the role is genuinely unused

```sql
-- Anyone connected as this role right now?
SELECT pid, usename, application_name, client_addr, state, query_start
FROM pg_stat_activity WHERE usename = 'jsettel';
```

And check outside the database: grep the application config and any server config for the
username — a role that turns out to be wired into a connection pool fails loudly and at the
worst possible moment.

```bash
grep -rn "jsettel" codeconnect/server/ src/main/webapp/WEB-INF/classes/
```

### Step 3 — dry run inside a transaction

`REASSIGN OWNED`, `DROP OWNED`, and `DROP ROLE` are all transactional in PostgreSQL. That means
you can execute the entire cleanup, inspect the result, and then throw it away:

```sql
BEGIN;

REASSIGN OWNED BY jsettel TO sylvia;
DROP OWNED BY jsettel;
DROP ROLE jsettel;

-- Look around. Does anything you care about still exist?
SELECT count(*) FROM public.blobbytes;
SELECT count(*) FROM public.cecase;

ROLLBACK;   -- <<< nothing above this line was kept
```

If that block completes without error, the real run is the same text with `COMMIT` in place of
`ROLLBACK`. If it errors, you have learned exactly what blocks the drop at zero cost. Get in
the habit of the `ROLLBACK` version first — it is the cheapest safety measure available and it
costs one word.

### Step 4 — the real sequence

```sql
-- Per database. REASSIGN and DROP OWNED are per-database operations;
-- DROP ROLE is cluster-wide and comes last, once every database is clean.
BEGIN;
REASSIGN OWNED BY jsettel TO sylvia;  -- moves ownership; destroys nothing
DROP OWNED BY jsettel;                -- now only revokes; there is nothing left to drop
COMMIT;

-- After repeating the above in every database that appeared in the pg_shdepend query:
DROP ROLE jsettel;
```

`REASSIGN OWNED BY … TO sylvia` is the load-bearing line. After it runs, the role owns nothing,
so the subsequent `DROP OWNED BY` can only revoke privileges and remove default-privilege
rules. That is the whole trick: the dangerous command is made safe by the one before it.

Reassigning to `sylvia` is the expedient choice today because `sylvia` already owns everything.
If section 4's separate owner role gets built first, reassign to that instead.

### Checklist

- [ ] Fresh structural dump taken and manifest-verified
- [ ] Ownership inventory run **in every database**, result understood
- [ ] No live sessions; username absent from app and server config
- [ ] Full sequence dry-run inside `BEGIN … ROLLBACK` with no errors
- [ ] `REASSIGN OWNED` before `DROP OWNED`, every time, no exceptions
- [ ] `DROP ROLE` only after every database is clean
- [ ] Removal recorded — who, when, why — so a later "where did this grant go?" has an answer

---

## 4. Production role design

### What the current design costs

One role, `sylvia`, is simultaneously:

- the **owner** of every table, sequence, function, and schema
- the credential in the **WildFly connection pool** (`java:jboss/postgresDS`), used by every
  request — administrator, code officer, and anonymous public form submission alike
- the identity used for **DB patch application** and ad hoc DBA work

Two distinct problems are tangled together here, and they are worth separating because they
have different costs and different fixes.

**Problem one: the application connects as the object owner.** Every SQL statement the
application issues carries the authority to `DROP TABLE`, `TRUNCATE`, or `ALTER` anything. No
application code path intends to do that, which is precisely why nothing would stop it. This
is the higher-severity problem and it has the cheaper fix.

**Problem two: every context shares one identity.** An anonymous public form submission runs
with the same authority as an authenticated system administrator. There is no database-level
boundary between the least trusted entry point in the system and the most privileged one, and
no audit trail that can distinguish them.

### The conventional layering

For an application of this scale — municipal, single-database, modest concurrency — the
generally accepted pattern separates *owning* from *using*, then subdivides *using* by trust
level:

| Role | Attributes | Holds | Used by |
|---|---|---|---|
| `cnf_owner` | `NOLOGIN` | Owns all objects | Nothing connects as it; an admin `SET ROLE`s to it |
| `cnf_migrate` | `LOGIN` | Member of `cnf_owner` | DB patch application only; restricted in `pg_hba.conf` |
| `cnf_app` | `LOGIN` | `SELECT/INSERT/UPDATE/DELETE` on app tables; **no DDL, owns nothing** | The main WildFly pool |
| `cnf_public` | `LOGIN` | Narrow write on the public-submission path; read on the lookups it needs | A second WildFly pool for public-facing writes |
| `cnf_readonly` | `NOLOGIN` | `pg_read_all_data` | Backups, reporting, analyst access |
| `cnf_backup` | `LOGIN` | Member of `cnf_readonly` | The backup scripts (section 2) |

The single highest-value change in that table is the `cnf_app` row. Moving the main pool off
the owner role eliminates DDL from the application's reach entirely, requires no application
code changes at all, and can be done independently of everything else. If only one thing gets
done, do that one.

### Should public-facing writes be segmented? Yes — and the schema boundary already exists

This is the question worth answering concretely, because the usual objection is that carving
out a public-write role means auditing hundreds of tables to decide which are in scope.

It does not, here, because the public-applications work already put the public-facing organs in
their own schema. `dbpatch_beta99.sql` creates `worldfacing.publicformsubmission`,
`worldfacing.publicformfieldvalue`, `worldfacing.publicformsubmissionperson` and the rest in the
**`worldfacing`** schema, deliberately separate from `public`. That is a ready-made privilege
boundary and it did not exist by accident.

So the grant set for a public-facing role is small and describable:

```sql
CREATE ROLE cnf_public LOGIN PASSWORD 'REPLACE_WITH_GENERATED_SECRET';

-- Write only where anonymous submissions land.
GRANT USAGE ON SCHEMA worldfacing TO cnf_public;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA worldfacing TO cnf_public;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA worldfacing TO cnf_public;

-- Read only what a form must render: municipalities, form definitions, code elements.
-- Enumerate these explicitly. Resist "GRANT SELECT ON ALL TABLES IN SCHEMA public" —
-- that hands the least-trusted entry point every person record in the database.
GRANT USAGE ON SCHEMA public TO cnf_public;
GRANT SELECT ON public.municipality TO cnf_public;
-- …and each additional lookup table the public form path genuinely reads.
```

Note what this role conspicuously lacks: `UPDATE` and `DELETE` anywhere, and any access at all
to `public.person`, `public.cecase`, `public.blobbytes`, or the `workflow` schema. A defect in
the public form path becomes an append-only nuisance in one schema instead of a route to every
enforcement record TCVCOG holds.

The awkward part to plan for honestly is **blob uploads**. If public submissions can attach
documents, `cnf_public` needs `INSERT` on `public.blobbytes` — which crosses the boundary back
into `public`. `INSERT`-only on an insert-only table is a defensible exception (the role still
cannot read anyone else's attachments, nor modify its own), but it should be a deliberate,
documented exception rather than something that arrives by accident later.

### Implementing it in WildFly

The mechanism is a second datasource. Concretely, given the current configuration:

**1. Add a datasource** in `standalone-full.xml`, beside the existing `postgresDS` block:

```xml
<datasource jta="false" jndi-name="java:jboss/postgresPublicDS" pool-name="postgresPublicDS"
            enabled="true" use-java-context="true" use-ccm="false">
    <connection-url>jdbc:postgresql://127.0.0.1:5432/cogdb</connection-url>
    <driver-class>org.postgresql.Driver</driver-class>
    <driver>postgresql</driver>
    <pool>
        <min-pool-size>1</min-pool-size>
        <max-pool-size>10</max-pool-size>
    </pool>
    <security>
        <user-name>cnf_public</user-name>
        <password>REPLACE_ME</password>
    </security>
</datasource>
```

A separate pool is not pure overhead: it also caps how many connections the public path can
consume, so a bot hammering the form cannot starve the authenticated application of its 20
connections. Size it well below the main pool.

**2. Add the JNDI name** alongside the existing key in
`src/main/webapp/WEB-INF/classes/dbconnection.properties`:

```properties
jndi_name=postgresDS
jndi_name_public=postgresPublicDS
```

**3. Add one accessor.** `BackingBeanUtils.getPostgresCon()` already resolves the datasource by
looking up `jndi_name` from that bundle under the `java:jboss/` context. A sibling method
reading `jndi_name_public` instead is a small, mechanical addition, and every integrator
already obtains its connection through this one path — so the segmentation is applied by
choosing which accessor an integrator method calls, with no change to any SQL.

**4. Route the public-form integrator methods** to the new accessor. This is the part requiring
judgement rather than mechanism: the boundary must be drawn at the *integrator* methods reached
by anonymous request paths, and it has to hold. A method that quietly serves both an
authenticated screen and the public form is the failure mode to watch for — if it needs the
privileged connection for the authenticated case, it will fail for the public one, which is the
correct and safe direction for it to fail.

**5. Verify by breaking it on purpose.** Point the public datasource at `cnf_public`, then
confirm an authenticated admin screen still works *and* that a deliberately over-reaching
public path fails with a permission error rather than succeeding. A segmentation that has never
been observed to deny anything has not been tested.

### What not to do yet: row-level security

PostgreSQL's RLS could enforce municipality-scoped access in the database rather than in
coordinator code, which is genuinely attractive for a multi-tenant municipal system. It is
still the wrong next step:

- It requires the connection to carry per-request identity, but WildFly **pools** connections
  across requests. Each request would have to `SET LOCAL` a session variable inside its
  transaction for `current_setting('app.municode')` to be meaningful — a leak there is a
  cross-municipality data exposure, which is worse than the problem being solved.
- Policies are invisible in application code. A query that silently returns fewer rows than
  expected is a genuinely hard class of bug to diagnose.
- It does nothing about the actual current risk, which is DDL authority in the application
  tier.

Revisit after the ownership split has been running in production for a while. The ordering
matters: RLS on top of a sound role design is a refinement; RLS instead of one is a distraction.

### Suggested order of work

1. **`cnf_backup` + `pg_read_all_data`, and repoint the backup scripts.** Isolated, reversible,
   no application impact. Section 2.
2. **Remove the departed intern roles.** Section 3. Independent of everything else.
3. **Create `cnf_app` and move the main WildFly pool onto it.** The big win. Requires a
   deployment and a rollback plan; no code changes. Test in a scratch restore first — grant the
   DML set, run the application against it, and fix every permission error before going near
   production.
4. **Split ownership into `cnf_owner` and migration access.** Best bundled with the
   PostgreSQL 14→18 upgrade, since both involve a maintenance window and both touch every object.
5. **`cnf_public` and the second datasource.** After the public-applications subsystem
   stabilises, so the boundary is drawn around a known set of integrator methods rather than a
   moving one.
6. Reconsider RLS, `REVOKE CREATE ON SCHEMA public FROM PUBLIC`, and per-role audit logging.

---

## Open questions

- **Is `sylvia` a superuser, or only the object owner?** Unanswerable from any dump; run the
  `pg_roles` query at the top of this page. It changes what step 3 and step 4 above must do.
- **What are `saylords`, `jsettel`, and `projectjay` actually for?** The grant counts (372 /
  192 / 163) and `saylords`' reach across four schemas suggest more than a read-only analyst
  account. Confirm none is wired into anything live before removing it.
- **Do public form submissions need to attach files?** Determines whether `cnf_public` needs
  the `public.blobbytes` `INSERT` exception described above.
- **Where should section 4 ultimately live?** It is application architecture as much as
  database administration, and may belong with the public-applications subsystem docs in the
  `codenforce` repo once that work settles.
