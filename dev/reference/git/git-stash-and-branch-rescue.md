---
title: Stashing & branch-rescue playbook — moving work to the branch it belongs on
description: Scenario-driven recipes for stashing uncommitted work onto the right branch, locating which branch holds a given file, and relocating an already-committed change to a different branch
published: true
date: 2026-08-19T00:00:00.000Z
tags: git, stash, branching, development, tooling
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Stashing & branch-rescue playbook

Three variations on the same mistake — work ends up associated with the wrong branch — and the
fix differs completely depending on **whether the work is committed yet**. This is the mental
model's snapshot/immutability point ([git-mental-model.md](/dev/reference/git/git-mental-model))
made practical: uncommitted content isn't anchored to any branch at all, so it's a stash-and-move
problem; committed content is baked into an immutable commit object, so it's a copy-the-diff
problem (cherry-pick), not a move.

This page assumes you've read the **"stash workflow"** section of
[git-three-trees-recovery-primer.md](/dev/reference/git/git-three-trees-recovery-primer) for what
a stash actually *is* (real commit objects, `pop` vs `apply`, selective stashing) — this page is
the scenario-driven companion, not a restatement.

## Quick reference

| Situation | Is it committed? | Right tool |
|---|---|---|
| Mid-work, realize you're on the wrong branch | No | `git stash` → switch/create branch → `pop`/`apply` |
| Don't know which branch has a given file | N/A | `git cat-file -e` sweep, or `git log --all --source` |
| Already committed to the wrong branch | Yes | `git cherry-pick` (+ `reset`/`rebase -i`/`revert` to remove the original) |

---

## 1. Uncommitted work landed on the wrong branch

**Situation:** you created `feat/pub-app-sqlandspeccing` for SQL/public-app work, but you've
actually been heads-down on letters. `git status --short` shows a realistic mix:

```
 M src/main/java/com/tcvcog/tcvce/coordinators/LetterCoordinator.java
 M docs/subsystems/letters+emailing/letters-index.md
?? docs/subsystems/letters+emailing/letters-index-pt4.md
?? docs/subsystems/letters+emailing/IV-E-nov-legacy-migration-spec.md
```

None of it is committed. Per the mental model, uncommitted content isn't attached to a branch —
only commits are — so this is purely a stash-and-relocate problem, not the cherry-pick problem in
§3 below.

### Step 0 — read the staged/unstaged split before you do anything

```bash
git status --short
```

Column 1 = staged (index vs HEAD), column 2 = unstaged (working tree vs index) — see the
`status --short` decoding table in
[git-three-trees-recovery-primer.md](/dev/reference/git/git-three-trees-recovery-primer). If every
line reads ` M` (leading space), nothing is staged — the easy case, covered below. If anything
shows in column 1 (`M `, `A `, `MM`), some hunks are already staged and you need the `--index`
flag when reapplying (explained inline below) or you'll lose that distinction.

Also check for `??` untracked files — plain `git stash` ignores them entirely; you need `-u`.

### Case A — the destination branch doesn't exist yet, and the current branch hasn't diverged

Confirm the current branch has no commits of its own yet:

```bash
git log --oneline master..feat/pub-app-sqlandspeccing   # empty output = no divergence
```

If that's empty, `git stash branch` is the one-shot recipe:

```bash
# capture everything, including new untracked files, staged or not
git stash push -u -m "letters work stashed off pub-app-sqlandspeccing by mistake"

# create + checkout a new branch at the same commit, and reapply in one motion
git stash branch feat/letters-pt4-continued
```

`git stash branch <name>` creates the branch **at the commit that was HEAD when the stash was
taken**, then applies the stash to both the working tree and the index — so whatever staged/
unstaged split you had is restored automatically, no separate `--index` flag needed.

**Gotcha:** that new branch is rooted at "wherever HEAD was when you stashed," not necessarily at
`master`. If the divergence check above had shown commits, those commits belong to
`feat/pub-app-sqlandspeccing` specifically and would come along for the ride — not what you want.
In that case, pick the base explicitly instead:

```bash
git stash push -u -m "letters work"
git switch -c feat/letters-pt4-continued master   # explicit, correct base
git stash pop --index                              # --index restores the staged/unstaged split
```

### Case B — the destination branch already exists

```bash
git stash push -u -m "letters work stashed off pub-app-sqlandspeccing by mistake"
git switch lsa7-d-letterscont
git stash pop --index
```

`stash branch` only ever creates a *new* branch, so it's not an option here — switch manually,
then reapply. Popping doesn't care what branch is currently checked out; it's just a patch
application against whatever's in the tree. If that target branch's copies of these files differ
enough from what they looked like at stash time, `pop` can conflict, with the same
conflict-marker behavior as any other patch application. If you're not confident the apply will
be clean, use `git stash apply --index` first (keeps the stash entry as a safety net) and only
`git stash drop` once you've confirmed the result builds.

### The staged-vs-unstaged answer, distilled

A stash always captures the index and the working tree as two separate snapshots, so the
staged/unstaged split is *preserved in the stash entry itself*. But by default, `git stash apply`
/ `pop` collapse everything back into a single unstaged blob when reapplying. If you'd staged some
hunks before realizing you were on the wrong branch, always reapply with `--index`
(`git stash pop --index` / `git stash apply --index`) to reproduce that split. If everything was
unstaged to begin with, plain `pop`/`apply` reproduces that state exactly — there's no split to
lose, so `--index` is a harmless no-op in that case too.

---

## 2. Finding which branch has a file you can't find on your current one

**Situation:** `codeconnect/database/patches/dbpatch_beta92.sql` isn't in your working tree, and
`git log -- <path>` on the current branch shows nothing — but you know it exists on *some* branch
among the two dozen in this repo.

Two different questions need two different tools, and conflating them is the trap:

- *"Which branch(es) currently have this file at their tip?"* → check each branch's tree directly.
- *"Which commit, anywhere in history, ever added or touched this file?"* → search commit history
  across all refs.

### Direct tip-existence check (fastest — "do I have this file somewhere to just grab")

```bash
git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ | while read -r b; do
  git cat-file -e "$b:codeconnect/database/patches/dbpatch_beta92.sql" 2>/dev/null && echo "$b"
done
```

`git cat-file -e <ref>:<path>` exits `0` if that path exists as a blob in that ref's tree, `1`
otherwise — no checkout required, no output on failure. It's the existence-only analog of
`git show <ref>:<path>`, which would print the file's contents.

### History search (answers "when/where was this file ever added, even if since deleted")

```bash
# every commit, on every ref, that touched this path — annotated with which ref found it
git log --all --oneline --source -- '**/dbpatch_beta92.sql'
```

`--source` prints the ref name through which `log` reached each commit — only meaningful when
walking multiple refs (`--all`, or an explicit branch list), and it shows *one* contributing ref
per commit, not necessarily every branch containing it. Pair it with `--contains` for the
complete list once you have a SHA:

```bash
git branch --all --contains <sha>
```

**Common trap:** `--grep` searches commit **messages**, not file paths or file contents —
`git log --all --grep=dbpatch_beta92` finds nothing unless someone happened to type that filename
into a commit subject. The pathspec after `--` is what matches paths. Searching file *contents*
across history (e.g. "which commit ever added this table name") is a third, different tool — the
pickaxe, `git log -S<string> --all`.

### Once you've found the right branch, grab just the file — no full checkout needed

```bash
git show lsa7-ceartweaks:codeconnect/database/patches/dbpatch_beta92.sql \
  > codeconnect/database/patches/dbpatch_beta92.sql
```

---

## 3. Already committed to the wrong branch entirely

Contrast with §1: this is committed, so immutability applies. You can't move a commit — you copy
its diff onto a different parent (`cherry-pick`), then separately decide what happens to the
original.

### Case A — it's the single most recent commit, unpushed, and the correct branch doesn't exist yet

```bash
git log --oneline -1                 # confirm it's really the tip; note the SHA
git branch feat/correct-branch       # new branch pointing at the SAME commit — includes it
git reset --hard HEAD~1              # rewind the wrong branch, dropping the commit
git switch feat/correct-branch       # now has exactly that commit
```

Safe only because the commit is unpushed and genuinely the last one. `reset --hard` unconditionally
drops it from the wrong branch's history — recoverable briefly via `git reflog`, not a durable
safety net. See the revert-strategies table in
[git-mental-model.md](/dev/reference/git/git-mental-model) for how this compares to the other
"undo" options.

### Case B — buried among other commits you want to keep, already pushed, or the correct branch has diverged

```bash
git log --oneline feat/wrong-branch          # find the SHA of the misplaced commit
git switch feat/correct-branch
git cherry-pick <sha>                        # copies the same diff as a NEW commit here
```

Cherry-pick takes the diff between that commit and its parent and reapplies it as a brand-new
commit object — new SHA, new parent, same tree changes. Conflicts are handled exactly like a merge
conflict: edit, `git add` the resolved paths, `git cherry-pick --continue`.

Then deal with the original on the wrong branch:

- **Unpushed, not the tip** — interactive rebase and drop that line:
  `git rebase -i <sha>~1`, change `pick` to `drop` for that commit.
- **Already pushed / shared** — don't rewrite published history.
  `git revert <sha>` on the wrong branch instead: it adds an inverse commit rather than erasing
  the original. This is the "safe after push" row in the mental-model doc's revert table —
  cherry-pick the good copy first, revert the bad original second; order doesn't matter
  mechanically, but doing it in that order means you're never without a working copy of the
  change mid-operation.

---

## See also

- [git-mental-model.md](/dev/reference/git/git-mental-model) — objects, refs, reachability, merge
  outcomes, revert-strategy table.
- [git-three-trees-recovery-primer.md](/dev/reference/git/git-three-trees-recovery-primer) — the
  index-as-snapshot model, `status --short` decoding, and the stash mechanics this page builds on.
- [git-branch-commit-conventions.md](/dev/reference/git/git-branch-commit-conventions) — branch
  naming grammar and the interrogation commands (`--merged`, `--contains`, `--grep`) used above.
- [gitlab-mr-cli-primer.md](/dev/reference/git/gitlab-mr-cli-primer) — two-dot vs. three-dot diff,
  for when the branch you just rescued work onto is about to become an MR.
