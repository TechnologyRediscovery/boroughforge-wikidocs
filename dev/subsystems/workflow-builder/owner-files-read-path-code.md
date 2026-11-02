---
title: Owner Files — Read Path Code Walkthrough
description: How the coordinator and integrator read the link graph — seeds, the derive entry points, and the SQL behind each bulk read, dissected line by line
published: false
date: 2026-10-19T11:45:00.000Z
tags: subsystem:workflow-builder, audience:dev, type:reference
editor: markdown
dateCreated: 2026-10-19T11:45:00.000Z
---

# Owner Files — Read Path Code Walkthrough

Prerequisites: [data model](/dev/subsystems/workflow-builder/owner-files-data-model) and
[derivation theory](/dev/subsystems/workflow-builder/owner-files-derivation-theory). This page follows a
request from the **coordinator** down through the **integrator's SQL** and back up into the **pure
deriver**. It covers every path that *reads* the graph. The [write path](/dev/subsystems/workflow-builder/owner-files-write-path-code)
is the companion page.

Source files (codenforce repo, package `com.tcvcog.tcvce`):

- `coordinators/OwnerFileCoordinator.java` — business logic and derive entry points
- `integration/OwnerFileIntegrator.java` — JDBC only
- `coordinators/OwnerFileDeriver.java` — the pure graph walk (previous page)

## 1. The shape of the classes

```java
@Named("ownerFileCoordinator")
@ApplicationScoped
public class OwnerFileCoordinator extends BackingBeanUtils implements Serializable {
    ...
    /** Stateless, so one shared instance is safe on an application-scoped bean. */
    private final OwnerFileDeriver deriver = new OwnerFileDeriver();
```

Three things follow from this declaration:

1. **`@ApplicationScoped` = one contextual instance for the whole server**, shared by every user and thread
   (callers actually hold a CDI client proxy that forwards to it). A field written during one request is
   visible to the next user's request. **Never store per-request data in a field of the coordinator or
   integrator.** All per-call state lives in method locals and in the small `DeriveSetup` object (below). The
   deriver is a field only because it is stateless. *(Caveat: the shared base class `BackingBeanUtils` itself
   keeps a few per-call values in fields, `connx` and `sessionBean`; see
   [deriver vs coordinator §6.3](/dev/subsystems/workflow-builder/owner-files-deriver-vs-coordinator) for the
   observed hazard and why the owner-file code passes identity as arguments.)*
2. **`extends BackingBeanUtils`** gives access to the other coordinators/integrators
   (`getOwnerFileIntegrator()`, `getPropertyCoordinator()`, …), the session, and `getResourceBundle(...)`.
   Each `getXxx()` is a **service locator**: it asks JSF's Expression Language for the bean by name
   (`#{ownerFileCoordinator}`) at the moment of use, rather than having it injected. That is how the repo
   wires its 3 tiers together. The integrator does the same (`OwnerFileIntegrator extends BackingBeanUtils`)
   mainly to reach `getPostgresCon()` and `releasePostgresConnection(...)`. The Java mechanics (static nested
   classes, `final`, inheritance) are explained in the
   [class design primer](/dev/subsystems/workflow-builder/owner-files-java-class-design-primer).
3. **Method naming.** Public coordinator methods are `ownerfile_verbPhrase`. Private helpers are plain
   camelCase.

### The permission gate (BB Rule 8)

```java
public boolean ownerfile_isManageAllowed(UserAuthorized ua) {
    return ua != null && ua.getKeyCard() != null && ua.getKeyCard().isHasMuniStaffPermissions();
}

private void ownerfile_verifyManagePermission(UserAuthorized ua) throws AuthorizationException {
    if (ua == null || ua.getKeyCard() == null) { …throw… }
    if (!ownerfile_isManageAllowed(ua)) { …throw… }
}
```

The rule is **exactly one computation, two uses**: the *query* (`ownerfile_isManageAllowed`) returns a boolean
for `rendered=`; the *verify* method throws. Every public method that touches data starts with
`ownerfile_verifyManagePermission(ua)`. The bean never inspects the user's key card. Read-only derive
methods are gated too (MuniStaff and above, R-7). The only methods *not* gated by `verifyManagePermission`
are pure queries and the reverse lookup, which uses its own muni-only visibility rule
(`ownerfile_isMembershipVisible`, Q-V17-13: any signed-in user working in the muni).

### One server-log line per operation

```java
private void logShape(String method, String message) {
    System.out.println("OwnerFileCoordinator." + method + " | " + message);
}
```

The house pattern (`Class.method | …`). Messages carry **ids, counts and operation names only**, never names,
titles, addresses or free text, so the server log shows the *shape* of what happened without becoming a
second copy of personal data. Derivations log a READ line; writes log a CREATE/UPDATE/DELETE line.

## 2. The read entry points

| Public method | Mode (see theory §5) | What it returns | Reads scope |
|---|---|---|---|
| `ownerfile_deriveAll(muni, seedGroupID, ua)` | **Group-seeded** | Proposed + saved files over one parcel group; ownerless group parcels; summary | **Muni-wide** owner links and control edges |
| `ownerfile_deriveSaved(muni, referenceGroup, ua)` | **Saved-files** (the panel's default view) | Each saved file read from its head | Scoped to the saved heads |
| `ownerfile_getLinkGraph(head, muni, referenceGroup, ua)` | **Single head** | One derived file; a *preview* (file number 0) if the person has no file | Scoped to one head |
| `ownerfile_getMembershipsForProperty / ForPerson` | **Membership** | Slim `OwnerFileMembership` list | Scoped to a handful of humans; see the [lookup page](/dev/subsystems/workflow-builder/owner-files-membership-lookup) |
| `ownerfile_getSeedLorList`, `ownerfile_getSeedGroupChoices`, `ownerfile_getDefaultSeedGroup(…)` | config | Seed rows, group dropdown choices | one small query each |
| `ownerfile_getUnsavedProposals(derivation)`, `ownerfile_getPropertyRows(derivation)` | pure, no DB | Filter/reshape an already-derived result for the UI (unsaved only; by-property table) | none |
| `ownerfile_getLogs`, `ownerfile_getPendingReview` | log reads | Log rows | one file / one muni |

The first three share the same *algorithm* (they all call `deriver.derive`); they differ only in **which rows
they feed it**.

## 3. Seeds in code

### Reading

```java
public List<OwnerFileSeedLor> getSeedLorList(int muniCode) throws IntegrationException {
    String sql = """
            SELECT s.seedlorid, s.muni_municode, s.linkedobjectrole_lorid, lor.title AS lortitle,
                   s.seedkind, s.controllerside, s.notes,
                   s.createdts, s.createdby_userid
              FROM workflow.ownerfileseedlor s
              JOIN public.linkedobjectrole lor ON lor.lorid = s.linkedobjectrole_lorid
             WHERE s.deactivatedts IS NULL
               AND (s.muni_municode IS NULL OR s.muni_municode = ?)
             ORDER BY s.seedkind, s.linkedobjectrole_lorid, s.seedlorid
            """;
```

- `deactivatedts IS NULL` → only **active** seed rows.
- `(muni_municode IS NULL OR muni_municode = ?)` → the **all-muni rows plus this muni's own rows**. That is
  how a seed can be scoped to one town.
- The join to `linkedobjectrole` exists to fetch the human-readable **`title`**, which later labels parcel and
  member rows ("currently owns").
- The text columns are parsed leniently:

```java
/** The column is open-ended TEXT, so an unknown value is left null rather than failing the read. */
private OwnerFileSeedKind parseSeedKind(String text) {
    try {
        return text == null ? null : OwnerFileSeedKind.valueOf(text);
    } catch (IllegalArgumentException ex) {
        return null;
    }
}
```

A typo in `seedkind` does **not** throw; it yields a seed with a null kind, which `classifySeeds` turns into
a visible "setup problem". This is a deliberate trade: open-ended TEXT means a new kind needs no DDL, and a
bad row does not take the whole panel down.

### Classifying

```java
private void classifySeeds(DeriveSetup setup) {
    for (OwnerFileSeedLor s : setup.seeds) {
        if (s.getLorTitle() != null) {
            setup.input.roleTitleByLorID.put(s.getLorID(), s.getLorTitle());
        }
        if (s.getSeedKind() == null) {
            setup.problems.add("Seed row " + s.getSeedLorID() + " (role " + s.getLorID()
                    + ") has a kind this version does not recognise and was ignored.");
            continue;
        }
        switch (s.getSeedKind()) {
            case OWNS_PARCEL:
                addOnce(setup.ownerLorIDs, s.getLorID());
                break;
            case OWNER_OCCUPANT:
                addOnce(setup.ownerLorIDs, s.getLorID());
                setup.input.occupantLorIDs.add(s.getLorID());
                break;
            case CONTROLS_HUMAN:
                if (s.getControllerSide() == null) {
                    setup.problems.add("Control seed row … has no controller side and was ignored.");
                } else {
                    addOnce(setup.controlLorIDs, s.getLorID());
                    setup.input.controlSideByLorID.put(s.getLorID(), s.getControllerSide());
                }
                break;
            default:
                break;
        }
    }
}
```

This turns the seed *table* into the *lists and maps the walk needs*:

| Output | Feeds |
|---|---|
| `setup.ownerLorIDs` (`OWNS_PARCEL` ∪ `OWNER_OCCUPANT`) | `ANY(?)` in every owner-link SQL (the `OWNER_LINK_PREDICATE`) |
| `setup.controlLorIDs` (`CONTROLS_HUMAN`) | `ANY(?)` in the control-edge SQL |
| `setup.input.occupantLorIDs` | the deriver's `ownerOccupied` marker |
| `setup.input.controlSideByLorID` | the deriver's orientation step |
| `setup.input.roleTitleByLorID` | display titles |
| `setup.problems` | Strings shown at the top of the panel (the "setup problems") |

Note `OWNER_OCCUPANT` goes into **both** `ownerLorIDs` (it counts as ownership) and `occupantLorIDs` (it marks
the parcel).

### `DeriveSetup`: per-call state

```java
private static class DeriveSetup {
    final OwnerFileDeriver.Input input = new OwnerFileDeriver.Input();
    List<OwnerFileSeedLor> seeds = new ArrayList<>();
    final List<Integer> ownerLorIDs = new ArrayList<>();
    final List<Integer> controlLorIDs = new ArrayList<>();
    final List<String> problems = new ArrayList<>();
    DeriveSetup(Municipality muni, OwnerFileGroupChoice group) { … }
}
```

This is the repo's "**context inner class**" pattern: instead of passing five arguments to every helper, one
object carries the call's working state. It lives only for the duration of one call (hence thread-safe on an
application-scoped bean).

### What happens when seeds are missing

Both derive paths check:

```java
if (setup.ownerLorIDs.isEmpty()) {
    setup.problems.add("No owner role is seeded (workflow.ownerfileseedlor needs an OWNS_PARCEL row such as LOR 116). …");
    return finishDerivation(setup, deriver.derive(in), method, ua);   // an empty derivation
}
if (setup.controlLorIDs.isEmpty()) {
    setup.problems.add("No control role is seeded (CONTROLS_HUMAN, LOR 2205): no entity is folded into an owner's file, …");
}
```

- **No owner seed → empty result** (nothing can be an owner). The query reads are skipped entirely.
- **No control seed → still works**, but nothing folds: every owner heads their own file. (Also,
  `getControlEdgeRows*` short-circuit and return an empty list when `controlLorIDs` is empty.)

## 4. The SQL, dissected

All reads are **set-based**: one query takes *arrays* of ids (`= ANY(?)`) rather than one query per id.

### 4.1 How an array reaches the query

```java
private Array intArray(Connection con, Collection<Integer> ids) throws SQLException {
    return con.createArrayOf("integer", ids.toArray(new Integer[0]));
}
...
stmt.setArray(i++, intArray(con, ownerLorIDs));
```

`WHERE hp.linkedobjectrole_lorid = ANY(?)` means "is the value *equal to any element* of this array". One
round trip answers for any number of ids. This replaces the `N+1` anti-pattern (a loop issuing one query per
human).

### 4.2 `OWNER_LINK_PREDICATE`, the shared definition of "owner"

```java
private static final String OWNER_LINK_PREDICATE =
        "hp.deactivatedts IS NULL AND hp.archivedts IS NULL"
        + " AND hp.validfrom <= now() AND hp.validto > now()"
        + " AND hp.linkedobjectrole_lorid = ANY(?)";
```

It is **concatenated into several queries** (D1, D5, the head finder, the parcel-owner lookup). That is the
mechanism behind rule 6 on the orientation page: "owner" means exactly the same thing everywhere because it
is one string. The alias `hp` (= `humanparcel`) must be used in each query that embeds it.

### 4.3 D1: `readOwnerLinkRows`

```java
String sql = "SELECT hp.linkid AS humanparcellinkid, hp.human_humanid, hp.linkedobjectrole_lorid AS ownerlorid, "
        + "       p.parcelkey, p.parcelidcnty, "
        + "       EXISTS (SELECT 1 FROM public.parcelparcelgroup ppg "
        + "                WHERE ppg.parcel_parcelkey = p.parcelkey AND ppg.parcelgroup_groupid = ? "
        + "                  AND ppg.deactivatedts IS NULL) AS inseedgroup, "
        + "       sit.* "
        + "  FROM public.humanparcel hp "
        + "  JOIN public.parcel p ON p.parcelkey = hp.parcel_parcelkey AND p.muni_municode = ? AND p.deactivatedts IS NULL "
        + "  JOIN public.human h ON h.humanid = hp.human_humanid AND h.deactivatedts IS NULL "
        + SITUS_LATERAL
        + " WHERE " + OWNER_LINK_PREDICATE
        + (humanIDsOrNull == null ? "" : " AND hp.human_humanid = ANY(?)")
        + " ORDER BY p.parcelkey, hp.linkid";
```

Read the SQL **in the order the database logically evaluates it**:

1. `FROM public.humanparcel hp` — start from the owner **edges**.
2. `JOIN public.parcel p … AND p.muni_municode = ?` — **the muni fence**: drop edges to parcels outside the
   session muni; drop deactivated parcels (M1/R-21).
3. `JOIN public.human h … deactivatedts IS NULL` — drop edges whose owner human is deactivated.
4. `SITUS_LATERAL` — attach the parcel's street address (4.4 below).
5. `WHERE OWNER_LINK_PREDICATE` — only active edges with a seeded ownership role.
6. `AND hp.human_humanid = ANY(?)` — **only when `humanIDsOrNull != null`**: the **scoped** variant. With
   `null` it reads the *whole muni's* owner links (the group-seeded run). This one flag is what turns the same
   SQL into the muni-wide or the scoped read.
7. The `EXISTS (…) AS inseedgroup` column is a per-row Boolean "is this parcel in the chosen group?". When no
   reference group is wanted the caller passes group id `0`, which matches nothing, so every row gets
   `false`.

**Binding order must match the `?` order in the string**, which is why the code is written as a strict
sequence:

```java
stmt.setInt(i++, seedGroupID);                       // 1: EXISTS(... groupid = ?)
stmt.setInt(i++, muniCode);                          // 2: p.muni_municode = ?
stmt.setArray(i++, intArray(con, situsLorIDs));      // 3: inside SITUS_LATERAL
stmt.setArray(i++, intArray(con, ownerLorIDs));      // 4: OWNER_LINK_PREDICATE
if (humanIDsOrNull != null) {
    stmt.setArray(i++, intArray(con, humanIDsOrNull));  // 5: scoped variant only
}
```

> **If you edit any of these SQL strings, re-count the `?` placeholders and the `setXxx` calls.** A mismatch is
> the most common way to break this file; it fails at runtime, not at compile time.

### 4.4 `SITUS_LATERAL`: the "pick one address per parcel" trick

```java
private static final String SITUS_LATERAL = "LEFT JOIN LATERAL (SELECT "
        + addressColumns("pma")
        + " FROM public.parcelmailingaddress pma "
        + addressJoins("pma", "mailingaddress_addressid")
        + " WHERE pma.parcel_parcelkey = p.parcelkey"
        + "   AND pma.linkedobjectrole_lorid = ANY(?)"
        + "   AND pma.deactivatedts IS NULL AND pma.validfrom <= now() AND pma.validto > now()"
        + " ORDER BY pma.priority NULLS LAST, pma.linkid LIMIT 1) sit ON true ";
```

A **`LATERAL` subquery** is a subquery that may refer to columns of the row on its left (`p.parcelkey`). For
every parcel row it runs the inner `SELECT` and keeps `LIMIT 1` of the ordered result. In plain words: "for
each parcel, find its **one** best situs address link, or none." `LEFT JOIN … ON true` keeps the parcel even
when there is no such link (the situs columns are then all NULL).

Effects to remember:

- A parcel with 2+ situs links yields **one** row: lowest `priority`, then lowest `linkid`.
- Because the `?` array here is the **situs roles** (100, 235), the same table `parcelmailingaddress` is read
  for a *different purpose* than the owner-mailing role 233 (that is D3b).
- The mapper detects "no situs" like this:

```java
rs.getInt("addressid");
if (!rs.wasNull()) {                // LEFT JOIN produced NULL → the parcel has no situs
    OwnerFileAddressRow situs = generateAddressRow(rs);
    …
}
```

`rs.getInt` returns `0` for SQL NULL, so the code calls `wasNull()` immediately after to tell a genuine 0
from a NULL. That is the JDBC idiom you will see everywhere in the integrator.

### 4.5 D2: control edges, two flavours

**Muni-wide** (`getControlEdgeRows`, used by `ownerfile_deriveAll`): control links around *every owner in the
muni*, followed **two hops**.

```sql
WITH o AS (                                   -- the set of owners in this muni
    SELECT DISTINCT hp.human_humanid AS hid
      FROM public.humanparcel hp
      JOIN public.parcel p ON p.parcelkey = hp.parcel_parcelkey
                          AND p.muni_municode = ? AND p.deactivatedts IS NULL
     WHERE <OWNER_LINK_PREDICATE>
), e1 AS (                                    -- HOP 1: control links touching an owner
    SELECT hh.human_humanid, hh.humantarget_humanid
      FROM public.humanhuman hh
     WHERE hh.deactivatedts IS NULL AND hh.archivedts IS NULL
       AND hh.linkedobjectrole_lorid = ANY(?)
       AND (hh.human_humanid IN (SELECT hid FROM o) OR hh.humantarget_humanid IN (SELECT hid FROM o))
), ends AS (                                  -- both ends of every hop-1 link
    SELECT human_humanid AS hid FROM e1
    UNION
    SELECT humantarget_humanid FROM e1
)
SELECT DISTINCT hh.linkid, hh.linkedobjectrole_lorid, hh.human_humanid, hh.humantarget_humanid
  FROM public.humanhuman hh                    -- HOP 2: control links touching ANY end
 WHERE hh.deactivatedts IS NULL AND hh.archivedts IS NULL
   AND hh.linkedobjectrole_lorid = ANY(?)
   AND (hh.human_humanid IN (SELECT hid FROM ends) OR hh.humantarget_humanid IN (SELECT hid FROM ends))
 ORDER BY hh.linkid
```

Reading: a **CTE** (`WITH … AS`) names an intermediate result, like a temporary table.

- `o` = every distinct owner in the muni.
- `e1` = control links that touch an owner at **either** end (direction is not interpreted in SQL).
- `ends` = every human at either end of those links (the owners **and** their neighbours).
- The final `SELECT` = *all control links touching any human in `ends`*. That is **hop 2**: it reveals the
  *controllers of the controllers*, which is how the deriver can tell that a controller is itself controlled
  (L1, `DEEP_CHAIN_IGNORED`) and whether an entity has a **second controller** (F2).

**Scoped** (`getControlEdgeRowsAround(humanIDs, controlLorIDs)`): identical shape, but `o` is replaced by the
caller-supplied `humanIDs` (`= ANY(?)`). It is the read behind the saved-files view, the single-head graph
and the reverse lookup. Two hops means it finds, from a head *H*:
(1) *H*'s controlled entities, and (2) any **other** controller of those entities, which is what the sole-controller
rule needs.

Two caveats, both discussed with evidence on the [lookup page](/dev/subsystems/workflow-builder/owner-files-membership-lookup):
- the **second stage** uses `… IN (SELECT …) OR … IN (SELECT …)`, which PostgreSQL typically plans as a scan
  over `humanhuman` (no role index exists); and
- hop 2 is more than a membership answer strictly needs.

### 4.6 D5: ownerless group parcels

```sql
SELECT p.parcelkey, p.parcelidcnty, sit.*
  FROM public.parcel p  <SITUS_LATERAL>
 WHERE p.muni_municode = ? AND p.deactivatedts IS NULL
   AND p.parcelkey IN (SELECT ppg.parcel_parcelkey FROM public.parcelparcelgroup ppg
                        WHERE ppg.parcelgroup_groupid = ? AND ppg.deactivatedts IS NULL)
   AND NOT EXISTS (SELECT 1 FROM public.humanparcel hp
                     JOIN public.human h ON h.humanid = hp.human_humanid AND h.deactivatedts IS NULL
                    WHERE hp.parcel_parcelkey = p.parcelkey AND <OWNER_LINK_PREDICATE>)
```

"Group parcels that **no active owner link points at**": they can neither seed a file nor receive one
(Sharpsburg: 9 of 422). `NOT EXISTS` is the SQL form of set difference. They appear in the seed dialog's
"parcels with no owner" table and as an appendix on the audit sheet.

### 4.7 D4: saved files as shells

```java
private static final String SHELL_SELECT = """
        SELECT f.ownerfileid, f.muni_municode, f.head_humanid, f.title, f.canonicalname,
               f.humanmailingaddress_linkid, f.parcelmailingaddress_linkid, f.paperfileref, f.notes,
               f.createdts, f.createdby_userid, f.lastupdatedts, f.lastupdatedby_userid,
               latest.operation AS lastoperation, latest.entrytimestamp AS lastts
          FROM workflow.ownerfile f
          LEFT JOIN LATERAL (SELECT l.operation, l.entrytimestamp
                               FROM workflow.ownerfilelog l
                              WHERE l.ownerfile_ownerfileid = f.ownerfileid
                              ORDER BY l.entrytimestamp DESC, l.ownerfilelogid DESC
                              LIMIT 1) latest ON true
        """;
```

Every "get a saved file" method appends a `WHERE` to this one string (`getActiveOwnerFile`,
`getActiveOwnerFileList`, `getActiveOwnerFileByHead`, `getActiveOwnerFilesByHeads`). The lateral again picks
"the latest log row for this file" for the **Last activity** column; `ownerfilelog_file_ts_idx` makes that an
index probe. Note the shell carries the head as an **id-only** `Human`; the deriver replaces it with the
loaded person (`ctx.in.humans`).

### 4.8 D7: lock state

```sql
SELECT DISTINCT ON (l.ownerfile_ownerfileid, l.rentalcycle)
       l.ownerfile_ownerfileid, l.rentalcycle, l.operation, l.entrytimestamp
  FROM workflow.ownerfilelog l
  JOIN workflow.ownerfile f ON f.ownerfileid = l.ownerfile_ownerfileid AND f.deactivatedts IS NULL
 WHERE l.muni_municode = ?
   AND l.operation IN ('LOCKED_FOR_CYCLE_MAILING', 'UNLOCKED')
   AND l.rentalcycle IS NOT NULL
 ORDER BY l.ownerfile_ownerfileid, l.rentalcycle, l.entrytimestamp DESC, l.ownerfilelogid DESC
```

**`DISTINCT ON (a, b)`** is PostgreSQL's "keep the first row for each (a, b) group, in the `ORDER BY` order".
With the order `… entrytimestamp DESC`, "first" means *latest*. So you get, for every (file, cycle), its
most recent lock-or-unlock row, from which the deriver computes `isLockedForCycle`. This is how
**"state = latest log row"** (R-6) is implemented with no status column.

### 4.9 D3 and D6: addresses and people

| Method | Query idea | Notes |
|---|---|---|
| `getHumanMailingAddressRows(humanIDs)` | `humanmailingaddress` ⋈ address tables where `deactivatedts IS NULL AND priority >= 0`, freshest first | `priority >= 0` is "not hidden". Priority is **not** used for ranking |
| `getParcelMailingAddressRows(parcelKeys, roleID)` | `parcelmailingaddress` where role = 233 and active and in its validity window | The legacy county-scrape owner address; feeds the ladder |
| `getParcelMailingAddressRowsAnyRole(parcelKeys)` (D3e) | the same predicate with **no role filter** | Superset of the 233 read; feeds only the clerk's pick list. Added 2026-10-26 |
| `getPropertyManagerLinkRows(parcelKeys, managerLorIDs)` (D3f) | `humanparcel` ⋈ `human` with `OWNER_LINK_PREDICATE` and the manager role array | Which persons manage the file's parcels; their addresses come from `getHumanMailingAddressRows`. Pick list only. Added 2026-10-26 |
| `getLinkedObjectRoleTitles(lorIDs)` | `SELECT lorid, title FROM linkedobjectrole WHERE lorid = ANY(?)` | Role titles for the pick list's labels; filled into `roleTitleByLorID` with `putIfAbsent` |
| `getDeclaredHumanMailingLinkRows(linkIDs)` / `…Parcel…` | the links saved files *point at*, with an **active flag**, deliberately including retired ones | So the deriver can detect `DECLARED_LINK_DEACTIVATED` |
| `getHumanRefs(humanIDs)` | `SELECT humanid, name, businessentity, deceaseddate FROM human WHERE humanid = ANY(?)` | "Light person skeletons" (**never** a full `Human` load) |
| `getParcelGroupNames(muni, parcelKeys)` | group names per parcel | The "Groups" chips; read once per derivation and shared by parcel-row copies |

`addressColumns(alias)` and `addressJoins(alias, fkColumn)` are **tiny SQL template functions**: they emit the
same column list and join chain for any address query so every address row has identical column names and
`generateAddressRow(rs)` can map any of them.

## 5. The group-seeded derivation, annotated

`ownerfile_deriveAll(muni, seedGroupID, ua)`:

```java
ownerfile_verifyManagePermission(ua);                    // 1. permission, every time
requireMuni(muni);
OwnerFileIntegrator ofi = getOwnerFileIntegrator();

OwnerFileGroupChoice group = null;                       // 2. the group MUST belong to this muni
for (OwnerFileGroupChoice c : ofi.getSeedGroupChoices(muni.getMuniCode())) {
    if (c.getGroupID() == seedGroupID) { group = c; }
}
if (group == null) { throw new BObStatusException(…); }

DeriveSetup setup = new DeriveSetup(muni, group);        // 3. seeds -> lists and maps
setup.seeds = ofi.getSeedLorList(muni.getMuniCode());
classifySeeds(setup);
… (empty-seed early returns)

ResourceBundle fixed = getResourceBundle(Constants.DB_FIXED_VALUE_BUNDLE);   // 4. config that is not a seed
List<Integer> situsLorIDs = parseCommaSeparatedIntegerList(fixed.getString("ownerfile_situs_parcel_lorids"));

OwnerFileDeriver.Input in = setup.input;                 // 5. the three bulk reads
in.ownerLinks = ofi.getOwnerLinkRows(muni.getMuniCode(), group.getGroupID(), setup.ownerLorIDs, situsLorIDs);
in.ownerlessGroupParcels = ofi.getOwnerlessGroupParcelRows(…);
in.controlEdges = ofi.getControlEdgeRows(muni.getMuniCode(), setup.ownerLorIDs, setup.controlLorIDs);

in.existingFiles = ofi.getActiveOwnerFileList(muni.getMuniCode());   // 6. saved files (shells)

Set<Integer> allHumanIDs = …;                           // 7. who do we need names/addresses for?
for (OwnerFileParcelRow r : in.ownerLinks) { allHumanIDs.add(r.getOwnerHumanID()); … }
for (OwnerFileHeavy saved : in.existingFiles) { … saved heads … }
for (OwnerFileControlEdgeRow e : in.controlEdges) { … both ends … }
readSupportRows(setup, ofi, muni, allHumanIDs, addressCandidateIDs, parcelKeys);   // 8. names, addresses, locks, groups

OwnerFileDerivation result = deriver.derive(in);         // 9. the pure pass
result.setSeedsProposals(true);
return finishDerivation(setup, result, "ownerfile_deriveAll", ua);
```

**Step 7 is the pattern to understand.** The coordinator first *discovers which humans matter* from the rows
it already has (owners, saved heads, both ends of control edges), and only then asks "give me names and
addresses for exactly these humans" in **one** query each. This two-phase *discover, then fetch details* is how the facility avoids loading anything it does not
need: no `PropertyDataHeavy`, no per-human loads.

`readSupportRows(…)` performs the detail fetches:

```java
in.declaredHumanLinks = ofi.getDeclaredHumanMailingLinkRows(declaredHumanLinkIDs);
in.declaredParcelLinks = ofi.getDeclaredParcelMailingLinkRows(declaredParcelLinkIDs);
int ownerMailingLorID = Integer.parseInt(getResourceBundle(Constants.DB_FIXED_VALUE_BUNDLE).getString("ownerfile_ownermailing_parcel_lorid"));
in.humans = ofi.getHumanRefs(allHumanIDs);
in.humanAddressLinks = ofi.getHumanMailingAddressRows(addressCandidateIDs);
in.parcelOwnerMailingLinks = ofi.getParcelMailingAddressRows(parcelKeys, ownerMailingLorID);
in.lockRows = ofi.getLockRows(muni.getMuniCode());
Map<Integer, List<String>> groupNamesByParcel = ofi.getParcelGroupNames(muni.getMuniCode(), parcelKeys);
for (OwnerFileParcelRow r : in.ownerLinks) {
    r.setGroupNames(groupNamesByParcel.getOrDefault(r.getParcelKey(), new ArrayList<>()));
}
```

`finishDerivation` copies the seed rows and the setup problems into the result and prints the READ log line
(counts only, "writes nothing").

## 6. The scoped derivation, annotated

`ownerfile_deriveSaved` and `ownerfile_getLinkGraph` both delegate to the private `deriveFromHeads`:

```java
private OwnerFileDerivation deriveFromHeads(Municipality muni, OwnerFileGroupChoice referenceGroup,
        List<OwnerFileHeavy> savedFiles, List<Integer> forcedHeadIDs, String method, UserAuthorized ua) … {
    …
    in.headsFromSeedGroup = false;           // heads are saved heads + forced heads only
    in.existingFiles = savedFiles;
    in.forcedHeadIDs.addAll(forcedHeadIDs);
    …
    Set<Integer> headIDs = …saved heads ∪ forced…;
    in.controlEdges = ofi.getControlEdgeRowsAround(headIDs, setup.controlLorIDs);   // scoped, two hops
    Set<Integer> involved = new LinkedHashSet<>(headIDs);
    for (OwnerFileControlEdgeRow e : in.controlEdges) {                              // both ends
        involved.add(e.getSourceHumanID());
        involved.add(e.getTargetHumanID());
    }
    in.ownerLinks = ofi.getOwnerLinkRowsForHumans(muni.getMuniCode(),
            referenceGroup == null ? 0 : referenceGroup.getGroupID(), involved, setup.ownerLorIDs, situsLorIDs);
    …
    readSupportRows(setup, ofi, muni, involved, involved, parcelKeys);
    OwnerFileDerivation result = deriver.derive(in);
    result.setSeedsProposals(false);
    return finishDerivation(setup, result, method, ua);
}
```

How it differs from `deriveAll`:

| | `deriveAll` | `deriveFromHeads` |
|---|---|---|
| Starting point | a parcel group | a **set of head people** |
| Control edges | around **every owner** in the muni | around **the heads** (`getControlEdgeRowsAround`) |
| Owner links | **muni-wide** (`humanIDsOrNull == null`) | **only the involved humans** |
| `headsFromSeedGroup` | `true` | `false` |
| Proposals | yes (`setSeedsProposals(true)`) | no (`false`): an entity found along the way never becomes a proposal |
| Typical size | ~1,500 owned parcels / ~1,155 owners in Sharpsburg | a handful of saved files |

`ownerfile_getLinkGraph(head, muni, referenceGroup, ua)` is a thin wrapper: it looks up the head's saved
file; if there is one, it passes that shell; if not, it **forces** the head. Then it runs `deriveFromHeads` and
returns the one file whose head matches. With no saved file you get a *preview* with `ownerFileID == 0`. The
"Create file" path (`ownerfile_createFile`) reads the graph *just before writing*, so the log row records
what the file held at creation.

## 7. Mapping rows to objects: the `generateXxx` pattern

Every query has a paired mapper that turns one `ResultSet` row into one entity:

```java
private OwnerFileControlEdgeRow generateControlEdge(ResultSet rs) throws SQLException {
    OwnerFileControlEdgeRow e = new OwnerFileControlEdgeRow();
    e.setLinkID(rs.getInt("linkid"));
    e.setLinkRoleID(rs.getInt("linkedobjectrole_lorid"));
    e.setSourceHumanID(rs.getInt("human_humanid"));
    e.setTargetHumanID(rs.getInt("humantarget_humanid"));
    return e;
}
```

This is the repo's "Generator methods in Integrators" rule: **SQL and assembly are separate**. The query
method owns the statement lifecycle; the generator owns column→field mapping. Every read follows one shape:

```java
Connection con = getPostgresCon();
PreparedStatement stmt = null;
ResultSet rs = null;
try {
    stmt = con.prepareStatement(sql);
    … bind parameters in order …
    rs = stmt.executeQuery();
    while (rs.next()) { rows.add(generateXxx(rs)); }
} catch (SQLException ex) {
    System.out.println(ex);
    throw new IntegrationException("OwnerFileIntegrator.method | " + ex.getMessage(), ex);
} finally {
    releasePostgresConnection(con, stmt, rs);     // ALWAYS: returns the connection to the pool
}
```

The `finally` is not optional: a leaked connection starves the pool and eventually hangs the site.

**Null handling conventions** you will meet:

- `0` means "not set" for ids on entities. When writing, `setNullableInt` turns `0` into SQL `NULL`; when
  reading nullable ints, the code uses `rs.getInt(...)` followed by `rs.wasNull()`.
- Timestamps: `rs.getTimestamp(...)` then `.toLocalDateTime()` after a null check.
- Enums stored as TEXT are parsed with a try/catch `valueOf` that yields `null` for unknown text (read-side
  leniency).

## 8. Read cost: what scales with what

| Call | DB round trips (approx.) | Scales with | When it runs |
|---|---|---|---|
| `deriveAll` | seeds + group choices + 3 bulk reads + saved shells + ~7 support reads | **all owners and parcels in the muni** | When a clerk opens the seed dialog and clicks Derive, or opens the audit page with an explicit `groupID` (the older seeded run) |
| `deriveSaved` | seeds + saved shells + scoped edges + scoped owner links + ~7 support reads (**≈ 10–12**) | the number and size of **saved files** | The panel's auto-load on the Rental registry manager page, and every "Reload saved files" |
| `getLinkGraph` | same shape as `deriveSaved`, one head | one file | Opening "linked objects", "Read linked objects", create, lock |

In-memory work is a few passes over the row lists with hash maps (`O(rows)`), plus the
`O(heads × folded entities)` assembly loop noted in the theory page. The cost of a derive is dominated by
**round trips and row volume**, not CPU or RAM, for municipality-sized data.

## 9. Gotchas on the read path

1. **Placeholder order.** Every `?` in a concatenated SQL string must be bound in the order it appears,
   *including* the ones inside the shared fragments (`SITUS_LATERAL` has one; `OWNER_LINK_PREDICATE` has one).
2. **Empty arrays.** `ANY('{}')` is false for every row. The code guards with early returns
   (`if (humanIDs.isEmpty()) return …`). Do the same in new reads.
3. **Direction is never in SQL.** If you need "who controls whom", return both ends and orient in Java.
4. **The seed table is read on every call.** Changing a seed row takes effect immediately on the next
   derive (nothing is cached); there is no restart step.
5. **Situs lookup is always in the owner-link SQL.** Even a caller that does not need an address pays for the
   lateral join. (The reverse lookup passes an **empty** situs array to make it produce nothing; see the
   [lookup page](/dev/subsystems/workflow-builder/owner-files-membership-lookup) for why that is not a free
   skip.)
6. **A derivation is a snapshot.** The `OwnerFileDerivation` held by the bean is the world at the moment it
   ran. Writes (`ownerfile_updateFileNames`, `ownerfile_updateMailtoAddress`, `…_changeHead`, etc.) re-read the saved row themselves rather than
   trusting the screen. After any write the bean re-derives (`refreshSaved()`).
7. **Cross-file flags need the whole list** (theory §11). Do not look for them on a single-head result.
