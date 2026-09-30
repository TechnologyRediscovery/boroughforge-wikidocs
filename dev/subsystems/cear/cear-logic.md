---
title: CEAR Processing Logic — Submission, Routing, and Email Notifications
description: How Code Enforcement Action Requests are submitted, routed by officers, and how the email-notification system is wired into that lifecycle.
published: true
date: 2026-09-28T00:00:00.000Z
tags: subsystem:cear, audience:dev, type:architecture
editor: markdown
dateCreated: 2026-09-28T00:00:00.000Z
---

> Migrated 2026-09-28 from the codenforce repo's `docs/subsystems/cear/cear-logic.md` (dating
> to April 2026), per the doc-organization convention that a subsystem's deployed "how something
> works" architecture lives here in the public-facing docs repo, while in-flight
> features/design-questions/debugging notes stay in the JSF (codenforce) repo under
> `docs/subsystems/cear/`. See the [CEAR dev overview](/dev/subsystems/cear/overview) for the
> current in-flight feature index.

_Reflects `CEARInternalSubmitBB`, `CEActionRequestsBB`, `CaseCoordinator`,
`CEARProcessingRouteEnum`, and `CommunicationCoordinator` as of April 2026, **except section 3
(Routing), section 4 (Status Lifecycle), and section 6 (Email Notification System), which are
current as of 2026-09-30** (the CEAR-A through CEAR-J batch — see the codenforce dev index at
`docs/subsystems/cear/cear-index.md` for the full per-item history) — check the codenforce dev
index for anything that has changed since._

---

## 1. What Is a CEAR?

A **Code Enforcement Action Request (CEAR)** is a complaint or municipal concern submitted to the CE office. It exists in one of three modes:

| Mode | Flags | Description |
|---|---|---|
| **Property-specific** | `muniGeneral=false`, `notAtKnownAddress=false` | Tied to a specific parcel via `parcelKey` |
| **Not at known address** | `muniGeneral=false`, `notAtKnownAddress=true` | Cannot be mapped to any parcel |
| **Muni-general** | `muniGeneral=true`, `notAtKnownAddress=true` | Infrastructure/patrol/non-parcel; no property attached |

---

## 2. Submission Pathways

### 2A. Internal Staff Submission (`cearInternalSubmit.xhtml` / `CEARInternalSubmitBB`)

This page is for officers creating a CEAR on behalf of a caller or for themselves.

#### Bean initialization (`@PostConstruct`)
1. Calls `CaseCoordinator.cear_getInititalizedCEActionRequest()` → returns blank `CEActionRequest` with `dateOfRecord=now`, `requestorPersonType=Public`, empty blob list.
2. Sets `muni` and `dateOfRecord` on `workingCEAR`.
3. Sets `muniGeneralRequest = false`, `submitAsSelf = true`.
4. Loads two issue type lists from coordinator: full (`issueTypeList`) and muni-general filtered (`muniGeneralIssueTypeList`).
5. Calls `onMuniGeneralToggle()` to prime `activeIssueTypeList` to the full list.

#### Request type toggle (`onMuniGeneralToggle`)
Bound to the `p:selectOneRadio` AJAX listener.

1. Clears `workingCEAR.issue`.
2. Reads `workingCEAR.isMuniGeneral()` (just set by the radio submit).
3. Mirrors the flag to BB field `muniGeneralRequest` — used by all `rendered=` conditions in the XHTML to avoid repeated getter chaining.
4. If NOT muni-general: `notAtKnownAddress=false`, `activeIssueTypeList = issueTypeList`.
5. If muni-general: `notAtKnownAddress=true`, `activeIssueTypeList = muniGeneralIssueTypeList`.

The AJAX `update` targets both the property wrapper (outside the main form) and the details panel (inside it) using absolute client IDs to avoid cross-form resolution failures.

#### Property resolution
- For **property-specific** requests, the officer uses `propertyQuickSearchCC` to set `sessionBean.sessProperty`.
- `muniGeneralRequest` controls whether the property panel renders at all.
- The "Property" field in Concern Details shows:
  - Address (bold) if property-specific and `sessProperty` is set.
  - "No property selected" (italic) if property-specific and no property selected yet.
  - "Muni-general requests are not attached to any particular property." if muni-general.

#### Pre-submit validation (`validatePreSubmit`)
- If NOT muni-general and `sessProperty == null` → error, abort.

#### Submit without photos (`onSubmitWithoutPhotos`)
1. `validatePreSubmit()`
2. `applyParcelAndSubmitterFields()`:
   - If not muni-general: copies `sessProperty.parcelKey` onto `workingCEAR`.
   - Sets `internalUserSubmitter=true`; if submitting as self clears name/phone/email, sets `requestorPersonType=User`.
3. `CaseCoordinator.cear_insertCEARFirstStage(workingCEAR, ua)`:
   - Assigns initial unprocessed status from resource bundle key `actionRequestInitialStatusCode`.
   - Generates public control code.
   - Sets `createdBy`, `lastUpdatedBy`.
   - Calls `CEActionRequestIntegrator.insertCEActionRequest()` → returns new `requestID`.
4. Shows success growl; calls `resetWorkingState()` to blank the form.

#### Submit with photos (`onSubmitWithPhotos`)
Same as above through step 3, but instead of resetting:
- Stores the returned ID on `workingCEAR.requestID`.
- Sets `cearPreSaved = true`.
- Opens the blob upload dialog via `BlobUtilitiesBB`.
- Re-clicking the button when `requestID != 0` just re-opens the dialog (idempotent).
- After upload, officer clicks "Submit another" → `onResetForAnother` → `resetWorkingState()`.

---

### 2B. Public Submission

Handled by `CEActionRequestSubmitBB`. Also calls `cear_insertCEARFirstStage` for first-stage insert, then `cear_updatePublicFields` for contact info in the second stage.

---

## 3. Routing (`cearCentral.xhtml` / `CEActionRequestsBB`)

After submission, unprocessed CEARs land on the CEAR dashboard (`cearCentral.xhtml`). Officers route them through a **3-step modal flow** (`cear-process-flow-var` dialog).

### 3.1 Route list computation (`evaulateSelectedRequestRoutingStatusAndUpdateRouteList`)

Called at every routing-state change. Builds `processingRouteList` based on request type:

| Request type condition | Routes offered |
|---|---|
| `isMuniGeneral()` | `MUNI_GENERAL_ACTION_UNDERWAY`, `MUNI_GENERAL_ACTION_COMPLETED`, `INVALID_REQUEST`, `REFERRED_TO_OTHER_DEPARTMENT` |
| `isNotAtKnownAddress()` | `INVALID_REQUEST`, `REFERRED_TO_OTHER_DEPARTMENT` |
| Standard (property-linked) — property **has** existing CE cases | `ATTACH_TO_EXISTING_CASE`, `ATTACH_TO_NEW_CASE`, `ATTACH_TO_OCC_PERIOD`, `INVALID_REQUEST`, `REFERRED_TO_OTHER_DEPARTMENT` |
| Standard (property-linked) — property **has no** CE cases yet | `ATTACH_TO_NEW_CASE`, `ATTACH_TO_OCC_PERIOD`, `INVALID_REQUEST`, `REFERRED_TO_OTHER_DEPARTMENT` |

`ATTACH_TO_EXISTING_CASE` is omitted when `selectedRequestPropertyDH.getCeCaseList()` is null or empty, preventing the officer from reaching step 3 only to find an empty table.

> **Retired from new routing 2026-09-30 (CEAR-F): `NO_VIOLATION_FOUND`.** The enum constant,
> its DB status row, and the `UNPROCESSED` re-route escape hatch for CEARs already sitting in
> this status are all untouched — this is a soft deactivation at the route-*offering* layer
> only (`CEARProcessingRouteEnum` is a Java enum, not a DB-backed lookup table, so there is no
> row to flag `deactivatedts` on). The constant carries `@Deprecated` plus a Javadoc pointer to
> this decision. Rationale: a genuine "no violation found" determination is a code-enforcement
> finding and now requires a real CE case with a logged inspection
> (`ATTACH_TO_NEW_CASE`/`ATTACH_TO_EXISTING_CASE`) rather than a one-click dashboard closeout.
> Officers are routed into a case for anything short of literal junk (`INVALID_REQUEST`) or a
> referral (`REFERRED_TO_OTHER_DEPARTMENT`).
>
> **Added 2026-09-30 (CEAR-C, tier 1): `REFERRED_TO_OTHER_DEPARTMENT`.** A plain terminal
> "get this off my plate" route — free-text note, no case/property requirement, offered in
> every branch above. It reuses the existing `CEAR_ROUTED` blast event (fires on every
> terminal-route commit once a muni enables that event type) rather than needing its own event
> type. A **tier 2** enhancement (officer picks a specific staff person with a valid UMAP —
> "MuniStaff rank or above" is being revisited to also allow read-only accounts — to receive
> the full CEAR confirmation email as a new-task notification, via
> `CEARUpdateBlastContext.overrideToAddress`, alongside — not instead of — the normal update
> blast) is spec'd but still `PLANNING`; see the codenforce dev index's CEAR-C doc and
> `cearbacklog.md`.

After the type-based list is built, the method resolves the **current route** (`resolveCurrentRoute()`) by scanning all enum values for the one whose DB status key matches the current `requestStatus.statusID`. It then checks `isTerminal()` on that route:

- **Non-terminal** current status (`UNPROCESSED`, `MUNI_GENERAL_ACTION_UNDERWAY`): `selectedRequestAwaitingInitialRouting = true` — the **"Process this request"** button remains visible.
- **Terminal** current status (all others): adds `UNPROCESSED` as an escape-hatch re-route option, sets `selectedRequestAwaitingInitialRouting = false` — the button hides.

### 3.2 Step 1 — Property

> **Changed 2026-09-30 (CEAR-H-3): muni-general requests no longer skip this step.** The
> earlier behavior (`onCEARProcessingInit` special-casing `selectedRequest.isMuniGeneral()` to
> jump straight to `cearFlowActiveStep = 2`) left an officer with no way to search for and
> attach a real property to a muni-general concern that turned out to have one (e.g. a
> "streetlights are out downtown" report that's actually traceable to one parcel). Every
> request type — including muni-general — now always starts at step 1. A muni-general request
> with genuinely no property gets a dedicated **"This is a general request (no property),
> proceed to routing"** confirm button (rendered only when `empty requestProperty and
> muniGeneral`) alongside the normal property-search box, wired to the same
> `onCEARFlowPropertyConfirm` listener. If an officer instead searches for and attaches a real
> property to a muni-general CEAR here, `CaseCoordinator.cear_updateCEARProperty()` now also
> flips `muniGeneral` back to `false` (mirroring its existing `notAtKnownAddress` toggle-off),
> so the request routes as standard/property-based going forward instead of being stuck
> offering only the muni-general routes.

For all other request types, step 1 displays the currently linked property address (or "No property linked").

- **"Property is correct, proceed to routing"** button (rendered only if `requestProperty` is not empty):
  - `onCEARFlowPropertyConfirm` → calls `evaulateSelectedRequestRoutingStatusAndUpdateRouteList()` then advances `cearFlowActiveStep = 2`.
  - **Important**: the route list must be built here; without it, step 2 renders an empty listbox.
- **Reassign to different property** (via `propertyQuickSearchCC`):
  - `onCEARFlowPropertyReassign(prop)` → `cear_updateCEARProperty(...)` → `refreshSelectedRequest()` → `evaulateSelectedRequestRoutingStatusAndUpdateRouteList()` → advances to step 2.

#### Property update coordinator logic (`cear_updateCEARProperty`)
- Validates non-null params.
- Notes old parcel key in muni notes via `SystemCoordinator.appendNoteBlock`.
- Sets new `parcelKey` on CEAR.
- Clears `notAtKnownAddress=false` (request is now at a known address).
- Calls `CEActionRequestIntegrator.updateActionRequestInternalFields(cear)`.
- Flushes cache.

### 3.3 Step 2 — Route Selection

Officer picks a route from `p:selectOneListbox` (no placeholder; list is populated from `processingRouteList`).

- **"Continue to execution"** → `onCEARFlowRouteSelectCommit`:
  - Guards: `selectedRoute == null` → error.
  - Guards: case-attach routes require linked property.
  - For case-attach routes: copies `requestProperty` into `sessProperty`.
  - Advances `cearFlowActiveStep = 3`.
- **"Back to property"** button (hidden for muni-general via `rendered="#{not ...muniGeneral}"`) → `onCEARFlowBackToStep1` → sets `cearFlowActiveStep = 1`.

> **Muni-general requests:** the "Back to property" button in step 2 is hidden (`rendered="#{not cEActionRequestsBB.selectedRequest.muniGeneral}"`), since there is no property step to return to.

### 3.4 Step 3 — Execute

Each route renders its own `f:subview`:

#### ATTACH_TO_EXISTING_CASE (`cear-flow-step3-excase-sv`)
- Displays all CE cases on `selectedRequestPropertyDH`.
- Officer clicks "Attach" on a row → `path2UseSelectedCaseForAttachment(cse)`:
  - `CaseCoordinator.cear_connectCEARToCECase(cse, cear, ATTACH_TO_EXISTING_CASE, ua)`:
    - Validates parcel keys match.
    - Sets `caseID`, `caseAttachmentTimestamp`, `caseAttachmentUser`, `lastUpdatedBy`.
    - Updates status to `actionRequestExistingCaseStatusCode`.
    - Appends public note.
    - Writes to DB via integrator; flushes both CEAR and case from cache.
  - Refreshes selected request, unprocessed list, route list.
  - Closes dialog via `oncomplete`.

#### ATTACH_TO_NEW_CASE (`cear-flow-step3-newcase-sv`)
- Officer sees address confirmation and optional public/internal note fields.
- **"Create new case"** button → `path1CreateNewCaseAtProperty`:
  1. If `parcelKey != 0`: loads `PropertyDataHeavy` into `sessProperty` so `ceCaseAddBB` can read it.
  2. Sets `sessionBean.sessCEAR = selectedRequest` so `CECaseAddBB.onAddNewCaseCommitButtonChange` can link the CEAR to the new case.
  3. Appends routing notes to `publicExternalNotes`.
  4. Calls `cear_updateCEAR(selectedRequest, ua, null)` — persists note without status change (the new case creation action, handled by `CECaseAddBB`, will determine final CEAR status via `cecase_insertNewCECase`).
  5. Closes flow dialog; opens `cecase-add-dialog` (`cecase-add-dialog-var`).
- Officer fills the case-add form and clicks "Open Code Enforcement Case":
  - `CECaseAddBB.onAddNewCaseCommitButtonChange`:
    - Reads `sessCEAR`; if parcel keys match, passes it to `CaseCoordinator.cecase_insertNewCECase`, which links the CEAR to the new case automatically.
    - Navigates to the new case view.

#### ATTACH_TO_OCC_PERIOD (`cear-flow-step3-occperiod-sv`)
- Officer navigates to a property's occupancy period to set `sessOccPeriod`, then returns and confirms.
- Direct selection from a period table: `path2AttachToOccPeriodDirect(op)`.
- Or session-based: `path2AttachToOccPeriod(ev)` reads `sessOccPeriod`.
- Both call `CaseCoordinator.cear_connectCEARToOccPeriod(op, cear, ua)`:
  - Validates non-null and muni match.
  - Sets `occPeriodID`, `caseAttachmentTimestamp`, `caseAttachmentUser`.
  - Updates status to `actionRequestOccPeriodStatusCode`.
  - Appends public note; writes to DB; flushes cache.

#### INVALID_REQUEST

> **Changed 2026-09-30 (CEAR-E): requires a real description + two-step confirm.** Officers
> were misusing this route for genuine code-enforcement determinations instead of literal form
> junk (spam, gibberish, abusive text). `path3AttachInvalidMessage` now rejects a blank or
> trivially short `invalidMessage` (minimum ~20 characters) both client-side (inline validation)
> and, per this codebase's "UI check is never the real gate" rule, inside
> `CaseCoordinator.cear_updateCEAR` itself as a route-specific audit guard (throws
> `BObStatusException` if bypassed). A `p:confirmDialog`-based two-step confirm (BB Rule 6 —
> never `onclick="return confirm(...)"`) asks the officer to affirm the request is genuinely
> invalid junk, not a real determination, before committing. Applies identically whether reached
> from a standard, not-at-known-address, or muni-general CEAR — no special-casing.

- `path3AttachInvalidMessage(ev)`:
  - Appends officer's text to `publicExternalNotes` using message bundle header/explanation.
  - `cear_updateCEAR(..., INVALID_REQUEST)` → updates status, persists, flushes.

#### NO_VIOLATION_FOUND (deprecated — legacy data only, see §3.1)

- `path4AttachNoViolationFoundMessage(ev)` still exists and still works for re-routes, but the
  route is no longer offered in `processingRouteList` for any new routing decision (§3.1).
  Structurally identical to `path3AttachInvalidMessage` — free-text note, no confirmation step
  — but a genuine "no violation" finding now belongs inside a real CE case instead.

#### REFERRED_TO_OTHER_DEPARTMENT (added 2026-09-30, CEAR-C tier 1)

- New `path6ReferToOtherDepartment(ev)` method, mirroring `path3AttachInvalidMessage`: a
  free-text note (which department, and why), `cear_updateCEAR(..., REFERRED_TO_OTHER_DEPARTMENT)`,
  then the normal `fireRoutingBlastIfEnabled()` / `CEAR_ROUTED` blast path — no special recipient
  handling in tier 1. Offered for every request shape (standard, not-at-known-address, and
  muni-general).

#### MUNI_GENERAL_ACTION_UNDERWAY / MUNI_GENERAL_ACTION_COMPLETED

Rendered by `cear-flow-step3-munigeneral-sv` when `isCearFlowRouteMuniGeneral()` is true.

- Officer may enter an optional internal note.
- **"Confirm"** button → `path5MuniGeneralAction(ev)`:
  - Appends routing note to the request via `appendRoutingNotesToRequest()`.
  - If `selectedRoute == MUNI_GENERAL_ACTION_UNDERWAY`: calls `cc.cear_setMuniGeneralActionUnderway(selectedRequest, ua)` — status is set to `actionRequestMuniGeneralUnderwayStatusCode`.
  - If `selectedRoute == MUNI_GENERAL_ACTION_COMPLETED`: calls `cc.cear_setMuniGeneralActionCompleted(selectedRequest, null, ua)` — status is set to `actionRequestMuniGeneralCompletedStatusCode`.
  - Refreshes selected request, unprocessed list, route list; closes dialog.
- **"Back to route selection"** button calls `onCEARFlowBackToStep2()` (sets `cearFlowActiveStep = 2`), not `onCEARFlowBackToStep1`, because muni-general has no step 1.

> A muni-general CEAR can also be routed to `INVALID_REQUEST`, in which case it falls through to the standard `cear-flow-step3-closeout-sv` subview (rendered when `isCearFlowRouteNoteAndClose()` is true). The officer enters an optional message, then clicks "Confirm: Invalid request" → `path3AttachInvalidMessage`. The "Back to route selection" button in that subview also calls `onCEARFlowBackToStep2()` so the user returns to step 2, not the property step they never visited.

#### UNPROCESSED (re-route to start)
- `cear_updateCEAR(..., UNPROCESSED)` → resets to initial status code.

---

## 4. Status Lifecycle

All status transitions go through `cear_updateRequestStatus(cear, route)` (now promoted onto
`CaseCoordinator` per CEAR-D, called by `cear_updateCEAR`), which reads the DB status ID from
the resource bundle key stored in `CEARProcessingRouteEnum`.

```
[inserted] → UNPROCESSED (non-terminal)
              ↓
    ┌─────────────────────────────────────────────────────────────────────┐
    │ Property-specific / not-at-known-address / muni-general             │
    │  ATTACH_TO_EXISTING_CASE        → status=existingCase   (terminal)  │
    │  ATTACH_TO_NEW_CASE             → status=newCase         (terminal) │
    │  ATTACH_TO_OCC_PERIOD           → status=occPeriod       (terminal) │
    │  INVALID_REQUEST                → status=invalid         (terminal)│
    │  REFERRED_TO_OTHER_DEPARTMENT   → status=referredOtherDept(terminal)│
    │  NO_VIOLATION_FOUND (deprecated, legacy data / re-route only)       │
    │                                 → status=noViolation      (terminal)│
    ├─────────────────────────────────────────────────────────────────────┤
    │ Muni-general only                                                    │
    │  MUNI_GENERAL_ACTION_UNDERWAY  → status=muniGenUnderway (non-term.) │
    │  MUNI_GENERAL_ACTION_COMPLETED → status=muniGenCompleted (terminal) │
    └─────────────────────────────────────────────────────────────────────┘
              ↑
    Any terminal status can be reset back to UNPROCESSED
    (re-routing: officer selects UNPROCESSED from route list)
    Non-terminal statuses (UNPROCESSED, MUNI_GENERAL_ACTION_UNDERWAY)
    keep the "Process this request" button visible without a reset option.
```

> **Ground-truthed 2026-09-28, fixed 2026-09-30 (CEAR-D).** `cear_updateRequestStatus` used to
> be a bare status-code write with **no automatic internal note** and no single "when was this
> CEAR last routed" timestamp — `caseAttachmentTimeStamp` only ever covered the two case/occ-
> period attachment routes, never `INVALID_REQUEST`, `NO_VIOLATION_FOUND`,
> `MUNI_GENERAL_ACTION_COMPLETED`, or `REFERRED_TO_OTHER_DEPARTMENT`. Fixed by:
> - A new `routingcompletedts timestamp with time zone` column, stamped centrally inside
>   `cear_updateRequestStatus()` whenever `route.isTerminal()` — covering every terminal route
>   (including the two case/occ-period attachment routes, which keep setting
>   `caseAttachmentTimeStamp` separately as before; the two columns answer different
>   questions and are both kept). Never stamped on `UNPROCESSED` (non-terminal — that's the
>   un-resolution, not a resolution).
> - An automatic **re-route note**: if the CEAR's *current* route (resolved the same way
>   `resolveCurrentRoute()` does, now promoted onto `CaseCoordinator`) was already terminal
>   when a new terminal route commits, `cear_updateRequestStatus()` appends an internal note
>   ("Re-routed from `{oldRoute}` to `{newRoute}` by `{officer}`.") automatically, instead of
>   depending on each of the ~7 routing call sites to remember to do it themselves.
> - `routingcompletedts` is exposed in the CEAR dashboard UI (the routed-date line on the CEAR
>   card and the search table — see §7 of the codenforce dev index's CEAR-H doc) and is
>   searchable via `SearchParamsCEActionRequestsDateFieldsEnum.ROUTINGCOMPLETED_TS`.

---

## 5. Cache Management

`CaseCoordinator` holds `ceCaseCacheManager` (Caffeine). CEARs are flushed from cache after:
- Any update to internal fields, status, notes, or property.
- Attachment to a case or occ period (both CEAR and case are flushed).
- Deactivation or abandonment.

`refreshSelectedRequest()` in `CEActionRequestsBB` always fetches a fresh copy from the coordinator + integrator after any mutation.

---

## 6. Email Notification System

CEAR email notifications are handled entirely by `CommunicationCoordinator`. As of 2026-09-28
there are **two structurally separate systems in production side by side**, built five months
apart, each with its own recipient model, gating rules, and content builder. They are not layers
of one pipeline — a single routing action can fire both, independently, in the same request.

| | §6.1 Legacy routing blast (April 2026 MVP) | §6.2 Update-blast system (Phase 12, Sept 2026) |
|---|---|---|
| Entry point | `CEActionRequestsBB.fireRoutingBlastIfEnabled()` → `CommunicationCoordinator.sendCEARRoutingUpdateBlast()` | `CaseCoordinator.cear_dispatchRouteBlast()` / `cecase_dispatchBlastIfConfigured()` → `CommunicationCoordinator.comm_sendCEARUpdateBlast()` |
| Event scope | CEAR routing only | CEAR routing **plus** case-lifecycle events for the CEAR's whole life: NOV sent, violation attached/compliant/nullified/stipcomp-extended, citation status recorded, case closed, case event logged |
| Gating | One BB checkbox (`notifySubscribersOnRouting`), **on** by default | Per-muni, per-event-type JSON settings (`CEARMuniUpdateBlastSettings`), **off** by default for every event type; plus independent officer opt-out and submitter opt-out gates |
| Recipients per call | Broadcasts to the muni's whole staff-subscriber list (`UserEmailSettings.cearSubscribeEnabled`) **+** the requestor | One targeted email per eligible submitter — the external requestor, or (separately) the specific staff user who created that CEAR, if they opted in |
| Content control | Fixed content, split only internal vs. external | 3 detail levels (MINIMAL/STANDARD/FULL — FULL currently clamped to STANDARD at runtime) |
| Unsubscribe | None | Per-recipient opaque opt-out token + link |
| Content builder | `cear_buildRoutingUpdateEmailHTML` | `comm_buildCEARUpdateBlastHTML` |
| Context object | Flat params (`routeName`, `publicNote`, `actingOfficer`, `internalRecipient`) | `CEARUpdateBlastContext` (event type, host case, violation/NOV/citation refs, detail-relevant fields) |
| Maintenance status | **Frozen** — preserved as-is; bugfixes only (§6.4) | Active — new CEAR/case-event-blast work lands here |

---

### 6.1 Legacy Routing Blast (frozen — bugfixes only)

#### 6.1.1 The Two Recipient Pathways

##### Pathway 1 — Raw Requestor Email (anonymous / public submitter)

| Aspect | Detail |
|---|---|
| Storage | `ceactionrequest.requestoremail` — plain `VARCHAR`, no identity backing |
| Object | `CEActionRequest.requestorEmail` (`String`) |
| Opt-in gate | `ceactionrequest.getemailupdates` → `CEActionRequest.isGetEmailUpdates()` |
| Set at | Submission time (public form or internal submit when not submitting as self) |
| Changeability | Frozen to the row — cannot be updated without an UPDATE to the CEAR itself |
| Identity graph | None. No `Human`, no `Person`, no `ContactEmail` object. Just a string captured from the form |

The opt-in confirmation flag (`getemailconfirmation`) is a parallel boolean persisted on the same row; it records whether the submitter checked "send me a confirmation" at submission time. The routing updates flag (`getemailupdates`) is set either by the public submitter, or by the internal officer via the "Subscribe requestor to routing status update emails" checkbox on `cearInternalSubmit.xhtml`.

##### Pathway 2 — Staff Subscriber ContactEmail (identity-backed)

| Aspect | Detail |
|---|---|
| Storage | `useremailsettings.cearsubscribed` (boolean), `useremailsettings.cearcontactemail_emailid` (FK → `contactemail`) |
| Object graph | `UserEmailSettings` → `ContactEmail` → `Human` (full identity graph) |
| Opt-in gate | `UserEmailSettings.cearSubscribeEnabled` (mirrors `cearsubscribed` column) |
| Resolved via | `CommunicationCoordinator.comm_getSubscribedUsersForMuni(muni)` → `SystemIntegrator.getUserEmailSettingsForMuniSubscribers(municode)` |
| Address hydration | `PersonCoordinator.getContactEmail(id)` — live DB lookup at blast time |
| Changeability | Officer updates their `ContactEmail` record independently; no CEAR change needed |
| Identity graph | Full `Human` parent, managed in admin UI |

The key architectural distinction: Pathway 1 is adequate for anonymous public requestors who may have no system account. Pathway 2 gives staff full address-book management independent of any specific CEAR — **it is muni-wide**, not tied to who created any given CEAR. Contrast with §6.2.2's internal-submitter model, which is the opposite: tied to one specific CEAR's creator, not a subscriber list.

#### 6.1.2 Blast Trigger Points

##### Trigger A — New CEAR Confirmation Blast (`sendCEARSubscriptionBlast`)

**When:** Immediately after `CaseCoordinator.cear_insertCEARFirstStage` successfully inserts the CEAR.
**Who receives it:** Pathway 2 only — all staff with `cearsubscribed=true` for the muni.
**Email category:** `EmailCategoryEnum.CEAR_STAFF_SUBSCRIBE`
**Content:** Built by `cear_buildConfirmationEmailHTML` — includes location, concern type, description, requestor contact (suppressed when `anonymityRequested=true`), muni notes (internal submissions only), submission date.
**Non-throwing:** Individual recipient failures are logged to stderr; the insert is never rolled back.

> The requestor confirmation email (sent to the raw email address) is a separate concern and is not currently implemented as a blast — it would be triggered at insert time if desired.

##### Trigger B — Routing Update Blast (`sendCEARRoutingUpdateBlast`)

**When:** After an officer completes a routing action in `cearCentral.xhtml`. Fired by `CEActionRequestsBB.fireRoutingBlastIfEnabled()` when the `notifySubscribersOnRouting` checkbox is checked — **unconditionally for every routing commit**, regardless of any per-muni setting (contrast §6.2.2).
**Who receives it:** Both pathways:
1. All staff subscribers for the muni (Pathway 2).
2. The requestor, **only if** `cear.isGetEmailUpdates() == true` and `requestorEmail` is non-blank (Pathway 1).

**Email category:** `EmailCategoryEnum.CEAR_ROUTING_UPDATE`
**Content:** Built by `cear_buildRoutingUpdateEmailHTML` — includes reference #, submission date, concern type, description, property address, the route name chosen by the officer, any public note entered at routing time, and (internal copy only) the acting officer's identity.
**Non-throwing:** Same per-recipient fault isolation as the subscription blast.

> Because trigger B fires on **every** routing commit with no muni-level off switch, it is the
> blast most munis actually see today for CEAR routing — the Phase 12 system's `CEAR_ROUTED`
> event (§6.2) only starts firing once a muni explicitly turns it on.

#### 6.1.3 Traceability Note

After every routing blast, `CommunicationCoordinator.writeBlastTraceNote()` appends an **internal muni note** to the CEAR (scope `NoteScopeEnum.INTERNAL` — staff-only, never shown on public view) recording the exact outcome:

```
Routing update blast: sent to alice@town.gov [staff]; bob@town.gov [staff]; req@gmail.com [requestor].
Routing update blast: sent to alice@town.gov [staff]. FAILED for: req@gmail.com [requestor].
Routing update blast: no eligible recipients.
```

Addresses are tagged `[staff]` or `[requestor]` to distinguish the two pathways. Any delivery failure is also recorded. This note is non-throwing — a failure to persist it is logged to stderr but does not affect the blast itself or any routing operation. The writer method itself (`writeBlastTraceNote`) is shared with the Phase 12 system (§6.3) — only the label text differs per call site.

#### 6.1.4 Opt-In Summary

| Who | Opt-in mechanism | Where set | Gate |
|---|---|---|---|
| Public submitter | "Send me status updates" checkbox on submission form | `CEActionRequestSubmitBB` | `cear.isGetEmailUpdates()` |
| Internal staff submitter | "Subscribe requestor to routing status update emails" checkbox | `CEARInternalSubmitBB` | `cear.isGetEmailUpdates()` |
| Staff officer | `UserEmailSettings.cearSubscribeEnabled` in admin UI | Admin settings page | `getUserEmailSettingsForMuniSubscribers()` filter |

---

### 6.2 Update-Blast System (Phase 12, Sept 2026 — active development)

A per-municipality-configurable blast system covering every notable event in a CEAR's — and its
host case's — lifecycle, not just routing. Settings, event catalog, detail levels, and opt-out
mechanics are specified in the codenforce dev index at
`docs/subsystems/i_municipality/municearupdatesettings-jul2026.md`; this section summarizes how
it wires into CEAR processing specifically.

#### 6.2.1 Event Catalog & Muni Settings

`CEARUpdateBlastEventTypeEnum` enumerates the blastable events, each independently switchable
per municipality (all **off** by default) via the JSON-typed `updateblastsettings` column,
managed in the muniManage admin page's "CEAR Subscriber Update Blasts" panel
(`MunicipalityManageBB`):

| Event | Fired from |
|---|---|
| `CEAR_ROUTED` | `CaseCoordinator.cear_dispatchRouteBlast()` — same routing commits as legacy Trigger B, but only for **terminal** routes, and only once the muni has this event enabled |
| `NOV_MARKED_SENT` | NOV marked sent (`NoticeOfViolationBB`) |
| `VIOLATION_ATTACHED` | Violation attached to a case |
| `VIOLATION_MARKED_COMPLIANT` / `VIOLATION_NULLIFIED` / `VIOLATION_STIPCOMP_EXTENDED` | Violation batch operations (`CECaseBB`) |
| `CITATION_STATUS_NCM` | Citation status recorded (`CitationBB`) |
| `CASE_CLOSED` | Case closed (`CaseloadActionsBB`, `CECaseBB`) |
| `CASE_EVENT_NCM` | Officer-selected event category logged (`EventBB` / `EventCoordinator`) |

Each enabled event type carries its own `CEARUpdateBlastDetailLevelEnum` (§6.2.3).

#### 6.2.2 Recipients & Gating

Every dispatch resolves recipients from the CEAR(s) attached to the case, then sends one
targeted email per unique eligible address (de-duplicated, normalized) — never a broadcast list:

1. **External requestor** — the CEAR's `requestorEmail`, when non-blank and not opted out
   (`isCEARSubmitterOptedOut`).
2. **Internal submitter** — the staff user who originally created that specific CEAR
   (`CEActionRequest.createdBy`), resolved via `comm_resolveEmailForCEARInternalSubmitter()`,
   sent **only if** `cear.isNotifyInternalSubmitter()==true` (an opt-in captured at submission
   time on `cearInternalSubmit.xhtml`) and not opted out (`isCEARInternalSubmitterOptedOut`).

> **This "internal" concept is unrelated to legacy Pathway 2 (§6.1.1).** Pathway 2 is a muni-wide
> subscriber address book: any staff member can opt in, regardless of which CEARs they touch.
> This system's internal recipient is exactly one person per CEAR — whoever created it — and only
> if that CEAR itself was flagged for it. There is no muni-wide staff broadcast list in this
> system at all.

Every send additionally passes through `CommunicationCoordinator.comm_sendCEARUpdateBlast()`'s
four gates, in order: (1) muni has the event type enabled, (2) the acting officer hasn't opted
this specific blast out, (3) the submitter (external or internal, per above) hasn't opted out,
(4) a delivery address is actually present. Any gate failing returns `null` silently — no email,
no error.

#### 6.2.3 Detail Levels

Each muni/event-type pair configures a `CEARUpdateBlastDetailLevelEnum`:

| Level | Adds |
|---|---|
| `MINIMAL` | Reference #, submission date, the event itself, property address |
| `STANDARD` | + concern type, any public note |
| `FULL` | + affected-violation count — **currently always clamped down to `STANDARD`** at runtime (`comm_clampDetailLevel`) for non-internal submitters; reserved for future use |

#### 6.2.4 Dispatch Call Sites

Two private `CaseCoordinator` dispatchers build a `CEARUpdateBlastContext` and hand it to
`CommunicationCoordinator.comm_sendCEARUpdateBlast()`:

- `cear_dispatchRouteBlast(cear, hostCase, route, publicNote, ua)` — the CEAR-routing path,
  called alongside (not instead of) legacy Trigger B; fires only for terminal routes.
- `cecase_dispatchBlastIfConfigured(eventType, cse, cv, nov, citation, eventDescriptor,
  publicNote, violationCount, officerOptedOut, ua)` — every other case-lifecycle event; iterates
  all CEARs attached to the case and dispatches once per eligible external/internal recipient.

Both are best-effort/non-throwing: a blast failure never affects the primary operation
(routing, closing a case, marking a violation compliant, etc.).

#### 6.2.5 Opt-Out Mechanism

Each CEAR carries independent opaque tokens for its external requestor
(`updateBlastOptOutToken`) and, when applicable, its internal submitter
(`internalSubmitterBlastOptOutToken`). `CaseCoordinator.cear_processOptOutToken(token)` is the
unauthenticated, idempotent public endpoint behind the unsubscribe link embedded in every blast
footer — the token itself is the credential. Legacy blasts (§6.1) have no equivalent; they cannot
be unsubscribed from short of disabling the muni-wide subscriber flag or the routing-blast
checkbox.

#### 6.2.6 Officer Notice Invariant (P1 — ratified 2026-09-30, CEAR-J)

**No blast under this system may ever fire without the acting officer first seeing a
one-click-skippable notice.** This is a hard product invariant, not a per-event-type setting —
it applies identically whether the muni has that event type's blast enabled or disabled, and
there is no admin override, permission, or role that bypasses it. Ratified after an internal
review found the original Phase 12 design would have let a blast go out silently from a couple
of case-lifecycle action buttons with no confirmation step at all.

Mechanics:

- A single composite component, `cearBlastNoticeCC` (`<tt:cearBlastNoticeCC .../>` — verify the
  actual namespace alias in each host file before reuse), renders a small inline banner
  immediately above the commit button for every action that can dispatch a Phase-12 blast: *"A
  status update email may be sent to N recipient(s) for this action"* with a **"Don't send this
  time"** one-click checkbox/toggle that maps straight to the `officerOptedOut` parameter on
  `cecase_dispatchBlastIfConfigured` (§6.2.4) — opting out skips only *this one dispatch*, not
  the muni's setting for the event type going forward.
- The notice renders **unconditionally** once the host action is one of the 9
  `CEARUpdateBlastEventTypeEnum` values, even when the muni currently has that specific event
  type toggled off in `updateblastsettings` — so an officer is never surprised the other
  direction either (toggling it on between page load and commit can't silently start emailing
  with no visible change to the form the officer is looking at).
- **All 9/9 event types confirmed mounted** as of the 2026-09-30 ratification pass: `CEAR_ROUTED`
  (the 3-step routing flow's step-3 execute subviews, §3.4), `NOV_MARKED_SENT`,
  `VIOLATION_ATTACHED`, `VIOLATION_MARKED_COMPLIANT`, `VIOLATION_NULLIFIED`,
  `VIOLATION_STIPCOMP_EXTENDED`, `CITATION_STATUS_NCM`, `CASE_CLOSED`, `CASE_EVENT_NCM` — see
  the codenforce dev index's CEAR-J doc for the exact host-XHTML/line-number audit trail per
  event type.
- Legacy routing blasts (§6.1) are **not** in scope for this invariant — they predate it, are
  frozen (bugfixes only), and already have their own always-visible BB checkbox
  (`notifySubscribersOnRouting`) serving a similar "officer is aware a blast may fire" purpose.

---

### 6.3 Shared Code Between the Two Systems

As of the 2026-09-28 refactor (CEAR-I, codenforce dev index), the two systems share their HTML
**rendering** layer — but nothing about recipients or gating:

- A common set of `CEAR_STYLE_*` inline-style constants on `CommunicationCoordinator` (one
  visual palette for every CEAR email, including the confirmation email of §6.1.2 Trigger A).
- Shared row-builder helpers: `buildCearHeaderBanner` (title + muni name + the "Internal CNF
  user update" banner tag), `buildCearReferenceRow`, `buildCearSubmittedRow`,
  `buildCearPropertyRow`, `buildCearOfficerRow` ("Action taken by"), `buildCearFooterRow`.
- `resolveInternalUserDisplayName`, `buildInquiryContactRowForEmail`,
  `resolvePropertyAddressForEmail`, and the outbound `sendEmail`/`EmailLog` machinery.
- `writeBlastTraceNote` (§6.1.3) — both systems append the same style of internal audit note,
  just with a different label per call site.

This merge was deliberately scoped to presentation only. `sendCEARRoutingUpdateBlast`,
`comm_sendCEARUpdateBlast`, `CearEmailContent`, and `CEARUpdateBlastContext` were left untouched
— the two systems' recipient/gating engines remain intentionally separate (§6.4).

---

### 6.4 Maintenance Policy: Legacy Routing Blast Is Frozen

**The legacy routing blast (§6.1) is preserved as-is going forward and is not a target for new
features.** It stays wired up exactly as built in the April 2026 MVP — same unconditional
broadcast-to-subscribers model, same lack of per-muni settings or unsubscribe link — and will
only be touched again for genuine bugfixes (e.g. a rendering defect shared via §6.3, or a crash).
Any new CEAR- or case-event-blast capability (new event types, new detail-level content, new
opt-out UX, etc.) belongs in the Phase 12 update-blast system (§6.2). A full sunset of the legacy
system (removing it once every muni has migrated its routing-notification needs onto the Phase 12
`CEAR_ROUTED` event) remains an open, undated follow-up — see the codenforce dev index's CEAR-I
doc for the tracking note.

---

## 7. Key Classes at a Glance

| Class | Scope | Responsibility |
|---|---|---|
| `CEARInternalSubmitBB` | `@ViewScoped` | Staff CEAR submission form; owns `workingCEAR` for the duration of the form session |
| `CEActionRequestsBB` | `@ViewScoped` | CEAR dashboard + processing flow; owns `selectedRequest` and routing step state |
| `CECaseAddBB` | (checked via EL) | Case creation dialog; reads `sessCEAR` from session to auto-link new case to CEAR |
| `CaseCoordinator` | `@ApplicationScoped` | All CEAR business logic: insert, update, status change, attachment, muni-general operations; also owns both blast dispatchers (`cear_dispatchRouteBlast`, `cecase_dispatchBlastIfConfigured`) |
| `CEActionRequestIntegrator` | `@ApplicationScoped` | All SQL for CEAR CRUD operations, plus opt-out token lookups (`isCEARSubmitterOptedOut`, `isCEARInternalSubmitterOptedOut`) |
| `CEARProcessingRouteEnum` | Enum | Maps each routing outcome to: DB status key, UI title, dialog widgetVar, update targets, and `isTerminal()` flag. Non-terminal: `UNPROCESSED`, `MUNI_GENERAL_ACTION_UNDERWAY`. Terminal: all others. |
| `CommunicationCoordinator` | `@ApplicationScoped` | Builds + sends all CEAR emails for both blast systems (§6); owns the shared rendering helpers (§6.3) |
| `CEARUpdateBlastContext` | Entity (transient) | Per-send context for the Phase 12 update-blast system: event type, host case, driving violation/NOV/citation, detail-relevant fields, opt-out state |
| `CEARMuniUpdateBlastSettings` | Entity (JSON-backed) | Per-muni, per-event-type enablement + detail level for the Phase 12 system, persisted as `updateblastsettings` JSON |
| `CEARUpdateBlastEventTypeEnum` | Enum | Catalog of blastable events for the Phase 12 system (§6.2.1) — CEAR routing is only one of nine |

---

## See also

- [CEAR dev overview](/dev/subsystems/cear/overview) — front door for this subsystem's dev branch
- [Communication — Developer Notes](/dev/subsystems/communication/overview) — the shared Resend/webhook transport layer this subsystem's emails ride on
- [Subsystem registry](/system/subsystem-registry) entry #20

## Back to: [CEAR dev overview](/dev/subsystems/cear/overview)
