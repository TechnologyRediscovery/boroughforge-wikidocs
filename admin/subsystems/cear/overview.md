---
title: Code Enforcement Action Requests (CEAR) — Admin Guide
description: Configuring CEAR routing notifications and the per-event update-blast system
published: true
date: 2026-09-30T00:00:00.000Z
tags: subsystem:cear, audience:admin, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Code Enforcement Action Requests (CEAR) — Admin Guide

A **Code Enforcement Action Request (CEAR)** is a concern or complaint submitted to your
municipality's code enforcement office — either by a member of the public through the
unauthenticated public form, or by staff on a caller's behalf. Officers triage and route every
CEAR from a dashboard, and the system can email the submitter and/or staff as that happens.

As a system administrator, your configuration surface for CEAR is entirely about **who gets
emailed, when, and with how much detail.** There are two separate, independently-running email
systems layered on top of CEAR — you don't have to choose one; both can be active at once, and
they serve different purposes.

## Topics

- [Configuring CEAR update-blast notifications](/admin/subsystems/cear/configuring-update-blast-notifications) —
  the full walkthrough of the "CEAR Subscriber Update Blasts" panel: the 9 event types, the 3
  detail levels, and what each does.

## The two email systems, at a glance

| | Legacy routing blast | Update-blast system (recommended) |
|---|---|---|
| What it covers | Only the moment an officer routes a CEAR | Routing **plus** every notable event afterward in the CEAR's host case (violation attached, NOV sent, case closed, etc.) — see the task page for the full list of 9 event types |
| Who configures it | Nobody — it's always on by default; an officer can uncheck a box on their own submission form | You, per event type, per municipality |
| Default state | **On** | **Off** for every event type until you turn it on |
| Who it emails | The whole municipality's subscribed staff list, plus the requestor | One targeted email per eligible recipient — the requestor and/or the specific staff member who logged the original request, if they opted in |
| Unsubscribe | None | Every email includes a working, no-login-required unsubscribe link |
| Where you manage it | Nothing to manage — it's a fixed behavior | Muni Tools → Municipality Manager → **"CEAR Subscriber Update Blasts"** panel |

<!-- SCREENSHOT NEEDED: The muniManage page with the "CEAR Subscriber Update Blasts" panel
visible in its collapsed state, showing where it sits relative to other municipality
configuration panels. -->

## What you control

- **Whether each of the 9 blastable event types is on or off** for your municipality — every
  one defaults to off, so nothing emails anyone until you deliberately enable it.
- **How much detail each enabled event type's email includes** — a plain-language MINIMAL
  summary, or a STANDARD level that adds specifics (the concern type, any public note, an
  itemized list for batch violation actions).
- Nothing about *whether an officer can skip a given blast* — that's not configurable. See
  the guarantee below.

## The one thing you cannot turn off

**Every blastable action always shows the acting officer a visible notice with a one-click
"don't send this time" option, no matter what you've configured.** This is a deliberate,
non-negotiable product guarantee (ratified 2026-09-30) — not a bug and not a setting you can
change. You decide whether an event type is *available* to send at all; the officer in front
of the specific case always decides whether *this one* actually goes out. There is no
administrative way to force a blast through without that notice, and no municipality setting
removes it.

## Cautions and risks

- **The legacy routing blast has no unsubscribe link.** If a requestor or a subscribed staff
  member wants to stop receiving routing emails, the only options are: the requestor's own CEAR
  submission didn't opt in to begin with, or a staff member removes themselves from the
  muni-wide subscriber list in their own account settings. There is no per-blast opt-out for
  this system — that's exactly why the update-blast system exists.
- **Turning on an event type emails every eligible recipient going forward, immediately** —
  there's no staged rollout or preview mode. Consider starting with one or two event types
  (e.g. just `CEAR routed by officer`) before enabling the full set.
- **Detail level is per event type, not global.** You can run `STANDARD` for one event and
  `MINIMAL` for another on the same municipality; there's no single "detail level for
  everything" switch.
- **A referral to another department (new as of 2026-09-30) reuses the "CEAR routed by
  officer" event type** — it does not need or have its own toggle. If you've enabled that
  event type, referrals will also generate an update email like any other terminal routing
  decision.

## See also

- [CEAR user guide](/users/subsystems/cear/overview) — the officer-facing routing/triage side
  this configuration feeds into.
- [CEAR public guide](/public/subsystems/cear/overview) — what the public sees when they submit
  a request or receive one of these emails.
- [Developer notes — Email Notification System](/dev/subsystems/cear/cear-logic#6-email-notification-system) —
  the full technical architecture of both blast systems.

Back to: [hub page](/system/subsystems/cear) · [subsystem registry](/system/subsystem-registry) entry #20
