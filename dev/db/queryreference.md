---
title: Handy DB queries
description: For system admin tasks
published: true
date: 2026-07-24T08:38:12.078Z
tags: 
editor: markdown
dateCreated: 2026-07-24T08:38:12.078Z
---
# Handy DB queries

## Event management

Batch deac of follow up events

```sql
SELECT
    e.eventid,
    e.category_catid,
    e.createdts,
    e.eventdescription,
    e.cecase_caseid,
    e.occperiod_periodid,
    p_cc.muni_municode  AS cc_muni,
    p_op.muni_municode  AS op_muni
FROM event e
-- CE Case pathway: event → cecase → parcel
LEFT JOIN cecase        cc   ON cc.caseid        = e.cecase_caseid
LEFT JOIN parcel        p_cc ON p_cc.parcelkey   = cc.parcel_parcelkey
-- OccPeriod pathway: event → occperiod → parcelunit → parcel
LEFT JOIN occperiod     op   ON op.periodid      = e.occperiod_periodid
LEFT JOIN parcelunit    pu   ON pu.unitid         = op.parcelunit_unitid
LEFT JOIN parcel        p_op ON p_op.parcelkey   = pu.parcel_parcelkey
WHERE e.deactivatedts IS NULL
  AND e.category_catid = 100039
  AND (
        p_cc.muni_municode = 852
     OR p_op.muni_municode = 852
  )
ORDER BY e.createdts DESC;
```

And the actual update

```sql
UPDATE event
SET
    deactivatedts       = now(),
    deactivatedby_userid = :performing_userid   -- replace with actual integer userid
WHERE eventid IN (
    SELECT e.eventid
    FROM event e
    LEFT JOIN cecase     cc   ON cc.caseid       = e.cecase_caseid
    LEFT JOIN parcel     p_cc ON p_cc.parcelkey  = cc.parcel_parcelkey
    LEFT JOIN occperiod  op   ON op.periodid     = e.occperiod_periodid
    LEFT JOIN parcelunit pu   ON pu.unitid        = op.parcelunit_unitid
    LEFT JOIN parcel     p_op ON p_op.parcelkey  = pu.parcel_parcelkey
    WHERE e.deactivatedts IS NULL
      AND e.category_catid = 100039
      AND (
            p_cc.muni_municode = 852
         OR p_op.muni_municode = 852
      )
);

```