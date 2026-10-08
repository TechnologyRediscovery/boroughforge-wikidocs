---
title: Production DB Log — Patch/Schema Divergence Findings
description: Append-only investigation log of cases where the production CodeNforce database's actual schema diverged from what the patch history implies it should be — root causes, evidence trail, and remedies. Not a procedure doc; see postgresql-cluster-hygiene.md / backup-restore-runbook.md for those.
published: true
date: 2026-10-06
tags: [postgresql, patches, incident, investigation, finance-schema, cear]
editor: markdown
dateCreated: 2026-10-06
---

# Production DB Log — Patch/Schema Divergence Findings

Append-only log. Add new dated entries at the **top**. Each entry documents one divergence
between what prod's actual schema contains and what the patch history (`dbpatch_betaN.sql`
files in the `codenforce` repo) implies it should contain — plus the root cause, the evidence
trail, and the remedy chosen. All findings below were produced by static analysis of patch
files and `pg_dump` schema-only snapshots; no live DB connection was made or is available to
the assistant producing this log (see the codenforce repo's zero-DB-access boundary).

---

## 2026-10-06 — `dbpatch_beta91.sql` never ran on prod; `citationstatus.notifycasemonitors` missing broke session init

### Symptom
Right after applying `dbpatch_beta102.sql`, prod sessions started throwing a `FacesException`
out of `SessionInitializer.sessionInit_credentializeUserMuniAuthPeriod`, with a root
`PSQLException: ERROR: column "notifycasemonitors" does not exist` (Position: 177) from
`CourtEntityIntegrator.getCiationStatus(statusID)`.

### Root cause
`dbpatch_beta91.sql` ("Muni CEAR Update Blast Settings") was never applied to prod. Patch 102
itself contains nothing related to `citationstatus` — it only happened to be the first patch
to exercise a code path (building a `CECase` that touches citation status) that depends on a
column beta91 was supposed to have added 11 patch-numbers earlier.

### Evidence (schema-dump comparison only)
Checked the 6-Oct-2026 prod schema-only dump (taken before patch 102 ran) against
`dbpatch_beta91.sql`'s six additive items:

- `public.citationstatus` exists on prod but has no `notifycasemonitors` column.
- None of beta91's other five targets exist either: `cecactionrequestmunisettings
  .updateblastsettings`, the `public.cearupdateblastoptout` table (and its
  `subscribertype` column), `ceactionrequest.updateblastoptouttoken`,
  `ceactionrequest.notifyinternalsubmitter`/`notifyinternalsubmitterconfirmation`/
  `internalsubmitterblastoptouttoken` — confirming the entire patch never ran, not just one
  column.
- Grepped `dbpatch_beta92.sql` through `dbpatch_beta102.sql` for any reference to those same
  six targets — zero hits. Nothing downstream built on top of beta91's objects, so re-running
  it late carries no ordering conflict.
- Every statement in `dbpatch_beta91.sql` is additive and idempotent (`ADD COLUMN IF NOT
  EXISTS`, `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`), and `public.dbpatch`'s
  only constraint is a plain PK on `patchnum` (`dbpatch_pk`, no monotonicity check) — so it was
  safe to run `dbpatch_beta91.sql` as-is, out of its original numeric order, rather than
  needing a new wrapper patch.

### Remedy
Ran `dbpatch_beta91.sql` directly against prod, unmodified. `patchappliedts` (added by patch
102) now correctly records today as the real run time, while `datepublished` stays `NULL` as
originally authored — an honest record that the content was written in July but not applied
until October. The `dbpatch` log now has patch 91 registered after 92–102 chronologically by
`patchappliedts` even though its `patchnum` is lower; that's expected and not a sign of further
divergence.

### Lesson for future divergence checks
A subsystem's own spec/tracking doc marking a DB patch "✅ Done" (see
`docs/subsystems/cear/municearupdatesettings-jul2026.md`) only means dev-complete, not
necessarily prod-applied. Prefer cross-checking an actual prod schema dump over trusting a
planning doc's status claim, especially for patches that sat for months without the live code
path being exercised.

---

## 2026-10-06 — `finance` schema empty on prod; `dbpatch_beta99.sql` blocked at `finance.moneyledger`

### Symptom
Applying `dbpatch_beta99.sql` to prod fails with `ERROR: relation "finance.moneyledger" does
not exist`.

### Root cause
The `finance.moneyledger` table (and its siblings: `moneychargeschedule`,
`moneyledgercharge`, `moneychargeoccpermittype`, `moneypmtmetadatacheck`,
`moneypmtmetadatamunicipay`, `moneytransactionhuman`, `moneytransactionsource`) were only ever
created in one place: the archived `dbpatch_beta40.sql` ("GRAND TRANSACTION REVAMP" section).
That script contains a typo — `CREATE TABLE pulic.moneyledgercharge` (schema `pulic` does not
exist) — partway through the block. Whatever ran it against prod never got past that point for
at least some of the statements in that section.

### Evidence (schema-dump comparison only)
Compared prod snapshots from 9-Aug-2026 and 6-Oct-2026 against
`dbpatch_beta40.sql`/`dbpatch_beta87_schemaCleanup.sql`/current canonical dev schema:

- `finance` schema exists on prod (created by `dbpatch_beta87_schemaCleanup.sql`'s
  `CREATE SCHEMA IF NOT EXISTS finance;`) but contains **zero tables**, on both dumps.
- All 9 legacy `public.money*` tables that beta40 was supposed to `DROP ... CASCADE`
  (`moneycecasefeepayment`, `moneycecasefeeassigned`, `moneycodesetelementfee`,
  `moneyoccperiodfeeassigned`, `moneyoccperiodfeepayment`, `moneyoccperiodtypefee`,
  `moneypayment`, `moneyfee`, `moneypaymenttype`) are still present and fully functional on
  prod, with all original constraints/FKs intact.
- `public.chargetype` enum exists on prod, but `public.transactiontype` (created later in the
  same beta40 block) does **not**. This rules out a clean "one atomic transaction, all-or-
  nothing rollback" theory — the failure/stop point is somewhere around `moneychargeschedule`,
  not a single clean boundary at the `pulic` typo. The exact historical execution mechanics
  (manual chunked psql runs vs. per-statement autocommit) could not be determined from static
  files alone and were not pursued further, since they don't change the remedy.
- Corroborating side-evidence: `workflow.workflowinstanceobjectlink` on prod has every FK
  constraint present in current source **except** `payment_paymentid → finance.moneyledger`.
  Consistent with `dbpatch_beta88_workflow.sql` having been hand-adjusted at deploy time to
  drop that one inline `REFERENCES finance.moneyledger(...)` clause, because the gap was
  already known back when beta88 was applied.
- `dbpatch_beta87_schemaCleanup.sql`'s `ALTER TABLE IF EXISTS public.money* SET SCHEMA
  finance;` statements all silently no-opped on prod (guarded by `IF EXISTS`) because the
  tables never existed in `public` to move in the first place — this is why the gap stayed
  invisible for so long.

### Correction made mid-investigation — the legacy tables are NOT dead code
The initial plan (given the finance/ledger redesign is pre-release) was to drop the 9 legacy
`public.money*` tables as part of catching prod up. That assumption was wrong and was caught
before any patch was written: `PaymentIntegrator`/`PaymentCoordinator` still actively query
these tables, wired live into `FeeManagementBB` and `PaymentBB` (the occupancy fee/payment
UI) — not vestigial code. The codenforce repo's own
`docs/subsystems/payment/payment-subsystem-review-1JUL26.md` lists the `FeeManagementBB`/
`PaymentBB` cutover to the new ledger model as a **not-yet-done** future step. So on prod
today, the legacy tables are the *only working* fee/payment system; the `finance`-schema
ledger redesign never actually went live, because this exact gap kept it from ever being
populated.

### Remedy
Additive-only prepend to `dbpatch_beta99.sql`: create the missing `finance.*` tables/types
directly against current canonical structure (fixing the historical `pulic` typo in the
process), without touching or dropping any of the 9 legacy `public.money*` tables. The
legacy-to-ledger cutover (including the `FeeManagementBB`/`PaymentBB` rewrite) remains
separate, deliberate future work already tracked in the payment subsystem docs — not something
to fold into a reactive prod-sync patch.

### Sequence-safety note
`public.occinspectionfee_feeid_seq` and `public.paymenttype_typeid_seq` are standalone
sequences — never `ALTER SEQUENCE ... OWNED BY` their legacy table columns. The current
canonical schema still deliberately reuses both for `finance.moneychargeschedule.chargeid`
and `finance.moneytransactionsource.sourceid` respectively, so neither may be dropped
regardless of what eventually happens to the legacy tables they currently back.
