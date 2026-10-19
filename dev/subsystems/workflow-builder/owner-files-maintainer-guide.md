---
title: Owner Files — Maintainer Guide
description: Runbook and playbook for the engineer who owns the owner-file facility — configuring seed roles (with a worked LOR 2203 example), troubleshooting, safe-change recipes, verification, and practice exercises
published: false
date: 2026-10-19T13:15:00.000Z
tags: subsystem:workflow-builder, audience:dev, type:runbook
editor: markdown
dateCreated: 2026-10-19T13:15:00.000Z
---

# Owner Files — Maintainer Guide

This is the "**what do I do**" page. Read the other eight first:
[orientation](/dev/subsystems/workflow-builder/owner-files-orientation),
[data model](/dev/subsystems/workflow-builder/owner-files-data-model),
[Java class design primer](/dev/subsystems/workflow-builder/owner-files-java-class-design-primer),
[deriver vs coordinator](/dev/subsystems/workflow-builder/owner-files-deriver-vs-coordinator),
[derivation theory](/dev/subsystems/workflow-builder/owner-files-derivation-theory),
[read path](/dev/subsystems/workflow-builder/owner-files-read-path-code),
[write path](/dev/subsystems/workflow-builder/owner-files-write-path-code),
[reverse lookup](/dev/subsystems/workflow-builder/owner-files-membership-lookup).

> **Hard boundary (repo rule).** The SQL on this page is **for ECD to review and run**. An AI agent or any
> tool-assisted session writes it as *text* and **never executes it** or goes looking for database
> credentials. Git commits, pushes and deploys are also ECD's.

## 1. Runbook: configure the seed roles

The seed table (`workflow.ownerfileseedlor`) decides **which links the graph walk follows**. There is no
admin UI for it yet (backlog R-20); you maintain it with SQL. The only Java that reads it is
`OwnerFileIntegrator.getSeedLorList`, and nothing is cached, so **a change takes effect on the next
derive**.

### 1.1 When you need this

| Symptom | Likely seed problem |
|---|---|
| Panel says "No owner role is seeded…" | No active `OWNS_PARCEL` row |
| Panel says "No control role is seeded…" and LLCs have their own files | No active `CONTROLS_HUMAN` row (for example a dev database lacking production's LOR 2205) |
| LLCs *do not fold* even though a seed exists | The seed's LOR is not the one your `humanhuman` rows use, or `controllerside` is backwards (§1.4) |
| Setup problem "Seed row N … kind this version does not recognise" | A typo in `seedkind` |

### 1.2 Look at what exists (read-only)

```sql
-- the active seeds, with what each LOR is
SELECT s.seedlorid, s.muni_municode, s.linkedobjectrole_lorid, lor.title, lor.lorschema,
       s.seedkind, s.controllerside, s.notes
  FROM workflow.ownerfileseedlor s
  JOIN public.linkedobjectrole lor ON lor.lorid = s.linkedobjectrole_lorid
 WHERE s.deactivatedts IS NULL
 ORDER BY s.seedkind, s.linkedobjectrole_lorid;

-- (P-1) every HumanHuman role in the database: pick the "controls" one from here
SELECT lorid, title, description, sortorder
  FROM public.linkedobjectrole
 WHERE lorschema::text = 'HumanHuman' AND deactivatedts IS NULL
 ORDER BY title;
```

**LOR ids are per-database.** Production's "Owner of Business" is **2205** in ECD's notes; a dev database
may number the same role differently or lack it. Never copy an id between databases without checking
`title` and `lorschema`.

### 1.3 Worked example: make LOR 2203 the control role on a dev database

Goal: on dev, make **LOR 2203** the `HumanHuman` role through which a head person's file *folds in* the
entities they control (the "transitive ownership" behaviour that production gets from 2205).

**The column values to use:**

| Column | Value | Why |
|---|---|---|
| `seedlorid` | *(omit)* | `SERIAL` fills it |
| `muni_municode` | `NULL` | Config scope. `HumanHuman` links are global (R-20), and production's 2205 row is `NULL`. Use a municode only to limit the seed to one muni |
| `linkedobjectrole_lorid` | `2203` | Must already exist (FK). Must have `lorschema = 'HumanHuman'` |
| `seedkind` | `'CONTROLS_HUMAN'` | Exactly this text; anything else is ignored with a setup problem |
| `controllerside` | `'SOURCE'` *or* `'TARGET'` | **Required** for `CONTROLS_HUMAN` (CHECK). See §1.4 |
| `notes` | provenance text | Optional but kind to the next reader |
| `createdts` | *(omit)* | defaults to `now()` |
| `createdby_userid` | `NULL`, or your `login.userid` | The patch seeds leave it `NULL` |
| `deactivatedts`, `deactivatedby_userid` | `NULL` | `NULL` = active |

**Step 1 — confirm what 2203 is** (read-only):

```sql
SELECT lorid, title, description, lorschema, deactivatedts
  FROM public.linkedobjectrole WHERE lorid = 2203;
```

Expect `lorschema = HumanHuman`. If it is something else, stop: that is the wrong LOR.

**Step 2 — decide the direction from the data** (§1.4), using real rows:

```sql
SELECT hh.linkid,
       hh.human_humanid        AS source_id, s.name AS source_name, s.businessentity AS src_biz,
       hh.humantarget_humanid  AS target_id, t.name AS target_name, t.businessentity AS tgt_biz
  FROM public.humanhuman hh
  JOIN public.human s ON s.humanid = hh.human_humanid
  JOIN public.human t ON t.humanid = hh.humantarget_humanid
 WHERE hh.linkedobjectrole_lorid = 2203 AND hh.deactivatedts IS NULL AND hh.archivedts IS NULL
 LIMIT 20;
```

**Step 3 — insert** (the **guarded** form the patch uses, so it inserts nothing if 2203 is missing or the
wrong schema; shown for `SOURCE`; swap in `'TARGET'` if Step 2 says so):

```sql
INSERT INTO workflow.ownerfileseedlor
       (muni_municode, linkedobjectrole_lorid, seedkind, controllerside, notes)
SELECT NULL, lor.lorid, 'CONTROLS_HUMAN', 'SOURCE',
       'dev stand-in for production 2205: source person controls target entity'
  FROM public.linkedobjectrole lor
 WHERE lor.lorid = 2203 AND lor.lorschema::text = 'HumanHuman'
ON CONFLICT DO NOTHING;
```

`ON CONFLICT DO NOTHING` (no target) absorbs a violation of the partial unique index
`ownerfileseedlor_active_uidx` (one active row per muni-or-all, LOR, kind), so re-running is harmless.

**Step 4 — verify** (§1.5).

### 1.4 Deciding `SOURCE` vs `TARGET`

A `humanhuman` row reads **"`human_humanid` is ⟨role title⟩ `humantarget_humanid`"**. Ask: *in the sentence
the role title makes, who is the controller?*

| The role reads like… | Sentence | `controllerside` |
|---|---|---|
| "Owner of", "Principal of", "Officer of" | "Wang Lang **is Owner Of** Three Rivers LLC" | `SOURCE` |
| "Owned By", "Controlled By", "Subsidiary of" | "Three Rivers LLC **is Owned By** Wang Lang" | `TARGET` |

Use the Step 2 probe as evidence: if the business entity (`businessentity = true`, noting that flag is
unreliable) is mostly the **target**, the **source** is the controller → `SOURCE`. If the business entity
is mostly the **source** → `TARGET`. Prefer reading actual names over trusting a flag.

> **A wrong side does not raise an error.** It silently produces no folding (or folds the wrong way): see
> exercise 3 in §8. If LLCs are not folding, check this first.

### 1.5 Verify the seed took effect

1. Re-run the §1.2 seeds `SELECT`; your row is present and active.
2. In the app, **Reload saved files** (or re-open the Rental registry manager). The "No control role is
   seeded" message should be gone.
3. Open **linked objects** for a head who you know controls an LLC. You should see the LLC as a member
   with its control link and parcels.
4. If not, use the troubleshooting table (§2).

### 1.6 Changing or retiring a seed

- **Retire**: `UPDATE workflow.ownerfileseedlor SET deactivatedts = now(), deactivatedby_userid = :userid WHERE seedlorid = :id;`
  (Never `DELETE`: the repo prefers soft deactivation.)
- **Change the direction**: deactivate the row and insert a new one (so the history shows the correction),
  rather than editing `controllerside` in place. The CHECK constraints still apply to the new row.
- **Scope to one municipality**: put the municode in `muni_municode`. A `NULL` row and a muni row for the
  *same* LOR and kind can coexist (the unique index keys on `COALESCE(muni_municode, 0)`), but then both
  apply to that muni; avoid duplicates. **If their `controllerside` values differ, the later row (higher
  `seedlorid`) silently wins** (the side is stored in a map keyed by LOR id, filled in row order).
- **Adding an ownership role**: `seedkind = 'OWNS_PARCEL'` (or `'OWNER_OCCUPANT'`) for a **`ParcelHuman`** LOR,
  `controllerside` **NULL** (a non-null side on a non-control kind violates the CHECK).
- **Never insert a `linkedobjectrole` row to make a seed work.** Roles are ECD-approved data (R-32).

## 2. Troubleshooting table

Always check the **setup problems** shown at the top of the panel first; they report seed gaps in plain
words.

| Symptom | Likely cause | Where to look |
|---|---|---|
| "No owner role is seeded" | No active `OWNS_PARCEL` seed row (dev DB lacks LOR 116?) | §1.2; patch 104 s3 |
| LLC has its own file; head's file lacks the LLC | No control seed, or the control **LOR in the data differs** from the seeded one | `SELECT DISTINCT linkedobjectrole_lorid FROM humanhuman` near that head vs the seed table |
| Nothing folds, no error | `controllerside` backwards (§1.4), or the control link is **deactivated/archived** | the Step 2 probe; the link's `deactivatedts`/`archivedts` |
| LLC not in any file, head has `CONTROLLED_ENTITY_NOT_FOLDED` | The LLC has **2+ controllers** (rule F2) | `controllersOf` = distinct controllers via the seeded role |
| LLC's parcels missing from the head's file but no flag | The LLC is **depth 2** (controlled by a non-head entity): silently ignored (theory example D) | follow `humanhuman` one more hop |
| LLC's parcels missing | The LLC owns via a **non-seeded role** (e.g. 103 "owns", not 116/119), or its `humanparcel` link is ended (`validto` passed) / archived | `humanparcel` rows for the LLC |
| Parcel appears in the exception list ("no owner") | The group parcel has no active seeded owner link | D5 query; the link's role / dates |
| `NO_CURRENT_PARCELS` | The head sold everything, or was merged into another person | `humanparcel` for the head; retire the file |
| Two files for one real owner | Duplicate `human` rows | `SAME_MAILTO_AS_OTHER_FILE`; use the person merge tool, then retire the emptied file |
| `NO_MAILTO_ADDRESS` | Head has no active non-hidden (`priority >= 0`) human address link and no role-233 parcel link | `humanmailingaddress` rows; `parcelmailingaddress` role 233 |
| `MAILTO_HEAD_ADDRESSES_DIFFER` | Head has 2+ distinct addresses | clerk picks one ("assign for mailing") |
| `DECLARED_LINK_DEACTIVATED` | The pointed-at address link was retired | edit the file; clear or re-pick |
| "Save proposals" saved fewer than offered | Some heads already have an active file (idempotent skip) | `ownerfile_onefileperhead_uidx` |
| "Change head" refused | New head already heads an active file, is inactive, or the file changed meanwhile | message text |
| Lock badge does not show | The **rental cycle text must match exactly** (`2026-2029` ≠ `2026–2029`) | the cycle box vs `ownerfilelog.rentalcycle` |
| Badge missing on a profile | Parcel's muni ≠ session muni; no owner link; no saved file for any candidate head; or the lookup **failed** (stderr line `getManagedOwnerFileMemberships \|`) | server log |
| Label missing for a file | Label exception: no address, line too wide, too many lines, or a character the font cannot print | the exception report |
| A flag you expect is absent in "linked objects" | **Cross-file flags need the whole list** | the saved-files table |
| Everything is slow | See the [scaling review](/dev/subsystems/workflow-builder/owner-files-membership-lookup) §8: `EXPLAIN` the two-hop edge query first | `EXPLAIN (ANALYZE, BUFFERS)` |

### Reading the server log

Every coordinator write and every derivation prints one line:

```text
OwnerFileCoordinator.ownerfile_updateFile | user=17 | file=3 muni=852 | UPDATE ownerfile + 2 log rows [TITLE_CHANGED,MAILTO_UPDATED] humanLink none->4410 parcelLink none->none | run=3f1c…
OwnerFileCoordinator.ownerfile_deriveSaved | user=17 | muni=852 | READ derived files=41 (saved=41, unsaved=0) foldedEntities=12 ownerlessGroupParcels=0 setupProblems=0 | writes nothing
```

Lines carry **ids and counts only**. Refusals say `writes nothing`. A transaction rollback prints
`OwnerFileIntegrator.<method> | transaction rolled back` to **stderr**.

## 3. Safe-change recipes

Each recipe lists the files to touch and the traps. **Every recipe ends the same way:** `mvn clean package
-DskipTests` (never piped through `grep`/`tail`), the violation greps in §5, and a manual check by ECD.

### A. Add a flag

1. Add the constant to `OwnerFileFlag` (severity, label, description). **No DDL** (flags are never stored).
2. Raise it with `raise(f, OwnerFileFlag.X, detail)` in `OwnerFileDeriver`: in the per-file group
   (`assembleFile` and its helpers) **or** the cross-file pass (needs the whole list).
3. If it needs data the deriver does not have, add a field to `OwnerFileDeriver.Input`, fill it in
   `readSupportRows` / `deriveFromHeads`, and add the integrator read.
4. Decide whether the **reverse lookup** needs it (usually not: it discards flags).
5. Update the data-model and theory pages and the staff page that lists flags.

Trap: `raise()` is once-per-flag; a flag with a *detail* that differs between occurrences will show only
the first.

### B. Add a log operation

1. Add the constant to `OwnerFileLogOperation` with its label and `defaultRequiresReview`.
2. Write rows through `newLog(...)` inside the correct transaction (see the write-path template).
3. **No DDL** (TEXT column).

Traps: **never rename or reuse a constant** (historic rows would read as unknown); a new operation that
changes state must use the same permission/muni/re-read template.

### C. Add a seed kind

1. Add the constant to `OwnerFileSeedKind`.
2. Add a `case` to `classifySeeds` and any new field on `OwnerFileDeriver.Input`.
3. Teach the deriver/integrator to use it.
4. If it is not a control kind, remember the CHECK: `controllerside` must be NULL for it.

### D. Change a folding rule

1. Edit `chooseHeadsAndMembers` (and `prepareControlEdges` if orientation changes).
2. If the *definition of "owner" or "active edge"* changes, edit `OWNER_LINK_PREDICATE` **and** the
   control-edge SQL **together**.
3. Walk the seven worked examples in the [theory page](/dev/subsystems/workflow-builder/owner-files-derivation-theory) §4
   and write down what each now produces.
4. Remember **the reverse lookup reuses the deriver**: confirm the candidate-selection step in
   `ownerfile_getMembershipsFor…` still finds every file the new rule could include (it selects by owners and
   both edge ends).
5. Update the theory page, the user page, and the spec.

### E. Change the mail-to ladder

Touch `resolveDerivedMailto`, `OwnerFileMailtoProvenance`, the summary counters in `summarize`, the label
text (`OwnerFileLabelLines`), the audit sheet, the CSV `address_provenance` column, and the flag catalog.
Keep "data first, declaration laid over it".

### F. Add a column to `workflow.ownerfile`

1. DDL in a **new patch file** `codeconnect/database/patches/dbpatch_betaN.sql` where N = current highest + 1.
   ECD reviews and runs it.
2. `OwnerFile` entity getter/setter; copy constructor in `OwnerFileHeavy`.
3. `SHELL_SELECT` **and** `generateOwnerFileShell`; any `INSERT`/`UPDATE` SQL; `attachSavedFile` in the deriver.
4. If a clerk edits it: `ownerfile_updateFile` (diff + a log operation), the edit dialog.
5. Table names: all lowercase smashed; FKs `referencedtable_pkcolumn`; lifecycle columns per repo convention.

### G. Add a read

Use the template from the [read path page](/dev/subsystems/workflow-builder/owner-files-read-path-code) §7:
integrator method (SQL + `generateXxx` + `releasePostgresConnection`), guard empty arrays, apply the muni
fence, no business logic. Re-count placeholders vs `set…` calls.

### H. Add a write

Use the six-step template from the [write path page](/dev/subsystems/workflow-builder/owner-files-write-path-code) §1.
Guarded SQL + `rowCount` check + log rows in **one** transaction; re-read before writing; permission and muni
checks inside the coordinator method.

### I. Add a UI action

Bean method calls **only** the coordinator; fields bind to the selected object directly (BB Rules 1–2);
`update="@form"` on dialog commits; two-step confirm instead of `onclick="return confirm(...)"`; explicit `id`
on every command component; visible text on every button; no `style=`; dates via `#{bean.getPrettyDate(...)}`;
never `--` inside an XHTML comment.

### J. Add a new logic object (the deriver's species of class)

Use this when you have a *decision or computation over data already in memory* (a new rule engine, a new
formatter with state-free logic). Full reasoning is in
[deriver vs coordinator](/dev/subsystems/workflow-builder/owner-files-deriver-vs-coordinator) §7.

1. **Plain class**: no annotations, **no `extends BackingBeanUtils`**, no `@Named`. Put it in
   `coordinators/` beside the deriver (or `label/` for the label engine).
2. **No mutable fields**, no `static` mutable state. Constants (`static final`) only.
3. **One public method** taking a **parameter object** (`public static class Input` with public fields and
   defaults) and returning a **result object**.
4. **Per-call state in a `private static class` context object**, passed as an argument to every helper.
5. **No `getSessionBean()`, `getPostgresCon()` or `FacesContext`**: everything arrives in the input.
6. **Do not mutate objects you did not create** unless you document it; copy rows first if two results may
   share them (primer §13).
7. Have a **coordinator own it** in a `private final` field (`private final MyLogic logic = new MyLogic();`)
   and add the world-touching code (permissions, reads, writes, logging) there.
8. Cite the governing ruling in the Javadoc (R-n / Q-V3-n), as the deriver does.

If you find yourself wanting an instance field to carry data between helper methods, that is the signal to
introduce a context object instead (deriver vs coordinator §3.4).

## 4. Verification when there are no automated tests

Decision **R-34**: no automated tests for this facility. Verification is **manual and reconciling**:

1. `mvn clean package -DskipTests` is green.
2. ECD opens the **Rental registry manager** page for **Sharpsburg (municode 852)** and compares panel numbers
   with ECD's probe results (spec §V3.18.4). For the "Rental Property" group the expected numbers were:
   **422 group parcels / 413 with an owner link / 9 without**; **≈ 319 owners** (fewer by the folded
   entities); ladder buckets **256 single human address, 42 human addresses differ, 12 one 233, 3 233 differ,
   6 none**; **1** owner-occupant (119) parcel; **3** co-owned parcels; **26** shared-address groups.
3. ECD runs the read-only confirmations in the [write path page](/dev/subsystems/workflow-builder/owner-files-write-path-code) §12.
4. The agent that built the facility used **throwaway `/tmp` harnesses** over the pure deriver and a fake
   integrator (12 scenarios, later 91 checks). They were **not committed**. You can recreate one in a scratch
   directory: build an `OwnerFileDeriver.Input` by hand, call `new OwnerFileDeriver().derive(in)`, inspect the
   files.

### The probe catalogue (`dbpatch_beta104.sql` §8; results in `artifacts/phase16v3_probes`)

| Probe | Answers |
|---|---|
| **P-1** | Every HumanHuman role: which means "controls" |
| **P-1b** (852) | Which HumanHuman roles are actually used around Sharpsburg owners, and which side is the business entity (direction evidence) |
| **P-2** | How many seed-role `humanparcel` rows are archived / finite-`validto` / not yet valid |
| **P-3** | Humans with two active `priority = 0` mailing links (~638; why priority is not used) |
| **P-4** | Role-233 address fan-out per owner |
| **P-5** | Owners and parcels the seeds reach muni-wide (~1,155 owners, ~1,500 parcels) |
| **P-6** | Role titles for 100–103, 116, 119, 120, 233–235 |
| **P-7** | Owners by address source |
| **P-8** | Parcel groups vs owner-link coverage ("Rental Property": 422 / 9) |
| **P-9** | Owners per parcel (3 co-owned) |
| **P-10** | Top owners by parcel count (duplicates, institutions) |
| **P-11** | Ladder preview for the seed group |
| **P-12** | Seed group size, owner-occupant parcels |
| **P-13** | Shared addresses among seed-group owners (duplicate-owner problem) |
| **P-17-9** | Reverse-lookup cost (Phase 17); only covers the first two reads |

## 5. Pre-merge violation greps (repo rules)

Before finishing any bean or coordinator change, search for these signals (from the repo's guide):

| Pattern | Rule broken |
|---|---|
| `getXxxIntegrator()` inside `*BB.java` | A bean must call a coordinator, never an integrator |
| `new OwnerFile…()` / any `new` of a business object inside `*BB.java` | BB Rule 7: use a coordinator factory |
| `if`/`switch`/`for` logic inside a getter | BB Rule 4: pure getters |
| `style="..."` in XHTML | All CSS in `style.css` |
| `<f:convertDateTime` | Use `#{bean.getPrettyDate(...)}` |
| `onclick="return confirm(` | BB Rule 6: two-step confirm |
| `action=` on an AJAX `p:commandButton` | Use `actionListener=` |
| `getKeyCard()` / `isHasXxxPermissions()` inside `*BB.java` | BB Rule 8: permissions are the coordinator's |
| `--` inside an XHTML `<!-- … -->` comment | Illegal XML: JSF throws at deploy time |
| `method(int xxxID, …)` on a non-getter coordinator/integrator method | Pass typed objects; ints only on initial-fetch getters |

## 6. Where things live (quick finder)

| I want to… | Open |
|---|---|
| change *what* folds | `OwnerFileDeriver.chooseHeadsAndMembers`, `prepareControlEdges` |
| change a mailing-address rule | `OwnerFileDeriver.resolveDerivedMailto` |
| change what counts as an owner | `OwnerFileIntegrator.OWNER_LINK_PREDICATE` + seed rows |
| add or change a SQL read | `OwnerFileIntegrator` |
| add or change a write | `OwnerFileCoordinator` (`ownerfile_…`) + integrator transaction method |
| change what the clerk sees | `restricted/cogstaff/prop/compositions/ownerFile*.xhtml`, `OwnerFileManagerBB` |
| change labels or CSV | `OwnerFileLabelLines`, `label.*`, `ownerfile_buildLabelRun`, `ownerfile_buildCsv` |
| change a fixed role id | `dbFixedValueLookup.properties` (`ownerfile_*`) |
| change the badge | `ownerFileBadgeCC.xhtml`, `ownerfile_getMembershipsFor…`, the two bean getters |
| see the schema | `codeconnect/database/schemas/cogdb_local_schemaonly_16OCT26.sql`; DDL source `dbpatch_beta104.sql` |

## 7. Backlog and open items worth knowing

- **Seed-LOR configuration UI** (R-20) so seeds stop being hand-written SQL.
- **Promote a parcel mailing link to a person mailing link** (R-10).
- **Workflow enrollment** (`ownerfile_enrollFile`, the dormant `workflowinstance.ownerfile_ownerfileid`).
- **`DRIFT_SINCE_LOCK`** flag (live derivation vs lock snapshot).
- **Record audit outcome in-app** (`AUDITED_CORRECT` / `AUDITED_CHANGED` are in the enum, unwritten).
- **Depth-2 entities are silently omitted** (no flag): theory example D.
- **Reverse-lookup scaling fixes** F-1…F-7 (reverse lookup page §8).
- **Layer 1 stored enrollment** (Phase 17), deferred until Layer 0 is measured.
- **Jackson version mismatch** (lock snapshot JSON is hand-written for that reason).
- **`labelcalibration` table** exists but nothing reads or writes it.
- **`BackingBeanUtils` keeps per-call values in shared fields** (`connx`, `sessionBean`) on singleton beans: an
  observed hazard, not a reproduced failure; fix is local variables (deriver vs coordinator §6.3). Needs ECD's
  decision and a regression pass because the base class serves the whole application.
- **`ownerfile.mailto_humanid`** is a reserved, unused column.

## 8. Practice exercises (do these before changing the deriver)

Predict the result from the rules, then check the theory page. Answers are at the end of each.

**Exercise 1.** Group = { P1, P2 }. `own(Ann → P1)`, `own(Ann → P2)`, no control edges. *What files?*
> One file headed by Ann listing P1 and P2.

**Exercise 2.** Group = { P3 }. `ctl(Ann ⇒ LLC)` via a seeded `SOURCE` control role; `own(LLC → P3)`; Ann owns
nothing. *Who heads? Who is a member?*
> Ann heads (a sole controller becomes a head even if it owns nothing in the group). LLC is a **member**.
> The file lists P3 (owned via the entity). Ann's `parcelCount` is 1 although she owns none directly.

**Exercise 3.** Same graph as exercise 2, but the seed row says `controllerside = 'TARGET'` by mistake.
*What happens?*
> The deriver reads the edge as "LLC controls Ann". Group owners = { LLC }; LLC has **no** controller, so it
> **heads its own file** with P3; Ann is not an owner in the group and heads nothing. **No error, no flag**: the
> graph just does not fold. (Fix: deactivate the seed and re-insert with `SOURCE`.)

**Exercise 4.** Saved-files run, Ann is a saved head. `ctl(Ann ⇒ LLC)` and `ctl(Bob ⇒ LLC)`; `own(LLC → P3)`.
*What does Ann's file list? What does the badge on P3 say?*
> LLC has two controllers, so it is **not folded** into Ann's file (rule F2). Ann's file lists only parcels she
> owns directly and carries `CONTROLLED_ENTITY_NOT_FOLDED`. P3 is in **no** file (LLC is not a saved head), so
> the badge on P3 shows nothing.

**Exercise 5.** `own(Ann → P7)`, `own(Bob → P7)`; only Ann has a saved file. *Badge on P7? On Bob's profile?*
> P7's badge: "In rental owner file", via the head's own link (Ann). Bob's profile shows **no badge**: a
> co-owner who is not a head or a folded member is not in the file (the file lists the parcel through Ann's
> link and does not name Bob).

**Exercise 6.** `ctl(Wang ⇒ LLC1)`, `ctl(LLC1 ⇒ LLC2)`, `own(LLC2 → P9)`. Wang is a saved head, LLC1 and LLC2 are
not. *Is P9 in any file?*
> No. LLC2's only controller (LLC1) is not a head, so LLC2 is not folded; LLC1 is folded under Wang but the walk
> stops there (rule L1). *By code reading, no flag is raised on Wang's file for this.*

## 9. Documentation duties when you change things

Per the repo's always-on rules (see the codenforce `.github/copilot-instructions.md`):

- Update the **status line** of any plan/spec you work from, **every turn**.
- Append to `docs/worklog.md` and bump the subsystem's *Last worked* on `docs/subsystem-status.md`.
- When a feature flips to `DONE`, the Dev↔Docs Definition of Done applies (impl file linked; wikidocs page
  published; redirect id registered if there is an in-app help link; planned-reference notes removed).
- Keep these nine pages consistent with the code: **a rule changed in `OwnerFileDeriver` should change the
  theory page in the same pull request.**
