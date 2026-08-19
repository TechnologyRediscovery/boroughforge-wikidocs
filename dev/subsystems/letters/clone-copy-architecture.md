---
title: Clone/Copy Architecture
description: LetterFlowMode, the mode-chooser dialog, and the nested-form HTML5 parsing bug that once broke it
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:dev, type:architecture
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Clone/Copy Architecture

Cloning/copying a finalized letter (Phase 11 v2) is driven by a single enum,
`LetterFlowMode`, that the same 4-step flow dialog (`letterFlow.xhtml`) checks throughout to
decide what's locked at each step.

## `LetterFlowMode`

```java
public enum LetterFlowMode {
    NEW_LETTER("New letter", false, false),
    PURE_CLONE("Pure clone — exact letter", true, true),
    EDITABLE_COPY("Editable copy", false, true);
    // (label, textLocked, cloneMode)
}
```

| Mode | `textLocked` | `cloneMode` | Behavior |
|---|---|---|---|
| `NEW_LETTER` | false | false | Normal creation path — all 4 steps fully editable, starts at Step 1. |
| `PURE_CLONE` | true | true | Step 3's `p:textEditor` is replaced by a read-only HTML view. Writes `letter.cloneof_letterid`, making the identical wording provable later (court-defensible). Only recipient, address, and dates are editable. |
| `EDITABLE_COPY` | false | true | Step 3 shows the normal editor, pre-filled from the source letter. Does **not** write `cloneof_letterid` — appends a "based on" note instead. Fully independent letter. |

`cloneMode` (true for both clone variants) drives: skipping Step 1 (there's no template to
choose — the source letter supplies everything), and showing the source-letter info banner on
Step 2 ("Source: Letter #X" / "Based on: Letter #X").

`textLocked` is checked in exactly one place — Step 3's conditional rendering
(`letterFlowBB.flowMode.name() == 'PURE_CLONE'` vs. not) — everything else about "what's
editable" falls out of which fields are bound to enabled vs. read-only components in the
XHTML, not a separate permission check per field.

`LetterTokenType.editableOnPureClone` is the token-level counterpart: it flags which
mail-merge fields' *driving form controls* remain editable in `PURE_CLONE` mode (recipient
tokens and the two date tokens — see the
[mail-merge token implementation](/dev/subsystems/letters/mail-merge-token-implementation)
doc). The officer never edits a token string directly; they edit the underlying field (the
date picker, the recipient picker), and the token re-substitutes at render time.

## The mode-chooser dialog

Clicking **clone / copy** (from the letter table row, the letter-details dialog's Letter
tools panel, or Step 4 of the flow) opens a **mode chooser** dialog
(`letter-mode-chooser` in `letterTableCC.xhtml`) with two side-by-side panels — **Pure
Clone** and **Editable Copy** — each a `p:commandButton` that calls
`letterFlowBB.onSelectFlowMode(...)` to stage the chosen mode, followed by a **Continue**
button (disabled until a mode is actually chosen) that calls `onCloneContinue` and opens the
main flow dialog already on Step 2.

## The nested-`<form>` bug (III.G)

The mode-chooser dialog's inner content is an `h:panelGroup`, deliberately **not** an
`h:form` — this was the fix for a real, previously-shipped bug. The relevant comment, kept
in `letterTableCC.xhtml` itself:

> NOT an `h:form` on purpose, every calling page (`ceCaseLetters.xhtml`,
> `occPeriodLetters.xhtml`, `parcelLetters.xhtml`) already wraps this whole composite in its
> own outer `h:form`. A nested `<form>` here is invalid HTML; browsers silently drop the
> nested `<form>` START TAG per the HTML5 parsing spec (a form element pointer already set =
> ignore), so `document.getElementById(...:letter-mode-chooser-form)` never matched anything
> and every ajax `update=` targeting this id silently no-opped; this was the actual root
> cause of "clone / copy dialog dead on click." A `panelGroup` renders as a plain `div`, is
> unaffected by nested-form dropping, and keeps the same id so no `update=` references
> elsewhere needed to change.

**Why this matters beyond this one dialog:** any PrimeFaces composite component embedded
inside a page that already has its own outer `h:form` (which is nearly every page in this
app, per the "one form per page" JSF convention) must not declare a second `h:form` internally
if the browser needs to actually locate an element by id inside it. The HTML5 spec's "form
element pointer" rule silently drops the second `<form>` **tag** (not its children) the moment
one is already open on the page — there's no parse error, no console warning, nothing to
signal it happened. The symptom is exactly what shipped here: the dialog *opens* (PrimeFaces
JS widget lifecycle doesn't need the form), but any `update=` targeting an id inside it
silently no-ops, because the DOM element the JSF/ajax runtime expects to update by id was
never actually created as a child of a `<form>` element the browser recognizes. Use
`h:panelGroup layout="block"` instead when a composite embedded in an existing-form page needs
a stable, updatable container id.

The full bug writeup and fix history live in the codenforce repo's engineering scratch space
at `docs/subsystems/letters+emailing/III-G-clone-copy-fixes.md` (not part of this published
docs site — see this subsystem's [overview](/dev/subsystems/letters/overview) for how that
folder relates to these pages).

Back to: [Letters & Emailing — Developer Notes](/dev/subsystems/letters/overview)
