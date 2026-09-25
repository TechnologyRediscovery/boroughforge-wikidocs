---
title: Event Type Visibility by Parent
description: Which EventType values the add-event picker offers for a CECase, OccPeriod, or Property, by user rank
published: true
date: 2026-09-23T00:00:00.000Z
tags: subsystem:event, audience:dev, type:reference
editor: markdown
dateCreated: 2026-09-23T00:00:00.000Z
---

# Event Type Visibility by Parent

Governs which `EventType` values show up in the add-event type picker for a given parent
object and acting user rank. Source: `EventCoordinator.determinePermittedEventTypes(domain,
erg, ua)`, which switches on `EventRealm` and delegates to one private per-parent method —
`determinePermittedEventTypesForCECase()` / `...ForOcc()` / `...ForParcel()`. Each of those is
an if-cascade gated on `RoleType` rank (`MuniStaff` = 2, `MuniReader` = 1), not a per-type
switch. This only filters the picker menu — it does **not** gate `addEvent()` itself, so
system/coordinator code can still attach any `EventType` directly.

## Exposed by parent

| EventType | Case (`CECase`) | `OccPeriod` | Property (parcel) | `EventRealm.UNIVERSAL` |
|---|---|---|---|---|
| `Action` | Staff+ | Staff+ (also unconditional if `hasEnfOfficialPermissions`) | Staff+ | — |
| `Timeline` | Staff+ | Staff+ | Staff+ | — |
| `Origination` | Staff+ | — | — | — |
| `Occupancy` | Staff+ | Staff+ | Staff+ | — |
| `PropertyAlert` | Staff+ | Staff+ | Staff+ | Always |
| `Citation` | Staff+ | — | — | — |
| `CaseAdmin` | Staff+ | — | — | — |
| `Inspection` | Staff+ | Staff+ | — | — |
| `Accounting` | Staff+ | Reader+ | — | — |
| `Communication` | Reader+ | Reader+ | Reader+ | Always |
| `Meeting` | Reader+ | Reader+ | Reader+ | Always |
| `Custom` | Reader+ | Reader+ | Reader+ | Always |
| `PropertyInfoCase` | — | — | Reader+ | — |

`Staff+` = rank ≥ `MuniStaff` (Staff/Manager/SysAdmin). `Reader+` = rank ≥ `MuniReader`
(everyone but `Public`). `UNIVERSAL` is used when `erg` isn't a specific parent; those 4 types
are added with no rank check at all.

## Never exposed via the picker

These `EventType` values never appear in any of the three per-parent lists, so a human can
never pick them from an add-event dialog. All are created directly by coordinator code (case
phase transitions, occupancy lifecycle, etc.) via `initEvent()`/`addEvent()`, bypassing the
picker gate entirely:

- `Casereopen`
- `Closing`
- `Violation`
- `Court`
- `Notice`
- `OccupancyOrigination`
- `OccupancyClosing`
- `PhaseChange`
- `Workflow`

## Gotchas found while tracing this

- **`Accounting`'s floor is inconsistent**: Staff-only on a case, but Reader-level on an occ
  period.
- **`Action` has a duplicate-add path on `OccPeriod`**: added once unconditionally if
  `ua.getKeyCard().isHasEnfOfficialPermissions()`, and again if rank ≥ Staff. Harmless (plain
  `ArrayList`, not deduped) but worth knowing if iterating the list for anything order/count-sensitive.
- **`EventType.getUserRankMinimumToEnact()`/`getUserRankMinimumToView()`** (the numbers baked
  into the enum itself, e.g. `Action(5, 1)`) are dead code — the only reference in the repo is
  a commented-out line in `PublicInfoCoordinator`. All real enforcement is the hardcoded rank
  checks above, plus each `EventCategory`'s own `roleFloorEventEnact`/`roleFloorEventView`.
