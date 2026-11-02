---
title: Processing and routing a CEAR
description: The 3-step routing flow and every route available, including the September 2026 changes
published: true
date: 2026-11-02T00:00:00.000Z
tags: subsystem:cear, audience:staff, type:howto
editor: markdown
dateCreated: 2026-09-30T00:00:00.000Z
---

# Processing and routing a CEAR

Every new CEAR lands on the dashboard (**CE → Action Requests**) unprocessed. Routing it walks
you through a 3-step dialog: confirm the property, pick a route, then execute that route.

<!-- SCREENSHOT NEEDED: A CEAR card on the dashboard with the "Process this request" button
visible. -->

## Step 1 — Property

Click **Process this request** on any card (or **re-route this request** on an already-routed
one) to open the dialog. **As of September 2026, every request type starts here — including
municipal-general requests.** If the request has no property, you'll see "No property linked"
along with the property search box.

- Search for and select the correct property, then click **"Property is correct, proceed to
  routing"**.
- For a genuinely address-less muni-general concern, click **"This is a general request (no
  property), proceed to routing"** instead — no property search required.
- If you attach a real property to what started as a muni-general request, it's automatically
  reclassified as a standard request going forward.

<!-- SCREENSHOT NEEDED: Step 1 of the routing dialog, showing the property search box and both
the "proceed to routing" and "general request, no property" buttons. -->

## Step 2 — Route selection

Pick a route from the list. Which routes you see depends on the request:

| Request shape | Routes offered |
|---|---|
| Muni-general | Action underway, Action completed, Invalid request, Referred to another department |
| Not at a known address | Invalid request, Referred to another department |
| Property-linked, property already has open cases | Attach to existing case, Attach to new case, Attach to occupancy period, Invalid request, Referred to another department |
| Property-linked, no open cases yet | Attach to new case, Attach to occupancy period, Invalid request, Referred to another department |

Click **Continue to execution** to move to step 3, or **Back to property** to return to step 1.

<!-- SCREENSHOT NEEDED: Step 2 of the routing dialog, showing the route list for a standard
property-linked request. -->

## Step 3 — Execute

What you see depends on the route you picked:

- **Attach to existing case** — pick a row from the property's list of open code enforcement
  cases and click **Attach**.
- **Attach to new case** — confirm the address, add an optional note, click **Create new
  case**, then fill out the usual new-case form.
- **Attach to occupancy period** — select the occupancy period the concern belongs to.
- **Invalid request** *(changed September 2026)* — write a short explanation of why the request
  is invalid, then confirm through a two-step "are you sure" dialog before it commits. A
  genuinely blank or very short explanation is rejected — this route is reserved for literal
  junk submissions (spam, gibberish, abusive text), not real determinations. If you're closing
  out a real concern that just didn't turn up a violation, open a case for it instead so the
  finding is properly logged.
- **Referred to another department** *(new September 2026)* — a plain closeout for requests
  that belong somewhere else entirely (e.g. a public-works issue that isn't a code violation).
  Write a note on which department and why, then confirm. No property or case is required.
- **Muni-general action underway / completed** — leave an optional internal note and confirm.
  "Underway" keeps the request open (non-terminal); "completed" closes it out.

<!-- SCREENSHOT NEEDED: Step 3 for the "Referred to another department" route, showing the
free-text note field and confirm button. -->

> **"No violation found" has been retired as a routing option.** You may still see it on older
> requests that were already closed out this way, and it's still available as a re-route target
> if you need to match old behavior, but it's no longer offered for new routing decisions. A
> genuine "no violation" finding should now go through a real code enforcement case (attach to
> new/existing case) so the determination is properly logged with an inspection, rather than a
> one-click dashboard closeout.

## Re-routing

Any already-routed (terminal) request can be re-routed — an **UNPROCESSED** option appears in
step 2 as an escape hatch, resetting it back to the top of your queue. As of September 2026,
re-routing a request that was already terminal automatically leaves an internal note recording
the change (which route it moved from and to, and who did it) — you don't need to write that
note yourself.

## The officer notice — you see it before an update email goes out

Depending on your municipality's configuration, committing a route (or several other
case-lifecycle actions later on) can send an automatic status-update email to the requestor
and/or the staff member who logged the request. **Whenever that's possible, you'll see an
inline notice right above the commit button** — *"N CEAR subscriber(s) will receive an update
email when this action is …"* — with a **"Skip — do not send update email for this action"**
checkbox and an optional public-note box. The notice appears only when the municipality has that
event turned on and at least one eligible recipient exists. Skipping affects only that one action.

The routing dialog also has an older, separate checkbox — **"Notify action requestor and/or
subscribers of this routing action via email if they requested updates"** — which is on by
default. It controls the legacy routing email only; uncheck it if you don't want that one sent.
For help deciding what your municipality should enable, see
[Choosing your CEAR update-email settings](/users/subsystems/cear/choosing-update-email-settings).

<!-- SCREENSHOT NEEDED: The officer notice banner with its "Skip — do not send update email for
this action" checkbox, directly above a route's commit button. -->

## See also

- [Choosing your CEAR update-email settings](/users/subsystems/cear/choosing-update-email-settings)
- [Triage dashboard and priority chips](/users/subsystems/cear/triage-dashboard-and-priority-chips) —
  reading the color-coded age indicators before you start routing.
- [Submitting a CEAR on behalf of a caller](/users/subsystems/cear/submitting-a-cear-on-behalf-of-a-caller)
- [CEAR admin overview](/admin/subsystems/cear/overview) — how the notification behavior
  mentioned above gets configured.
- [Developer notes](/dev/subsystems/cear/cear-logic#3-routing-cearcentralxhtml--ceactionrequestsbb) —
  full technical detail on the routing flow and status lifecycle.

Back to: [CEAR user guide](/users/subsystems/cear/overview) · [hub page](/system/subsystems/cear)
