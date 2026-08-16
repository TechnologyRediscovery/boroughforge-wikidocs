#!/usr/bin/env bash
# =============================================================================
# Script : helpmap/audit-users-coverage.sh
# Purpose: Inventory every markdown page under users/, report whether each one
#          already has a stable-ID mapping (live or `# TODO`) in
#          helpmap/_redirects, and propose a deterministic stable ID for any
#          page that doesn't yet have one.
#
# Usage  : helpmap/audit-users-coverage.sh [--missing-only]
#
# This does not write anything — it's a read-only audit. Copy proposed IDs
# into helpmap/_redirects by hand (live line if the page is `published: true`,
# `# TODO <id>  (stub — not yet published)` if it's `published: false`), same
# "never guess, verify against the real tree" rule as the rest of this file.
# -----------------------------------------------------------------------------
# ID convention for IDs *this script* proposes (new "full coverage" IDs — the
# original 21 hand-picked SL.0 IDs at the top of _redirects are untouched and
# follow their own older, more thematic naming):
#   users/index.md                     -> users-home            (one-off)
#   users/basics/<file>.md              -> basics-<file>
#   users/subsystems/<slug>/overview.md -> <slug>-overview
#   users/subsystems/<slug>/<file>.md   -> <slug>-<file>, or just <file> if
#                                          <file> already starts with
#                                          "<slug>-" (avoids a doubled prefix,
#                                          e.g. property/property-groups.md
#                                          stays "property-groups", not
#                                          "property-property-groups")
# =============================================================================
set -euo pipefail
#   │││ └─ pipefail: a failure anywhere in a pipeline fails the whole pipeline
#   ││└─── -u: reference to an unset variable is an error
#   │└──── -e: any non-zero exit from a command ends the script immediately
#   └───── set: bash builtin for toggling these shell behavior options

# Run from the repo root regardless of the caller's cwd, since paths below are
# repo-relative (dirname "$0" resolves to helpmap/, so ".." is the repo root).
cd "$(dirname "$0")/.."

REDIRECTS="helpmap/_redirects"
missing_only=0
[[ "${1:-}" == "--missing-only" ]] && missing_only=1

# Applies the ID convention documented above to one page's path (relative to
# users/, extension stripped — e.g. "subsystems/property/parcel-info").
# Prints the proposed stable ID on stdout.
propose_id() {
  local relpath="$1"
  case "$relpath" in
    index)
      echo "users-home"
      ;;
    basics/*)
      echo "basics-${relpath#basics/}"
      ;;
    subsystems/*/overview)
      local slug="${relpath#subsystems/}"
      slug="${slug%/overview}"
      echo "${slug}-overview"
      ;;
    subsystems/*/*)
      local rest="${relpath#subsystems/}"
      local slug="${rest%%/*}"      # everything before the first remaining '/'
      local file="${rest#*/}"       # everything after it
      if [[ "$file" == "${slug}-"* ]]; then
        echo "$file"
      else
        echo "${slug}-${file}"
      fi
      ;;
    *)
      echo "UNKNOWN-PATTERN(${relpath})"
      ;;
  esac
}

printf '%-8s %-72s %-6s %s\n' "PUBLISH" "WIKI PATH" "MAPPED" "PROPOSED ID (if unmapped)"
printf '%-8s %-72s %-6s %s\n' "-------" "---------" "------" "-------------------------"

# -print0 / -d '' / -z throughout: NUL-delimited instead of newline-delimited,
# so filenames are read safely even in the (currently hypothetical) case one
# contains a space or newline.
while IFS= read -r -d '' file; do
  relpath="${file#users/}"
  relpath="${relpath%.md}"
  path="/users/${relpath}"
  published=$(awk -F': ' '/^published:/{print $2; exit}' "$file")

  # grep -F: literal substring match, not regex — page paths contain no
  # regex metacharacters we'd need, but "-F" avoids surprises either way.
  if grep -qF -- "$path" "$REDIRECTS" 2>/dev/null; then
    mapped="yes"
    proposed="-"
    [[ $missing_only -eq 1 ]] && continue
  else
    mapped="NO"
    proposed=$(propose_id "$relpath")
  fi

  printf '%-8s %-72s %-6s %s\n' "$published" "$path" "$mapped" "$proposed"
done < <(find users -type f -name '*.md' -print0 | sort -z)
