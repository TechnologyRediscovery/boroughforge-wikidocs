---
title: WestMC Data Exchange — System Administrator Operations Guide
description: Daily monitoring, quarterly operations, and result interpretation for the Westmoreland County data exchange
published: true
date: 2026-07-21T00:00:00.000Z
tags: 
editor: markdown
dateCreated: 2026-07-21T00:00:00.000Z
---

# WestMC Data Exchange — System Administrator Operations Guide

**Audience:** System administrators at municipalities participating in the
Westmoreland County (WestMC) data exchange program.
**Scope:** Daily monitoring, quarterly operations, result interpretation.

---

## Overview

CodeNForce maintains a mirror of selected Westmoreland County data tables in a
local `westmc` PostgreSQL schema. This data is never the system of record —
WestMC owns and publishes it through the AppSheets API. CodeNForce syncs from
that source on a schedule, and for two special datasets, a human operator reviews
and triggers the process manually each quarter.

There are **three distinct processes**. They have different scopes, different
risks, and different triggers.

| # | Process | Trigger | Scope | Touches Native Tables? | Cadence |
|---|---------|---------|-------|------------------------|---------|
| 1 | **Nightly Data Exchange** | Automated (Quartz scheduler) | 7 mirror tables | **No** | Nightly |
| 2 | **Tax Delinquency Mirror Refresh** | Human operator | 1 mirror table | **No** | ~Quarterly |
| 3 | **Parcel Data Harmonization** | Human operator | Native parcel/address tables | **YES** | ~Quarterly |

---

## Process 1 — Nightly Data Exchange

### What it does

Pulls new and updated records from the AppSheets API for seven supporting
data sets and writes them into the `westmc.*` mirror tables. This is a
read-from-remote, write-to-mirror-only operation. No CodeNForce native records
(properties, persons, cases) are modified.

### Tables included in the nightly job

| Table | Pull New | Pull Updates | Notes |
|-------|----------|--------------|-------|
| `westmc_land_banking` | ✓ | ✓ | Land banking status |
| `westmc_countywide_demo` | ✓ | ✓ | County demolition data |
| `westmc_blight_record` | ✓ | ✓ | Blight records pulled FROM WestMC into the CNF mirror. See note below. |
| `westmc_documents` | ✓ | — | Document references |
| `westmc_parcel_photo` | ✓ | — | Parcel photo references |
| `westmc_arpa` | ✓ | ✓ | ARPA-funded project data |
| `westmc_demofund` | ✓ | ✓ | Demo fund program data |

**Not included in the nightly job:**

- `westmc_parcel_data` — handled by Process 3 (Parcel Harmonization)
- `westmc_tax_delinquency` — handled by Process 2 (Tax Delinquency Refresh)

> **Blight record — dual-direction table:** `westmc_blight_record` is included in
> the nightly pull like other tables above. However, there is also a separate **push**
> pathway: when an officer finalizes a property evaluation in CodeNForce, the resulting
> blight record is pushed to WestMC through the AppSheets API. These officer-originated
> records are **not** written back to the `westmc_blight_record` mirror table because
> CodeNForce, not WestMC, is their system of record. The mirror table contains only
> records that originated in WestMC and were pulled into CNF.

### When it runs

The Quartz scheduler triggers this automatically each night. The exact schedule
is configured in the application server. No manual action is required under
normal conditions.

### Monitoring

- Check the **Logging** tab on the Data Exchange Dashboard daily
- Look for `SUCCESS` entries in Recent Business Operations
- Duration under 5 minutes is normal for 7 tables
- If the last-run timestamp is more than 25 hours ago, investigate WildFly scheduler health

### Manual trigger

If the nightly job failed or you need to run it immediately:

1. Go to **Data Exchange Dashboard → Exchange Tools tab**
2. Click **Launch Data Exchange**
3. Results appear below the button after completion
4. Check the **Logging** tab to confirm all 7 tables processed

> **Note:** "Launch Data Exchange" runs the same table set as the nightly
> Quartz job (the 7 tables above). It does **not** trigger Parcel Harmonization
> or Tax Delinquency Refresh.

---

## Process 2 — Tax Delinquency Mirror Refresh

### What it does

Pulls the current tax delinquency file from WestMC and refreshes the
`westmc.westmc_tax_delinquency` mirror table using an upsert strategy:

- New delinquency records are inserted
- Existing records are updated in place
- Records that reappear after being absent are reactivated (deactivation
  timestamp cleared)

No CodeNForce native tables are touched.

### When to run it

- **Approximately quarterly**, after WestMC publishes a new delinquency extract
- When a staff member reports that the delinquency data looks stale
- After confirming with WestMC that their latest file is available via the API

### How to run it

1. Go to **Data Exchange Dashboard → Muni Configuration tab**
2. Locate the target municipality in the table
3. Click **Sync Tax Delinquency** in the Actions column for that municipality
4. Wait for the growl notification confirming success and record count
5. To verify, go to **WestMC Table Viewer tab**, select the municipality and
   `TAX_DELINQUENCY`, click **Load Table Data**

### Interpreting results

The growl message shows the number of records processed. No further action is
required — the updated data is available immediately for staff viewing.

---

## Process 3 — Parcel Data Harmonization

### What it does

This is the most consequential process in the WestMC integration.

It reads parcel records from `westmc.westmc_parcel_data` and attempts to match
each one to CodeNForce's native parcel records (`humanparcel`,
`parcelmailingaddress`). Where matches are found, it updates native address and
owner data. Records that cannot be matched are flagged for staff review.

**This process modifies mission-critical native CodeNForce tables.** Run it
deliberately, with appropriate staff awareness.

### When to run it

- **Approximately quarterly**, after WestMC has published a fresh parcel dataset
- When property addresses or owner names are significantly out of date and a
  WestMC export is available
- Only when the Tax Delinquency Refresh has been run first (to ensure fresh
  delinquency context)
- **Never** during active public hearings or enforcement periods where parcel
  data integrity is being relied upon by staff

### Prerequisites

1. Confirm WestMC has published updated parcel data via the API
2. The target municipality must have **WestMC Enabled = YES** in the Muni
   Configuration table
3. A baseline record count must exist for the municipality — the system checks
   this and will abort if the incoming record count is drastically different
   from the last run, as a circuit-breaker safety check
4. Recommended: run "Sync Tax Delinquency" first for the same municipality

### How to run it

1. Go to **Data Exchange Dashboard → Muni Configuration tab**
2. For the target municipality, click **Harmonize Parcels**
3. The button is disabled while harmonization is in progress — do not navigate
   away from the page
4. When complete, the **Parcel Harmonization Results** panel appears below the
   municipality table

### Interpreting results

The results panel shows four metrics:

| Metric | Meaning |
|--------|---------|
| **WestMC Records** | Total parcel records read from the WestMC mirror for this municipality |
| **Exact Matches** | Parcels that matched an existing CodeNForce parcel record by tax map number. Native data was updated for these. |
| **No Matches** | Parcels with no corresponding CodeNForce native record. These are logged but no native record is created. |
| **Flagged for Review** | Parcels where a match was found but data conflicts were detected. A staff member must review and resolve these. |

### After the run

- Review the **Flagged for Review** count — zero is ideal
- If flagged records exist, have the relevant staff member open Property Manager
  and work through the admin flags on affected parcels
- Check the **Logging** tab for any errors in the associated business operation
  log entry
- Confirm with WestMC that the run completed as expected if record counts look
  unusual

### Testing before a full run

Use **Test tiny batch** in the Muni Configuration table to run harmonization
against a small comma-separated list of specific parcel CNF IDs first. This
lets you verify the logic is working as expected before processing the full
municipality. Test results appear in a dialog and do not write to native tables.

---

## Dashboard Reference

The Data Exchange Dashboard is at:
`Cogadmin → System Administration → Data Exchange Dashboard`

### Tab 1: Exchange Tools

Controls for global operations.

| Control | Purpose |
|---------|---------|
| View API Configuration | Inspect the AppSheets API credentials and environment settings. Does not modify anything. |
| Refresh Logging Data | Force a reload of the Recent Business Operations and API Calls tables in the Logging tab. |
| **Launch Data Exchange** | Manually runs the same 7-table nightly pull immediately for all municipalities. Equivalent to the nightly Quartz job. |

### Tab 2: Muni Configuration

Per-municipality controls and the WestmcTableConfigEnum capability matrix.

**Municipality table — Actions column:**

| Button | Process | Notes |
|--------|---------|-------|
| View Tables | Opens a dialog showing capability flags per table for this muni | Read-only reference |
| **Harmonize Parcels** | Process 3 | Modifies native tables. Run deliberately. |
| Test tiny batch | Process 3 (test only) | Dialog for testing against specific parcel IDs |
| **Sync Tax Delinquency** | Process 2 | Mirror only |
| Sync Now | Same as Launch Data Exchange, scoped to all municipalities | Currently equivalent to "Launch Data Exchange" — per-municipality scoping is a planned future enhancement |

**WestMC Table Sync Settings panel:**

Shows the current capability flags from `WestmcTableConfigEnum.java` for all
10 mirror tables. This is a developer reference showing what the code is
configured to do. If the "In Nightly Job" column shows NO for a table you
expect to be synced, a developer review is needed.

### Tab 3: Testing

Developer and admin tools for verifying API connectivity and simulating the
data exchange with specific table selections. Test Mode limits which tables
are processed without touching nightly job configuration. Use this tab when
troubleshooting API failures or verifying a new municipality's configuration.

### Tab 4: Logging

- **Recent Business Operations**: One row per coordinator-level operation
  (harmonization run, tax delinquency refresh, full exchange). Click "view" to
  see the full payload JSON including metrics.
- **Recent API Calls**: One row per HTTP request to the AppSheets API. Check
  here to diagnose API errors (HTTP 4xx/5xx in the Status column).

> Logging data is loaded lazily. If the tables look empty or stale, click
> **Refresh Logging Data** in the Exchange Tools tab.

### Tab 5: WestMC Table Viewer

Read-only paginated view of the raw mirror table data, sliced by municipality.
Currently supported: **PARCEL_DATA** and **TAX_DELINQUENCY**.

Use this to:
- Verify that a mirror refresh actually populated the expected records
- Spot-check a specific parcel or delinquency record
- Confirm record counts after a sync operation

---

## WestmcTableConfigEnum — Attribute Reference

Each enum constant in `WestmcTableConfigEnum.java` configures how a single
WestMC table is handled. This table documents what each attribute does and
where it is consumed at runtime.

| Attribute | Method | Used by | What it controls |
|-----------|--------|---------|-----------------|
| `cnfTableNameString` | `getTableNameString()` | Coordinator (logging), Integrator (all SQL via `getFullTableName()` = `"westmc." + this`) | The PostgreSQL table name in the westmc schema |
| `remoteTableNameString` | `getRemoteTableNameString()` | WestmcAPIClient (`"Table"` field in every API request payload) | The table name sent to the AppSheets API |
| `pullNewRecords` | `canPullNewRecords()` | Coordinator (decides whether to call "fetch new records" path); `supportsPull()` = `pullNew OR pullUpdated` which gates nightly job inclusion | Enable/disable pulling records that are new since last sync |
| `pullUpdatedRecords` | `canPullUpdatedRecords()` | Coordinator (decides whether to call "fetch updated records" path) | Enable/disable pulling records modified since last sync |
| `syncRecords` | `canSyncRecords()` | `isBidirectional()` guard in coordinator; displayed in Muni Config tab | Enable bidirectional sync (pull AND push CNF data back to remote) |
| `pushNewRecordsOnly` | `canPushNewRecordsOnly()` | `isBidirectional()` guard; displayed in Muni Config tab | Enable push-only mode (send CNF-originated records to remote, no pull) |
| `batchSize` | `getBatchSize()` | WestmcAPIClient: controls page size when fetching updated records from the API | Max records returned per API request; tune for API rate limits |
| `dtoClass` | `getDtoClass()` | WestmcAPIClient: Jackson deserializes API JSON responses into this class | DTO class for JSON-to-Java mapping of records from the remote API |
| `lastUpdateFieldName` | `getLastUpdateFieldName()` | WestmcAPIClient: name of the remote date field used to filter "records updated since X" | The AppSheets field name for the "last modified" timestamp on the remote table (varies: `"last_updated_on"`, `"last_updated"`, `"last_update"`) |
| `remoteIdFieldName` | `getRemoteIdFieldName()` | WestMCPostgresIntegrator: reflection-based extraction of remote ID from DTO object for deduplication | The Java field name on the DTO that holds the remote system's unique key |
| `psqlIdColumnName` | `getPsqlIdColumnName()` | WestMCPostgresIntegrator: SQL `SELECT ... WHERE <this> IN (...)` for duplicate detection | The PostgreSQL column name for the same remote ID |
| `remoteIdKeyName` | `getRemoteIdKeyName()` | WestmcAPIClient: key name when sending ID mapping payloads back to AppSheets | The AppSheets API field name for CNF→remote ID mapping callbacks |

**Blight record — two constants, one table:** `BLIGHT_RECORD_READ` and `BLIGHT_RECORD_WRITEONLY` both reference `westmc_blight_record` but have opposite operation profiles. `BLIGHT_RECORD_READ` has pull flags set and is included in the nightly job. `BLIGHT_RECORD_WRITEONLY` has pull flags unset (`supportsPull()` = false) and is the configuration used when CNF pushes officer-created blight records to WestMC on property evaluation finalization — it is excluded from the nightly job.

**Attributes confirmed unused in current business processes:**
- `isBidirectional()` is checked once as a guard but no table currently passes the bidirectional sync path end-to-end
- `getRemoteEndpoint()` is `@Deprecated` and has no callers

---

## Known Limitations and Planned Improvements

| Item | Current Behavior | Planned |
|------|-----------------|---------|
| Gap 2 — temporal columns | `validfrom`/`validto` added to `humanparcel` and `parcelmailingaddress` in DB but not yet populated by Java code | Wire in Integrator/Coordinator |
| Gap 4 — conflict queue | Flagged-for-review parcels accumulate with no assignment or SLA | Assignment model |
| Gap 7 — zombie reactivation logging | Tax delinquency upsert silently reactivates records; no specific log event | Add `TAX_DELINQUENCY_REACTIVATED` log type |

---

*Last updated: July 2026. Maintained in this wiki (`admin/westmc-data-exchange.md`). For developer architecture notes see [Data exchange in Postgres](/dev/db/dataexchange).*
