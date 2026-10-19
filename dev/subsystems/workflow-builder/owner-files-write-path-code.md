---
title: Owner Files — Write Path Code Walkthrough
description: How owner-file changes are written safely — one transaction per change, the append-only audit log, optimistic concurrency, lock snapshots, and the review pipeline, with the code dissected
published: false
date: 2026-10-19T12:15:00.000Z
tags: subsystem:workflow-builder, audience:dev, type:reference
editor: markdown
dateCreated: 2026-10-19T12:15:00.000Z
---

# Owner Files — Write Path Code Walkthrough

Prerequisites: the [data model](/dev/subsystems/workflow-builder/owner-files-data-model) (especially the
`ownerfile` and `ownerfilelog` sections) and the [read path page](/dev/subsystems/workflow-builder/owner-files-read-path-code).
This page is about **every method that changes the database**. The facility changes only two tables
(`workflow.ownerfile`, `workflow.ownerfilelog`) — plus one call into the property subsystem — so the whole
write path fits on one page.

> **Reminder (repo hard boundary).** Whoever works in this code, including an AI agent, **never runs SQL
> against any database**. The SQL on this page is shown so you can read and review it. ECD runs anything
> that touches data.

## 1. The write template

Every mutating coordinator method follows the same six-step template. Learn it once; every method below
is a variation.

```text
1. PERMISSION   ownerfile_verifyManagePermission(ua)                  (re-checked every time; never trust the bean)
2. FENCE        requireMuni(muni); the file must belong to that muni
3. RE-READ      load the CURRENT saved row from the database          (never trust the screen's copy)
4. VALIDATE     trim, length limits, "is this change still legal?"    (BObStatusException with a clerk-readable message)
5. WRITE        ONE transaction in the integrator:
                  a guarded UPDATE/INSERT  +  the log rows describing it
                check the row count; 0 means "someone else got there first" → refuse, write nothing
6. LOG SHAPE    logShape(...) prints one server-log line (ids and counts only)
```

Four ideas hide inside that template.

### Idea 1: the UI is untrusted

A browser can show a stale list (another clerk retired the file two minutes ago). So the coordinator
**re-reads** (step 3) and the SQL `WHERE` clause **asserts what the clerk saw** (step 5). If reality moved,
the guarded statement matches **zero rows**, the integrator returns `0`, and the coordinator throws "…was
retired or changed meanwhile. Reload the saved files."

### Idea 2: a change and its audit are inseparable

A change without a log row is an unaccountable change; a log row without a change is a lie. Both go in one
database transaction, so either both exist or neither does.

### Idea 3: optimistic concurrency, enforced by the database

There are no application-level locks. The pattern is **compare-and-swap in SQL**:

```sql
UPDATE … SET … WHERE <id matches> AND <the state I last saw still holds>
-- then:  if rowCount != 1 → somebody else changed it → roll back and refuse
```

This is called **optimistic** concurrency: assume no conflict, detect it cheaply if it happens. It is
correct even across two server nodes, because the database is the only arbiter.

### Idea 4: partial unique indexes as guard rails

`ownerfile_onefileperhead_uidx` (unique `(muni, head)` **where active**) makes "one active file per head"
a **database-enforced** rule. Code that violates it gets `0` rows (via `ON CONFLICT DO NOTHING`) instead of a
duplicate.

## 2. The writes at a glance

| Coordinator method | Writes to | Log operation(s) | Guard against races |
|---|---|---|---|
| `ownerfile_proposeFiles` | `ownerfile` INSERT (many) + log | `PROPOSED` | `ON CONFLICT (muni, head) WHERE deactivatedts IS NULL DO NOTHING` per file; one transaction |
| `ownerfile_createFile` | `ownerfile` INSERT + log | `CREATED_MANUALLY` | Same `ON CONFLICT`; also re-reads the graph first and refuses a head that already has a file |
| `ownerfile_updateFile` | `ownerfile` UPDATE + log | `TITLE_CHANGED`, `PAPER_REF_CHANGED`, `MAILTO_UPDATED`, `NAME_DECLARED` (only for real changes) | `WHERE ownerfileid = ? AND deactivatedts IS NULL AND (pointed-at link is still active)` |
| `ownerfile_assignMailtoAddress` | delegates to `ownerfile_updateFile` | `MAILTO_UPDATED` | as above; takes title/paper ref/name from the **saved** row so one click cannot overwrite them |
| `ownerfile_changeHead` | `ownerfile` UPDATE + log | `HEAD_CHANGED`, `TITLE_CHANGED` | `WHERE … head_humanid = <old> AND NOT EXISTS(other active file with new head) AND EXISTS(active new head human)` |
| `ownerfile_retire` | `ownerfile` UPDATE (soft delete) + log | `RETIRED` | `WHERE ownerfileid = ? AND deactivatedts IS NULL` |
| `ownerfile_lockForCycle` | log INSERT only | `LOCKED_FOR_CYCLE_MAILING` (+ JSON snapshot) | app-level check of the latest lock row; **no DB guard** (advisory) |
| `ownerfile_unlockForCycle` | log INSERT only | `UNLOCKED` (note required) | app-level check; no DB guard |
| `ownerfile_flagForReview` | log INSERT only | `REVIEW_FLAGGED` (`requiresreview = true`) | none needed (append-only) |
| `ownerfile_resolveReview` | log UPDATE (review cols) + log INSERT | `REVIEW_RESOLVED` | `WHERE ownerfilelogid = ? AND requiresreview AND reviewedts IS NULL` |
| `ownerfile_addParcelToGroup` | **`parcelparcelgroup` INSERT via `PropertyCoordinator`** + log | `PARCEL_ADDED_TO_GROUP` | **Not atomic** (two integrators); see §9 |
| `ownerfile_buildAuditSheet` | log INSERT only | `AUDIT_SHEET_PRINTED` | quiet writer (never throws) |
| `ownerfile_logLabelsPrinted` | log INSERT only | `LABELS_PRINTED` | in-memory `run.isLogged()`; quiet writer |

Everything the facility does to `public.*` tables is **one** call: `PropertyCoordinator.linkParcelToParcelGroup`
(the "add parcel to group" tool). The facility never writes link tables itself, which is why it can promise
that deriving is the only thing that reads the graph and the owner-link tables are untouched.

## 3. Factories: `ownerfile_getNewOwnerFile` (BB Rule 7)

```java
public OwnerFile ownerfile_getNewOwnerFile(Human head, Municipality muni, UserAuthorized ua)
        throws AuthorizationException, BObStatusException {
    ownerfile_verifyManagePermission(ua);
    requireMuni(muni);
    if (head == null || head.getHumanID() == 0 || head.getName() == null || head.getName().isBlank()) {
        throw new BObStatusException("A new owner file needs a head person with a name");
    }
    OwnerFile file = new OwnerFile();
    file.setMuniCode(muni.getMuniCode());
    file.setHead(head);
    file.setTitle(head.getName());          // default title = the head's name verbatim (Q-V3-20)
    file.setCreatedBy(ua);
    return file;
}
```

The repo rule (BB Rule 7): **a backing bean never does `new OwnerFile()`**. It asks the coordinator for a
pre-wired draft. The coordinator sets the required muni, head and default title, so a bean cannot forget a
required field, and the *defaulting rules live in one place*. Other factories:
`ownerfile_getNewOwnerFile(OwnerFileHeadCandidate, …)`, `ownerfile_getNewHeadChange`,
`ownerfile_getEditableCopy`, `ownerfile_getNewLabelOptions`. A factory writes nothing.

## 4. Saving proposals: `ownerfile_proposeFiles` and `insertOwnerFilesWithLogs`

### Coordinator side

```java
UUID batch = UUID.randomUUID();                                    // one id for the whole run
List<OwnerFile> newFiles = new ArrayList<>();
List<OwnerFileLog> logs = new ArrayList<>();
for (OwnerFileHeavy proposal : derivation.getFiles()) {
    if (proposal.getOwnerFileID() != 0) {                          // already saved: skip
        continue;
    }
    newFiles.add(ownerfile_getNewOwnerFile(proposal.getHead(), muni, ua));
    logs.add(newLog(proposal, OwnerFileLogOperation.PROPOSED, null, ua, batch,
            "Proposed from the derivation over parcel group '" + groupName + "'",
            describeForLog(proposal)));
}
…
for (Integer id : getOwnerFileIntegrator().insertOwnerFilesWithLogs(newFiles, logs)) { if (id != 0) created++; … }
```

Notes:

- The derivation is **only a proposal source**: the saved file keeps *just* muni, head and title. The parcels
  and members the clerk saw are not stored; they will be re-derived.
- `describeForLog(proposal)` stores "head=…; parcels=N; members=M; mailto=…; flags=…" in `technicaldetails`:
  a **text snapshot of the file's state at that moment**, which is what makes the log useful for later audit.
- The `batch` UUID ties every row of this save together (`batchsessionid`).
- Derivation muni must match: `derivation.getMuniCode() != muni.getMuniCode()` is refused so a stale list from
  another muni cannot be saved here.

### Integrator side

```java
String fileSql = """
        INSERT INTO workflow.ownerfile (muni_municode, head_humanid, title, createdby_userid)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (muni_municode, head_humanid) WHERE deactivatedts IS NULL DO NOTHING
        RETURNING ownerfileid
        """;
…
con = getPostgresCon();
con.setAutoCommit(false);                           // BEGIN
fileStmt = con.prepareStatement(fileSql);
logStmt  = con.prepareStatement(LOG_INSERT_SQL);
for (int i = 0; i < files.size(); i++) {
    …bind and run the INSERT...
    rs = fileStmt.executeQuery();
    int newID = rs.next() ? rs.getInt(1) : 0;       // RETURNING gives a row only if the insert happened
    ids.add(newID);
    if (newID != 0) {
        OwnerFileLog log = logs.get(i);
        log.setOwnerFileID(newID);                  // the log row learns its file id only now
        bindLog(logStmt, log);
        logStmt.addBatch();
    }
}
logStmt.executeBatch();
con.commit();                                       // COMMIT: files and logs together
```

Dissection:

- **`ON CONFLICT (muni_municode, head_humanid) WHERE deactivatedts IS NULL DO NOTHING`** names the partial
  unique index as the conflict target. If the head already has an active file, **the INSERT silently does
  nothing and `RETURNING` produces no row.** That is why the method returns `0` for that file, and why
  *clicking Save twice writes nothing the second time* (idempotency).
- **`RETURNING ownerfileid`** is how the code learns the new primary key without a second query. The returned
  id is attached to the matching log row, which is why the two lists must be the **same length and order**
  (the method throws if they are not paired).
- A skipped file also skips its log row (`if (newID != 0)`).
- **`setAutoCommit(false)` … `commit()`** turns the whole loop into one transaction. If anything throws, the
  catch block calls `rollbackQuietly` and nothing is written. The `finally` restores autocommit and closes
  the statements and connection.

### The transaction plumbing

```java
} catch (SQLException ex) {
    rollbackQuietly(con, "insertOwnerFilesWithLogs");
    throw new IntegrationException("OwnerFileIntegrator.insertOwnerFilesWithLogs | " + ex.getMessage(), ex);
} finally {
    restoreAutoCommitQuietly(con, "insertOwnerFilesWithLogs");   // pooled connections must be handed back in autocommit mode
    closeQuietly(rs, fileStmt, logStmt, con);                    // con.close() returns it to the pool
}
```

"Quietly" helpers print to stderr instead of throwing, because a failure *while cleaning up* must not mask
the original error. **Every multi-statement write in this integrator is wrapped exactly like this**; copy the
pattern when you add one.

## 5. The log row: `newLog`, `bindLog`, `LOG_INSERT_SQL`

```java
private OwnerFileLog newLog(OwnerFileHeavy file, OwnerFileLogOperation operation, String cycle, UserAuthorized ua,
        UUID batch, String description, String technicalDetails) {
    OwnerFileLog log = new OwnerFileLog();
    log.setOwnerFileID(file.getOwnerFileID());
    log.setMuniCode(file.getMuniCode());
    log.setOperation(operation);
    log.setRentalCycle(cycle);
    log.setLoggingUser(ua);
    log.setOperationDescription(description);
    log.setTechnicalDetails(technicalDetails);
    log.setHumanID(file.getHead().getHumanID());
    log.setSeverity(OwnerFileSeverity.INFO);
    log.setBatchSessionID(batch);
    log.setRequiresReview(operation.isDefaultRequiresReview());   // only REVIEW_FLAGGED starts "needs review"
    return log;
}
```

Every log row is born through this one factory, so every row carries the same minimum: file, muni,
operation, user, head, severity, batch. The *operation-specific* extras are then added by the caller
(`log.setNotes`, `log.setDataPayload`, `log.setHumanMailingAddressLinkID`, …).

`bindLog` maps that object to the 21-parameter `LOG_INSERT_SQL`:

```java
private void bindLog(PreparedStatement stmt, OwnerFileLog log) throws SQLException {
    if (log.getOperation() == null || log.getLoggingUser() == null || log.getOwnerFileID() == 0) {
        throw new SQLException("a log row needs a file number, an operation and a logging user");
    }
    …
    setNullableInt(stmt, i++, log.getHumanID());              // 0 in Java  →  NULL in SQL
    …
    stmt.setBoolean(i++, log.isRequiresReview());
    stmt.setString(i++, log.getReviewReason());
    if (log.getReviewFlaggedTS() != null) {                    // review-flagged timestamp filled automatically
        stmt.setTimestamp(i++, Timestamp.valueOf(log.getReviewFlaggedTS()));
    } else if (log.isRequiresReview()) {
        stmt.setTimestamp(i++, Timestamp.valueOf(java.time.LocalDateTime.now()));
    } else {
        stmt.setNull(i++, java.sql.Types.TIMESTAMP);
    }
    …
}
```

Three conventions to remember:

1. **`0` = "not set" in Java, `NULL` in SQL.** `setNullableInt` does the conversion. The six "soft" link
   columns (`human_humanid`, `parcel_parcelkey`, `humanparcel_linkid`, …) are almost always NULL; they are
   filled only when a row is *about* a specific link.
2. **The 21 placeholders are positional.** Adding a log column means touching the `INSERT` column list, the
   `VALUES (?, ?, …)` count, **and** `bindLog` in the same order.
3. **A row that cannot identify its file, operation or user is refused** by `bindLog` before it reaches the
   database.

## 6. Editing declared state: `ownerfile_updateFile`

This is the best example of "**diff, then write only what changed**".

```java
OwnerFileHeavy current = ofi.getActiveOwnerFile(edited.getOwnerFileID());          // RE-READ
if (current == null) { throw new BObStatusException("File … is retired or no longer exists"); }
if (current.getMuniCode() != muni.getMuniCode()) { throw … }

String title = trimToNull(edited.getTitle());                                      // VALIDATE
if (title == null) { throw new BObStatusException("A file needs a title"); }
requireDeclaredTextLength("Title", title);                                         // 200-char limit
…
OwnerFileAddressCandidate pick = findPickedCandidate(edited);                      // picked address must be one of THIS file's candidates
int newHumanLinkID  = pick != null && pick.isHumanLink()  ? pick.getAddress().getLinkID() : 0;
int newParcelLinkID = pick != null && !pick.isHumanLink() ? pick.getAddress().getLinkID() : 0;

List<OwnerFileLog> logs = new ArrayList<>();
if (!Objects.equals(title, current.getTitle())) {
    logs.add(newLog(current, OwnerFileLogOperation.TITLE_CHANGED, …, "old=" + oldTitle + "; new=" + title));
}
… PAPER_REF_CHANGED, MAILTO_UPDATED, NAME_DECLARED (each only if different from `current`) …
if (logs.isEmpty()) { logShape(… "writes nothing"); return 0; }                    // nothing changed → nothing written
```

**Why compare against `current` and not against the edited copy's original values?** Because the *copy the
clerk held* may be stale. Diffing against a fresh read means the audit rows describe the **true** before and
after, and "nothing differs" is detected correctly even if a colleague already made the same change.

The pointer columns are written **exactly as given** (`0` clears them) so the caller passes the *full intended
state*. Then the integrator:

```sql
UPDATE workflow.ownerfile
   SET title = ?, canonicalname = ?, paperfileref = ?,
       humanmailingaddress_linkid = ?, parcelmailingaddress_linkid = ?,
       lastupdatedts = now(), lastupdatedby_userid = ?
 WHERE ownerfileid = ? AND deactivatedts IS NULL
   AND (?::integer IS NULL OR EXISTS (SELECT 1 FROM public.humanmailingaddress
                                       WHERE linkid = ?::integer AND deactivatedts IS NULL))
   AND (?::integer IS NULL OR EXISTS (SELECT 1 FROM public.parcelmailingaddress
                                       WHERE linkid = ?::integer AND deactivatedts IS NULL))
```

Reading the `WHERE`:

- `ownerfileid = ? AND deactivatedts IS NULL` → the file still exists and is active.
- `(? IS NULL OR EXISTS(… link is still active …))` → **if a pointer is being set, the link it points at must
  still be active *at the instant of the write***. This closes the race "I picked an address, a colleague
  retired that link, I clicked Save". The `?::integer` cast is needed because Postgres cannot infer the type
  of a bare `NULL` parameter.
- Note each pointer value is **bound twice** (`IS NULL` test and the `linkid =` test). That is why you see
  `setNullableInt(…)` called twice per pointer in a row.
- **If zero rows match, the transaction is rolled back before any log row is written** and the method returns
  `0`; the coordinator turns that into the "retired meanwhile, derive again" message.

The database also has `ownerfile_oneaddresslink_chk` (at most one pointer); the coordinator guarantees it by
construction (a pick is either a human link or a parcel link), and the CHECK is the backstop.

**Mail-to name vs address.** The name override (`canonicalname`) works whether or not an address is declared.
`mailto_humanid` is not touched (reserved column).

## 7. Changing the head: optimistic concurrency at its sharpest

```sql
UPDATE workflow.ownerfile f
   SET head_humanid = ?, title = ?, lastupdatedts = now(), lastupdatedby_userid = ?
 WHERE f.ownerfileid = ? AND f.deactivatedts IS NULL AND f.head_humanid = ?                 -- (a)
   AND NOT EXISTS (SELECT 1 FROM workflow.ownerfile o
                    WHERE o.muni_municode = f.muni_municode AND o.head_humanid = ? AND o.deactivatedts IS NULL)   -- (b)
   AND EXISTS (SELECT 1 FROM public.human h WHERE h.humanid = ? AND h.deactivatedts IS NULL)                     -- (c)
```

Each clause defends one invariant:

| Clause | Means | Protects against |
|---|---|---|
| (a) `head_humanid = <expectedOld>` | "the file still has the head the clerk saw" | two clerks changing the head at once; the second sees the first's result and is refused |
| (b) `NOT EXISTS …` | "the new head does not already head another **active** file in this muni" | duplicate files per head (the unique index is the final judge if two clerks race *between* this check and the write) |
| (c) `EXISTS … human active` | "the new head is a real, active person" | pointing a file at a deactivated person |

The coordinator re-checks (a) and the "already heads a file" part of (b) in Java **first** (in
`ownerfile_changeHead` and `ownerfile_getNewHeadChange`) for friendlier messages ("That person already heads
file 7. A person heads at most one active file per municipality: merge the duplicate people or retire that
file first."), but the **SQL is the real guard**, and (c) is enforced **only** in the SQL. Only the SQL is
race-proof.

Two log rows are written in the same transaction: `HEAD_CHANGED` (with `oldHead`, `newHead` in
`technicaldetails`, the clerk's reason in `notes`) and, if the title followed the head, `TITLE_CHANGED`. The
**title follows the head only when it was still the old head's name verbatim** (the default); a title a
clerk edited is left alone. **The declared mail-to name and address are kept** across a head change, because
they are the clerk's declarations about the file; the success message tells the clerk to re-check them.

## 8. Retiring, locking, unlocking, reviewing

### Retire: a soft delete

```sql
UPDATE workflow.ownerfile
   SET deactivatedts = now(), deactivatedby_userid = ?, lastupdatedts = now(), lastupdatedby_userid = ?
 WHERE ownerfileid = ? AND deactivatedts IS NULL
```

No row is ever deleted. `deactivatedts IS NULL` is the universal "active" test, so retiring a file frees
its head (the partial unique index stops covering it) and the file vanishes from every active read. Its log
rows stay; pending-review rows on a retired file **still appear** in the pending list ("a flag raised on a
file is still a flag after the file is retired"). If the head is still derived from the group, the next
group-seeded derivation proposes it again as an *unsaved* file.

### Lock and unlock: events in the log, not state in the file

```java
// ownerfile_lockForCycle (abridged)
OwnerFileHeavy saved = requireSavedActiveFile(file, muni, ua);       // permission + saved + same muni + still active
String cycle = requireCycle(rentalCycle);                            // required, ≤ 60 chars
if (ofi.getLatestLockOperation(saved.getOwnerFileID(), cycle) == OwnerFileLogOperation.LOCKED_FOR_CYCLE_MAILING) {
    throw new BObStatusException("File … is already locked for the cycle …");
}
OwnerFileHeavy fresh = ownerfile_getLinkGraph(saved.getHead(), muni, null, ua);     // RE-DERIVE now, not from the screen
OwnerFileLog log = newLog(fresh, OwnerFileLogOperation.LOCKED_FOR_CYCLE_MAILING, cycle, ua, UUID.randomUUID(),
        "Locked for the " + cycle + " mailing", describeForLog(fresh));
log.setNotes(trimmedNote);
log.setDataPayload(lockSnapshot(fresh, cycle));                      // the JSON snapshot
ofi.insertOwnerFileLogBatch(List.of(log));
```

Design points:

- **A lock is a log row.** "Locked for cycle X" is derived as "the latest of {LOCKED, UNLOCKED} for (file, X)".
  There is no status column to keep consistent.
- **The snapshot is re-derived at lock time**, not copied from what the clerk was looking at, because it is
  "*the* record of what was mailed" (§V3.5.2).
- **Locks are advisory** (Q-V3-21): nothing is blocked. The UI shows a badge and warns on edit.
- **Unlock requires a note** (the only *lock* operation that does) and is refused if the file is not locked for
  that cycle.
- **There is no database guard** against two clerks locking at the same instant: the "already locked" check
  is a read followed by an insert (check-then-act). The worst case is two `LOCKED…` rows for the same
  file and cycle, which is harmless because **latest wins**. If you ever *enforce* locks, this must become a
  guarded write.

The snapshot (`lockSnapshot`) is flat JSON built by hand:

```json
{ "ownerFileId": 1, "title": "WANG LANG", "rentalCycle": "2026-2029", "headHumanId": 5001,
  "mailtoName": "WANG LANG", "mailtoProvenance": "HEAD_SINGLE_ADDRESS",
  "declaredHumanLinkId": 0, "declaredParcelLinkId": 0,
  "address": { "addressId": 321, "linkKind": "humanmailingaddress", "linkId": 4410, "oneLine": "…" },
  "labelLines": ["WANG LANG", "100 ELM ST", "…"],
  "members": [ { "humanId": 5002, "name": "…LLC", "controlLinkId": 80001 } ],
  "parcels": [ { "parcelKey": 9001, "parcelId": "0123-A-00100", "ownerHumanId": 5001,
                 "humanParcelLinkId": 70001, "viaEntity": false }, … ] }
```

It is hand-written (`jsonString` escapes quotes, backslashes and control characters) because, in the
author's build, `ObjectMapper.writeValueAsString` threw `NoSuchMethodError` from a jackson-databind (2.17.1)
vs jackson-core (2.15.2) mismatch. **Do not "simplify" this to Jackson without checking the deployed WAR's
dependency versions.**

### Review: flag, then resolve

```java
// flag: append one row that starts life "needs review"
OwnerFileLog log = newLog(saved, OwnerFileLogOperation.REVIEW_FLAGGED, null, ua, UUID.randomUUID(), "Flagged for review", describeForLog(saved));
log.setReviewReason(trimmedReason);
log.setSeverity(OwnerFileSeverity.WARNING);
getOwnerFileIntegrator().insertOwnerFileLogBatch(List.of(log));
```

```sql
-- resolve: the ONLY UPDATE a log row ever gets
UPDATE workflow.ownerfilelog
   SET reviewedby_userid = ?, reviewedts = now(), reviewoutcome = ?, reviewnotes = ?
 WHERE ownerfilelogid = ? AND requiresreview AND reviewedts IS NULL
```

…followed, in the same transaction, by an `INSERT` of a `REVIEW_RESOLVED` row. The `WHERE … reviewedts IS
NULL` means a row two reviewers click at once is resolved **once**; the loser gets 0 rows and the message
"That review was already resolved. Reload the pending list." The outcome is an enum
(`OwnerFileReviewOutcome`: `RESOLVED`, `NO_ACTION_NEEDED`, `DEFERRED`, `DEV`, `CUSTOM`).
The review **flag lives only on the log row** (R-6): it never changes the file.

## 9. The one non-atomic write: `ownerfile_addParcelToGroup`

```java
pc.linkParcelToParcelGroup(prop, target, ua);          // write #1: PropertyCoordinator → PropertyIntegrator (parcelparcelgroup)
…
return writeLogsQuietly(List.of(log), "ownerfile_addParcelToGroup");   // write #2: OwnerFileIntegrator (log row)
```

Two different integrators use two different connections, so these cannot share a transaction. The order is
deliberate: **do the real change first, then log it**, so the log can never claim a change that did not
happen. The cost is that a log failure leaves a change without its row; the method returns `false` in that
case and the bean tells the clerk. Before writing, it refuses a parcel not in the file, a group not in the
muni, and a parcel **already in the group**.

## 10. Logs that no mutation depends on: the "quiet" writer

Printing an audit list or downloading label PDFs produces log rows (`AUDIT_SHEET_PRINTED`,
`LABELS_PRINTED`), but a logging failure must **never stop the printout**.

```java
private boolean writeLogsQuietly(List<OwnerFileLog> logs, String where) {
    if (logs.isEmpty()) { …; return true; }
    try {
        getOwnerFileIntegrator().insertOwnerFileLogBatch(logs);
        … logShape(where, "… CREATE n ownerfilelog rows {OPERATION=n} cycle=… | run=…");
        return true;
    } catch (IntegrationException ex) {
        System.err.println(where + " | owner file log not written: " + ex.getMessage());
        return false;
    }
}
```

It follows the house rule "**logging methods never throw**: catch, print to stderr, tally." The UI then shows
"could not be written". Contrast with rule 3 on the orientation page: the log row for a **mutation** is *not*
quiet; it is in the transaction.

Two decisions about *when* these rows are written:

- `AUDIT_SHEET_PRINTED`: one row per **saved** file each time the audit page is **generated**
  (reloading the page is a new run and writes again, per Q-V3-16). Unsaved proposals have no file to log
  against and are skipped.
- `LABELS_PRINTED`: at **PDF download**, once per run (`run.isLogged()` flips to true), because "which
  label went to which address" should mean the PDF that actually left, not every preview while offsets were
  tuned.

## 11. Races: what happens when two clerks collide

| Scenario | What stops it | What the loser sees |
|---|---|---|
| Two clerks click **Save proposals** at once | `ON CONFLICT … DO NOTHING` per head; unique index | The second run's `created` count is lower; skipped heads are reported |
| Two clerks **create a file for the same person** | Coordinator pre-check, then the same `ON CONFLICT` | "That person was given a file by someone else a moment ago. Reload the saved files." |
| Clerk A edits while clerk B **retires** the file | `WHERE … deactivatedts IS NULL` → 0 rows | "File N was not saved: it was retired, or the chosen address link was retired, while you were editing." |
| Clerk A **picks an address** whose link is deactivated before Save | `EXISTS (link active)` in the `UPDATE` | same message as above |
| Two clerks **change the head** of one file | `head_humanid = <old>` | "…was given a different head while you were choosing. Reload…" (Java) or the generic refusal (SQL) |
| Two clerks **resolve the same review** | `reviewedts IS NULL` | "That review was already resolved." |
| Two clerks **lock** the same file and cycle | *nothing in the database* | Both succeed (two lock rows). Harmless; latest wins |
| A **link edit** by someone else changes what a file contains | Nothing needed: files are derived | The next read shows the new truth. A *locked* file still holds its snapshot |

## 12. Read-only verification queries (for ECD to run)

The agent never runs these. They come from the spec's gates and from reading the code; adapt `:fileid`.

```sql
-- Did a save write one folder row and one PROPOSED row per file, one batch?
SELECT f.ownerfileid, f.head_humanid, f.title, l.operation, l.batchsessionid
  FROM workflow.ownerfile f JOIN workflow.ownerfilelog l ON l.ownerfile_ownerfileid = f.ownerfileid
 WHERE f.muni_municode = 852 ORDER BY f.ownerfileid, l.entrytimestamp;

-- Is the one-active-file-per-head invariant holding? (expect zero rows)
SELECT muni_municode, head_humanid, count(*) FROM workflow.ownerfile
 WHERE deactivatedts IS NULL GROUP BY 1, 2 HAVING count(*) > 1;

-- A file's whole history, newest first
SELECT operation, rentalcycle, operationdescription, technicaldetails, notes, entrytimestamp, batchsessionid
  FROM workflow.ownerfilelog WHERE ownerfile_ownerfileid = :fileid ORDER BY entrytimestamp DESC, ownerfilelogid DESC;

-- Current lock state per file and cycle (what the panel's "Cycle lock" column derives)
SELECT DISTINCT ON (ownerfile_ownerfileid, rentalcycle) ownerfile_ownerfileid, rentalcycle, operation, entrytimestamp
  FROM workflow.ownerfilelog WHERE operation IN ('LOCKED_FOR_CYCLE_MAILING','UNLOCKED') AND rentalcycle IS NOT NULL
 ORDER BY ownerfile_ownerfileid, rentalcycle, entrytimestamp DESC, ownerfilelogid DESC;

-- Pending review queue
SELECT ownerfilelogid, ownerfile_ownerfileid, reviewreason, reviewflaggedts
  FROM workflow.ownerfilelog WHERE requiresreview AND reviewedts IS NULL ORDER BY reviewflaggedts DESC;

-- Files whose declared address pointer now points at a deactivated link (the DECLARED_LINK_DEACTIVATED population)
SELECT f.ownerfileid, f.title FROM workflow.ownerfile f
  JOIN public.humanmailingaddress h ON h.linkid = f.humanmailingaddress_linkid
 WHERE f.deactivatedts IS NULL AND h.deactivatedts IS NOT NULL;
```

## 13. Gotchas on the write path

1. **A write method that forgets the `rowCount` check silently succeeds on a lost race.** Always compare
   `executeUpdate()` to `1` and roll back otherwise.
2. **Log rows must be built from a fresh read** (`current`, `fresh`), not from the bean's list, or the audit
   trail records what the screen thought, not what the database held.
3. **Never add a write that bypasses `bindLog`/`newLog`.** The consistent minimum columns are what make the
   log queryable.
4. **Never `UPDATE`/`DELETE` a log row except `resolveOwnerFileLogReview`.** If a historic row is wrong, add
   a `NOTE` row.
5. **Do not add `deactivatedts` to `ownerfilelog`.** Its absence is the point of the table (write-only).
6. **The text columns `operation`, `seedkind`, `controllerside` are open-ended TEXT.** Adding an enum value
   needs no DDL, but renaming one **orphans historic rows** (the reader returns `null` for the unknown text).
   Never rename an `OwnerFileLogOperation` constant; add a new one.
7. **Transactions hold a connection.** Keep the code between `setAutoCommit(false)` and `commit()` short:
   no UI work, no derivations, no network calls.
8. **Keep the server log free of personal data.** `logShape` messages carry ids, counts and operation names
   only.
9. **The isolation of "one transaction per change" rests on `getPostgresCon()` handing each call its own
   connection.** That method stores the connection in a *shared field* of the base class before returning it,
   so under a rare interleaving two threads could receive the same `Connection` (and interleave `commit`s).
   It is an observation from reading the code, not a reproduced failure, and it applies to every integrator,
   not just this one; see
   [deriver vs coordinator §6.3](/dev/subsystems/workflow-builder/owner-files-deriver-vs-coordinator). Do not
   copy that pattern into new code: keep connections and sessions in **local variables**.
