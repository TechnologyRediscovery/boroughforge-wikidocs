---
title: Isolating a Single New File to Its Own Branch (git restore --staged, not stash)
description: Procedure for splitting one staged/untracked file out of a mixed commit and moving it to a new branch, with verification steps. Supersedes an earlier stash-pathspec draft that was empirically found unsafe — see the correction note.
published: true
date: 2026-08-31
tags: git, restore, branching, workflow, corrected
editor: markdown
dateCreated: 2026-08-31
---

> **Correction, same day:** the original version of this record used `git stash push -- <pathspec>` to isolate the file. In practice, `git stash show --name-only` on that stash entry listed all 14 changed files, not just the one pathspec target. Root cause, confirmed by the observed behavior below: `git stash push` **always** creates a full snapshot commit of the entire index and working tree at the moment it runs — the pathspec argument only controls which paths get reverted from the working directory and index afterward, it does not filter what gets recorded into the stash object. Popping that stash later, after the other 8 files had already been committed to the source branch, risked git trying to reapply already-identical changes on top of them — a needless conflict surface. The procedure below replaces the stash step with `git restore --staged`, which touches only the specified path's index entry and carries no such risk.

# Situation

On `feat/letters-logdistributionevent`, working-tree changes had accumulated across two unrelated efforts:

- Eight files belonging to the letters/logdistribution work (patches, docs, Java sources, XHTML) — correctly scoped to this branch.
- One new, untracked file — `docs/subsystems/person/PL-3-person-to-person-link-spec.md` — a spec for unrelated person-to-person linking work that belongs on a branch that doesn't exist yet: `feat/person-person-personlinks`.

`git add .` had already been run twice, so by the time this was addressed, the new file was sitting in the index as an `A` alongside the eight `M` entries. Goal: split the new file out, commit the rest to the current branch, then carry the new file over to a fresh branch as its first commit.

# Core Commands

```bash
# 1. Unstage ONLY the new spec file — its index entry is reset to HEAD (nonexistent),
#    leaving every other staged file's index entry untouched
git restore --staged docs/subsystems/person/PL-3-person-to-person-link-spec.md

# 2. Verify the split — see footnote [^verify]
git status --short

# 3. Commit everything else to the current branch
git commit -m "your commit message"

# 4. Create and switch to the new branch — untracked files travel with checkout
#    by default; see footnote [^checkoutcarry]
git checkout -b feat/person-person-personlinks

# 5. Confirm the file made the trip
git status --short

# 6. Stage and commit it there
git add docs/subsystems/person/PL-3-person-to-person-link-spec.md
git commit -m "Add PL-3 person-to-person link spec"
```

# Expected Output

After step 1's `git status --short`, the eight `M` entries remain staged (`M ` in the first column), and `PL-3` moves from staged (`A `) to the "Untracked files" section — not gone, not deleted, just unstaged.[^headstate]

After step 3, `git log -1 --stat` on the current branch shows the 8-file commit; `PL-3` should not appear in it.

After step 4's checkout, step 5's `git status --short` should show exactly one line:

```
?? docs/subsystems/person/PL-3-person-to-person-link-spec.md
```

If anything else appears, or the file is missing entirely, stop before committing — something in the working tree state diverged from what this procedure assumes.[^pathspecfail]

---

[^verify]: `git status --short` after step 1 is the only check needed here, because `git restore --staged` operates on exactly the pathspec you give it and nothing else — there's no snapshot-vs-working-tree split to reconcile the way there was with the stash approach.

[^headstate]: The file moves to "untracked" rather than showing as a pending deletion because `git restore --staged` resets the given path's index entry to match `HEAD`. Since `HEAD` never tracked this file, its `HEAD` state is "does not exist," so the index entry for it is simply removed — leaving the file exactly as it was on disk, just no longer staged.

[^pathspecfail]: The realistic failure mode here is a typo in the path or running the commands from the wrong working directory — not any interaction between `git restore` and the other staged files, since `git restore --staged <path>` is scoped to that single index entry by construction. If step 2 shows the wrong file affected, `git add` it back and re-run step 1 with the corrected path.

[^checkoutcarry]: `git checkout -b <name>` creates the branch and moves `HEAD` and the index to match it, but this only concerns *tracked* content — files that exist in some commit reachable from the target branch. An untracked file, like `PL-3` at this point in the procedure, isn't part of any branch's tree yet, so checkout has nothing to reconcile it against; it stays on disk through the switch unchanged. This only becomes a hazard if the target branch's tree already contains a *different* file at that exact path — then checkout refuses to switch to avoid silently clobbering it. That's not the situation here, since `PL-3` has no history on any branch, but it's the condition worth knowing about if this pattern gets reused for a file that might already exist elsewhere.

[^whystash]: The original draft of this procedure reached for `git stash push -- <pathspec>` on the reasonable assumption that a pathspec argument scopes the *entire* stash operation to that path. It doesn't: `git stash push` always records a full snapshot commit of the whole index and working tree, regardless of pathspec — the pathspec only governs which paths get reverted from the working directory afterward. This was caught empirically: `git stash show --name-only` on the resulting entry listed all 14 changed files, not the 1 intended. For this specific task — permanently relocating a file's uncommitted content to a different branch, with no intention of round-tripping through the original branch — `git restore --staged` is the correct, narrower tool. Stash remains the right tool for genuinely temporary shelving (e.g., "I need to pull someone's hotfix branch but my tree is dirty and I want it all back afterward"), where capturing the full state is the point.
