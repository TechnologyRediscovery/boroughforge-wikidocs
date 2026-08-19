---
title: Mail-Merge Token Implementation
description: LetterTokenType registry internals and LetterHtmlRenderer's two-pass substitution architecture
published: true
date: 2026-08-19T00:00:00.000Z
tags: subsystem:letters, audience:dev, type:architecture
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Mail-Merge Token Implementation

Dev-depth counterpart to [Mail-merge token reference](/admin/subsystems/letters/mail-merge-token-reference)
(the admin-facing catalog of what each token does). This page covers how the token registry
and substitution engine are actually built.

## `LetterTokenType` — the canonical registry

Every token recognized anywhere in the subsystem is one enum constant, carrying:

- **`marker`** — the literal `<<TOKEN>>` string embedded in template HTML.
- **`displayLabel`** — human-readable name for the reference-table UI.
- **`category`** — `LETTER`, `RECIPIENT`, `SENDER`, `MUNI`, `PROPERTY`, `VIOLATIONS`, `PHOTOS`.
- **`valueType`** — structural shape of the substituted output: `SCALAR_TEXT`,
  `SCALAR_BLOCK`, `POSITIONED_BLOCK` (the addressee window block — absolutely positioned so it
  lines up inside an envelope window), `IMAGE_TAG`, `TABLE_BLOCK`, or `IMAGE_BLOCK`.
- **`editableOnPureClone`** — true when the *form field driving this token* stays editable in
  `LetterFlowMode.PURE_CLONE`. True only for the three recipient tokens
  (`RECIPIENT_NAME`, `MAILING_ADDRESS`, `RECIPIENT_NAME_AND_ADDRESS`) and the two date tokens
  (`DATE_OF_RECORD`, `ACTION_DUE_DATE`) — the whole point of a pure clone is sending the
  identical wording to a different recipient on a different date; everything else resolves
  from context that shouldn't change per recipient. See
  [Clone/copy architecture](/dev/subsystems/letters/clone-copy-architecture).
- **`applicableParentTypes`** (`Set<LetterParentType>`) — which parent types this token is
  meaningful for. `UNIT_LIST` is `EnumSet.of(PARCEL)` only; `VIOLATIONS` is
  `EnumSet.of(CECASE)` only; every other token is `EnumSet.allOf(LetterParentType.class)`.

```java
public boolean isApplicableTo(LetterParentType parentType) {
    if (parentType == null) {
        return true;   // template-preview context — render everything
    }
    return applicableParentTypes != null && applicableParentTypes.contains(parentType);
}
```

Passing `null` (used by the template-authoring preview, which has no specific parent) treats
every token as applicable — the preview always shows the full picture regardless of which
parent type the template will eventually be used with.

### `isPresentIn` — the dual-form (escaped/literal) check

```java
public boolean isPresentIn(String html) {
    if (html == null) return false;
    if (html.contains(marker)) return true;
    String escapedMarker = marker.replace("<", "&lt;").replace(">", "&gt;");
    return html.contains(escapedMarker);
}
```

This checks **both** the literal `<<TOKEN>>` form and its HTML-entity-escaped
`&lt;&lt;TOKEN&gt;&gt;` form. The reason: the rich-text editor (`p:textEditor`/Quill)
HTML-escapes literal `<`/`>` characters typed as plain text, so a token typed by hand into the
editor is persisted in its **escaped** form even though it displays identically to the literal
form on screen. `LetterHtmlRenderer.replaceToken` performs the same dual-form check at
substitution time — a token stored either way still resolves correctly.

## `LetterHtmlRenderer` — two-pass substitution

Stateless (despite living in the `application` package, it is **not** a JSF backing bean —
just a plain `Serializable` utility class). Two public entry points:

- **`generatePreviewHtml(LetterTemplate, LetterRenderContext)`** — live preview during
  template authoring. May be called with dummy/placeholder context data
  (`LetterCoordinator.letter_buildDummyRenderContext`). Returns
  `"<p><em>No template text defined.</em></p>"` if the template or its text is null.
- **`generateFinalHtml(Letter, LetterRenderContext)`** — called **exactly once**, at
  finalization. The result is stored on `letter.renderedHtml` and hashed into
  `letter.renderedHtmlSha256` for later tamper detection (surfaced as the "INTEGRITY WARNING"
  banner in the letter details dialog if the hash ever stops matching).

Both funnel through the same two-pass pipeline:

```java
html = substituteScalarTokens(html, letter, ctx);   // pass 1
html = substituteBlockTokens(html, ctx);            // pass 2
```

### Pass 1 — scalar tokens

Every single-value token (recipient/sender/muni/property fields) is replaced via a
`replaceToken(html, marker, value)` helper. Two tokens get special gating logic rather than a
flat substitution:

- **`<<UNIT_LIST>>`** — gated by `LetterTokenType.UNIT_LIST.isApplicableTo(ctx.getParentType())`.
  When applicable and unit identifiers exist, they're joined with `", "`; when applicable but
  empty, or not applicable at all (non-`PARCEL` letters), the token is stripped to an empty
  string rather than left in the output.
- **`<<DATE_OF_RECORD>>` / `<<ACTION_DUE_DATE>>` / `<<REFERENCE_NUMBER>>`** — these come from
  the `Letter` object directly (not the render context), since they're properties of the
  letter record itself, not the recipient/sender/property context.

### Pass 2 — block tokens

- **`<<VIOLATIONS>>`** — gated by `LetterTokenType.VIOLATIONS.isApplicableTo(ctx.getParentType())`
  (`CECASE` only); stripped to empty for every other parent type.
- **`<<PHOTOS>>`** — always attempted (no gating), calling `buildBlock_Photos(...)`.

### `buildBlock_Violations` — the III.D non-tabular redesign

Originally a 3-column `<table>`. Replaced (III.D) with a non-tabular **stack** of entries —
one `<div class="letter-violation-item">` per violation, containing:

1. A bold ordinance header + findings line.
2. An optional italic full-ordinance-text line (only when
   `lcv.isIncludeordinancetext()` and text is present).
3. An optional compliance-date line (only when `lcv.isIncludestipcompdate()` and a date is
   set).

**Why:** the old table's Findings column was always cramped, and 3-column tables don't lay
out reliably in openhtmltopdf. The stack markup is deliberately reused **verbatim** for both
the browser preview (`style.css`) and the generated PDF (`letter-print.css`) — same HTML, two
stylesheets — so the two rendering paths stay visually identical, which is the whole fidelity
goal behind storing `renderedHtml` once at finalization rather than re-rendering per view.

Violation *photos* are **not** rendered inline inside this block — they're collected
separately into the `<<PHOTOS>>` appendix instead (next section), so the officer's photo-size
choice and page-break behavior apply uniformly to every photo regardless of which violation it
came from.

### `buildBlock_Photos` — the paginated photo appendix (II.G)

Draws from two sources into a single flat list of "cards":

1. **Violation-attached photos** — each `LetterCodeViolation` whose
   `isIncludeviolationphoto()` is true contributes every `BlobLight` from its backing code
   violation's blob list, captioned with the violation's header + findings text.
2. **Generic letter-wide photos** (`LetterPhotoDoc`, not tied to any violation) — captioned
   with photo ID only, since the stateless renderer has no blob metadata available for these.

Cards are then chunked into per-page `<div>` wrappers based on the officer's **photo display
size** choice (Small/Medium/Large → a fixed photos-per-page count, resolved by
`resolvePhotosPerPage`/`resolvePhotoGridClass`) — chunking into explicit page-wrapper `<div>`s
(rather than relying on CSS grid reflow) is what makes `page-break-inside:avoid` /
`page-break-after` behave predictably in openhtmltopdf. The whole appendix always starts on a
fresh page (`page-break-before:always` on `.letter-photo-attachments`) — attached photos never
share a page with the letter's own text body.

See also: [Distribution channels and webhooks](/dev/subsystems/letters/distribution-channels-and-webhooks),
[Clone/copy architecture](/dev/subsystems/letters/clone-copy-architecture),
[PDF & document encoding primer](/dev/subsystems/letters/pdf-encoding-primer).

Back to: [Letters & Emailing — Developer Notes](/dev/subsystems/letters/overview)
