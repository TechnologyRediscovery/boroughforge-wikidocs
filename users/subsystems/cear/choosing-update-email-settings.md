---
title: Choosing your CEAR update-email settings
description: A short guide for code officers and town managers on which CEAR update emails to turn on, and how much detail they should show
published: true
date: 2026-11-02T00:00:00.000Z
tags: subsystem:cear, audience:staff, type:howto
editor: markdown
dateCreated: 2026-11-02T00:00:00.000Z
---

# Choosing your CEAR update-email settings

When someone files a Code Enforcement Action Request (CEAR) with an email address, CodeNforce
can email them as their request moves forward: when it's routed, when a notice of violation
goes out, when the case closes, and so on. **Nothing is emailed until your municipality turns
a given event on** — every event starts off. This page helps you decide which to turn on.

Your system administrator flips the switches (see
[Configuring CEAR update-blast notifications](/admin/subsystems/cear/configuring-update-blast-notifications)).
You — the town manager or lead officer — decide what they should be.

## The guarantee that makes this low-risk

If an email is about to go out for something you're doing, **you will see a notice right above
the commit button** — *"N CEAR subscriber(s) will receive an update email when this action is
…"* — with a **"Skip — do not send update email for this action"** checkbox. Check it and that
one email doesn't go out. No setting removes this notice, and if nobody would receive an email
the notice simply doesn't appear. (One known exception: emails triggered by a case event the
system creates automatically — see "Don't double up" below.)

<!-- SCREENSHOT NEEDED: The officer notice banner (cearBlastNoticeCC) above a commit button,
showing the recipient count, the skip checkbox, and the optional public-note box. -->

People can also unsubscribe using the link in the email footer, after which they get no further
update emails about that request.

## Decision 1: which events?

Pick a column as your starting point. You can add events later; turning one on takes effect on
the very next matching action.

| Event | Cautious | Typical | Open |
|---|:---:|:---:|:---:|
| CEAR routed by officer — "we've looked at your concern and here's what happened" | ✅ | ✅ | ✅ |
| Case closed | ✅ | ✅ | ✅ |
| Notice of violation sent | | ✅ | ✅ |
| Violation marked compliant | | ✅ | ✅ |
| Code violation recorded | | | ✅ |
| Compliance date extended | | | ✅ |
| Violation nullified | | | |
| Event logged (officer-selected category) | | | ✅ |
| Citation status recorded | | | ✅ |

**Why this order:** routing and closing tell the person who raised the concern that *something
happened*, which is what most people want and costs you almost nothing. The later columns tell
them progressively more about the enforcement itself — useful for transparency, but also more to
explain if a neighbor dispute is involved. "Violation nullified" is usually a correction, not
news, so most towns leave it off.

> Two events need an extra step. **Event logged** only emails for event categories that have
> *Notify Case Monitors* switched on, and **Citation status recorded** only emails for citation
> statuses flagged *Notify CEAR case monitors*. Turning the row on is necessary but not
> sufficient. Your administrator sets those flags — keep them to categories and statuses an
> officer picks by hand.

## Decision 2: how much detail?

Set per event. There are really only two choices for people outside your office:

| Level | The email says |
|---|---|
| **MINIMAL** | That an update happened, what it was in a sentence, the property address, the reference code, and your office's contact details (if configured). **Any note you type is not included.** |
| **STANDARD** | Everything in Minimal, plus the concern type and your **public note** if you wrote one. |
| FULL | Same as Standard for the public. It only adds an "items affected" count on emails to the staff member who logged the CEAR. |

**Rule of thumb:** use **STANDARD** wherever you want officers to be able to add a short
plain-language note ("Inspection is scheduled for Tuesday"), and **MINIMAL** where a bare
heads-up is enough. If you choose MINIMAL, tell your officers — the note box still appears but
the note won't be sent.

## Things to know before you turn events on

- **Anyone with an email on the request can receive these**, unless they've unsubscribed. The
  older routing email respects the "send me updates" box from the submission form; this newer
  system works from the email address on the request.
- **Staff-submitted requests:** the officer who logged a request on someone's behalf gets copies
  too, but only if they asked for them when they logged it.
- **Don't double up.** Some actions (recording a citation status, for example) also create an
  automatic case event behind the scenes. If that event's category has *Notify Case Monitors*
  on, the one action can send two emails, and the second has no notice or skip box. Keep that
  flag off for any category the system creates for you.
- **The old routing email is separate and on by default.** When you route a CEAR the dialog has a
  "Notify action requestor and/or subscribers…" checkbox. It's independent of everything on this
  page.

## What officers do day to day

1. Do the action as usual.
2. If the notice appears, read the recipient count. Leave it alone to send; check **Skip** to
   hold the email back this once (a sensitive case, or the person already called).
3. Add a short public note only if your municipality uses STANDARD for that event.

## See also

- [Processing and routing a CEAR](/users/subsystems/cear/processing-and-routing-a-cear)
- [Configuring CEAR update-blast notifications](/admin/subsystems/cear/configuring-update-blast-notifications) — for your system administrator
- [CEAR user guide](/users/subsystems/cear/overview)

Back to: [CEAR user guide](/users/subsystems/cear/overview) · [hub page](/system/subsystems/cear)
