---
title: Compare a stale branch against master, then archive or discard it
description: Find what an old branch contributed, test whether master already has it, and retire the branch reversibly or delete it permanently
published: true
date: 2026-09-30T00:00:00.000Z
tags: git, how-to, branching, diff, cleanup
editor: markdown
dateCreated: 2026-09-27T00:00:00.000Z
---

# Compare a stale branch against master, then archive or discard it

**Quadrant:** how-to. **Use when:** an older branch tip holds work that was never merged, master has since moved on, and you need to decide whether to merge, archive, or delete the branch.

Throughout this page, `<branch>` means the stale branch (for example `lsa7-cearblasts` or `lsa2-nomorecustom`).

## Fast path

**Inspect the branch:**

```bash
git cherry -v master <branch>                         # 1. which commits are truly unapplied?
git diff --name-status -M master...<branch>           # 2. which files did the branch touch, and how?
git diff --stat=200 master...<branch> -- <path>       # 3. drill into a subtree
git diff master...<branch> -- <file>                  # 4. read the actual hunks
git merge-tree --write-tree master <branch>           # 5. dry-run merge, list conflicts (git ≥ 2.38)
```

**Archive it (reversible):**

```bash
git tag -a archive/<branch> <branch> -m "<why it was dropped>"
git branch -D <branch>
git push origin archive/<branch>
```

**Discard it permanently:** see [Discard a branch permanently](#discard-a-branch-permanently).

Use **three dots** (`master...<branch>`) for `git diff`. The two-dot and two-argument forms mix in master's later work.[^twodot]

## The core model: ancestry is not content

Git has two different ways to say that a branch is "merged," and they can disagree:

| Test | Question it answers | Commands |
|---|---|---|
| Ancestry | Are the branch's commit **objects** reachable from master? | `git log master..<branch>`, `git diff master...<branch>`, `git branch --no-merged`, `git branch -d` |
| Patch identity | Does master contain an **equivalent change**, under any hash? | `git cherry`, `git log --cherry-pick` |
| Content / intent | Does master contain the **same idea**, however it was written? | No git command answers this. Use `git grep`, `git log -S`, and your own judgment. |

"The commits aren't merged" is an ancestry claim. "The deltas can be tossed" is a content claim. Neither one implies the other. The branch's work may already be in master under different hashes, after a cherry-pick, rebase, or re-application by hand. The work may also be missing from master and still not needed, because it was superseded or abandoned. See [Does master already have this work?](#does-master-already-have-this-work)

## Command reference

### File-level summaries (all against the merge base)

| Want | Command |
|---|---|
| One-line totals | `git diff --shortstat master...<branch>` |
| Status letter per file | `git diff --name-status -M master...<branch>` |
| Only files the branch created | `git diff --name-only --diff-filter=A master...<branch>` |
| Everything except deletions | `git diff --name-status --diff-filter=d master...<branch>` |
| Added/removed counts, tab-separated | `git diff --numstat -M master...<branch>` |
| Histogram with `(new)` / `(gone)` markers | `git diff --compact-summary -M master...<branch>` |
| Rollup by directory | `git diff --dirstat=lines,cumulative master...<branch>` |

To list the files with the most added lines first:

```bash
git diff --numstat master...<branch> | sort -k1,1nr | head -20
```

`--name-status` letters: `A` added, `M` modified, `D` deleted, `R087` renamed at 87% similarity, `C` copied, `T` type change. `-M` turns on rename detection, so a moved file is not counted as one delete plus one add. In `--diff-filter`, a capital letter includes that category and a lowercase letter excludes it. In `--numstat`, binary files show `-` for both counts.

### Commit-level views

| Want | Command |
|---|---|
| Commits on the branch, not on master | `git log --oneline master..<branch>` |
| Same, with files per commit | `git log --oneline --stat master..<branch>` |
| Both sides since the fork, graphed | `git log --oneline --left-right --graph master...<branch>` |
| Branch commits whose patch is not already in master | `git log --oneline --cherry-pick --right-only master...<branch>` |

### Trial merge

```bash
git merge --no-commit --no-ff <branch>    # inspect, then:
git merge --abort
```

Alternatively, `git merge-tree --write-tree master <branch>` runs the merge without touching the working tree. On a branch that is years old, a trial merge mostly produces conflicts with master's later work, so it tells you little about whether the branch's content still matters.

## How to read `+` and `-`

`git diff A B` prints the edits that turn tree A into tree B. A is the `a/` (old) side and B is the `b/` (new) side.

| Command | `+` means | `-` means |
|---|---|---|
| `git diff HEAD master` (on `<branch>`) | in master, not at branch tip | at branch tip, not in master |
| `git diff master...<branch>` | branch added since fork | branch removed since fork |
| `git diff <branch>...master` | master added since fork | master removed since fork |
| `git cherry -v master <branch>` | commit not applied upstream | equivalent patch already upstream |

In the first row, the branch's stranded work appears mostly as **`-`** lines, which is the reverse of what most people expect.

`A...B` means different things to different commands. For `git diff`, it is the diff from `merge-base(A, B)` to `B`. For `git log`, it is the symmetric difference of commits, meaning commits reachable from either side but not both.

## Does master already have this work?

Work through these checks from cheapest to most expensive. Stop when you have an answer.

**1. Patch identity.** This check finds cherry-picks and clean rebases.

```bash
git cherry -v master <branch>
```

`+` means no equivalent patch exists in master. `-` means an equivalent change is already there under a different hash.[^cherry]

**2. Presence now.** Pick a distinctive identifier, SQL fragment, or string literal from the three-dot diff, and search master's current tree for it:

```bash
git grep -n 'distinctiveIdentifier' master
```

**3. Presence ever (the pickaxe).** This finds commits on master that changed the number of occurrences of a string. A hit tells you whether master introduced the same thing independently, and when. It also tells you whether master later removed it on purpose.

```bash
git log -S'distinctiveIdentifier' --oneline master
git log -G'regex.*pattern' --oneline master        # regex variant: any added/removed line matching
```

**4. Supersession.** Git cannot tell you that master solved the same problem a different way. This part is an adjudication, and it is yours to make. Record the result in the archive tag message or in the daybook, so the next reader does not have to repeat the analysis.

## Branches that carried database patches

A database patch that exists only on a branch has two separate existences: the SQL file in the repository, and whatever was actually executed against a database. Deleting the branch removes the file. It does not revert a schema that was already altered.

Before you delete such a branch:

```bash
git diff --name-status master...<branch> -- '*.sql'    # which patch files the branch holds
git show <branch>:path/to/patch_NNN.sql                # read one without checking out
git show master:path/to/patch_NNN.sql                  # compare with master's file of the same number, if any
```

Then compare that patch with the live schema in each environment it might have touched (`\d table` in psql, or `information_schema.columns`). Watch especially for a patch number that exists on both the branch and master with different content. Branch and master have then diverged on the meaning of that number, and any database that ran the branch's version has a schema that master's patch sequence does not describe.

## Triage every branch at once

```bash
git branch --no-merged master                # heads not reachable from master (ancestry test)

git for-each-ref refs/heads --sort=committerdate \
  --format='%(committerdate:short)  %(ahead-behind:master)  %(refname:short)'
```

`%(ahead-behind:master)` needs git ≥ 2.41 (check with `git --version`). It prints two numbers for each branch: commits ahead of master, and commits behind it. A branch with a few commits ahead and thousands behind is a triage candidate.

## Decide: archive or discard

An annotated archive tag costs almost nothing. It is a few hundred bytes plus retention of objects that the repository mostly already shares with master. Permanent deletion buys only one thing over archiving: the commits eventually stop existing. So the choice comes down to this:

| Situation | Choose |
|---|---|
| Any doubt about the content's value, or the branch touched the database | Archive |
| Abandoned experiment you might want to consult later ("why didn't that work?") | Archive |
| Throwaway work with no informational value (a scratch branch, a botched rebase, a duplicate) | Discard |
| The branch contains something that must not persist (a committed secret, personal data) | Discard, **and** read [Remote copies and the limits of "forever"](#remote-copies-and-the-limits-of-forever); deletion alone does not protect a leaked secret |

## Retire a branch to an archive tag (reversible)

```bash
git tag -a archive/<branch> <branch> \
  -m "Abandoned: <what was tried>; <why dropped>. Not merged. Superseded by <commit/branch>, if any."
git branch -D <branch>                        # -D because -d refuses unmerged branches
git push origin archive/<branch>              # off-machine copy on GitLab
git push origin --delete <branch>             # only if a remote branch exists
```

The tag keeps the commits reachable, so garbage collection never removes them. Because it is annotated, it records who archived the branch, when, and why. The `archive/` prefix keeps these tags grouped and easy to filter out:

```bash
git tag -l 'archive/*'                        # list archived branches
git tag -l --sort=-creatordate -n1 'archive/*'   # newest first, with first line of message
git switch -c <branch>-revived archive/<branch>  # bring one back as a branch
```

## Discard a branch permanently

### Procedure

```bash
# 0. Complete the checks above. Everything after step 4 is time-limited to reverse.

# 1. Record the tip hash (your recovery handle if you change your mind)
git rev-parse <branch>

# 2. Make sure the branch isn't checked out here or in any worktree
git branch --show-current
git worktree list

# 3. Delete the local branch
git branch -D <branch>
#   Deleted branch <branch> (was 1a2b3c4).

# 4. Delete the remote branch, if one exists
git ls-remote --heads origin <branch>        # empty output means no remote branch
git push origin --delete <branch>

# 5. Remove stale remote-tracking refs (origin/<branch>) here and on every other clone
git fetch --prune origin
```

`git branch -D` and `git push origin --delete` both accept several names at once, for example `git branch -D lsa2-nomorecustom lsa4-personlinks`.

### `-d` versus `-D`

`git branch -d <branch>` (`--delete`) deletes the branch only if it is fully merged into **its upstream branch**, or into **HEAD** if no upstream is set. The safety check is therefore relative to whatever you have checked out at the moment, not to master. A branch can pass `-d` while you are on a feature branch that contains it, and fail while you are on master, or the reverse. To check against master specifically, use `git branch --no-merged master` rather than trusting `-d`.

`git branch -D <branch>` is shorthand for `--delete --force`. It skips the merge check entirely. For a branch that is unmerged by definition, `-D` is the only way to delete it.

Git refuses either form in two cases:

- The branch is checked out in the current working tree. Switch away first.
- The branch is checked out in another worktree (`cannot delete branch '<branch>' used by worktree at ...`). Remove that worktree with `git worktree remove <path>`, or switch it to another branch.

### What `-D` actually removes

`git branch -D` deletes exactly two things:

1. The ref `refs/heads/<branch>`, the name that points at the tip commit.
2. The branch's own reflog, `.git/logs/refs/heads/<branch>`.

It does **not** delete any commits, trees, or blobs. Those objects stay in `.git/objects` until garbage collection finds them unreachable **and** older than the prune grace period. A commit counts as reachable while anything still refers to it, directly or through ancestry:

| Still referring to the commits | Removed by |
|---|---|
| Other local branches or tags containing them | deleting those refs |
| `refs/remotes/origin/<branch>` (remote-tracking ref) | `git fetch --prune` after the remote branch is gone |
| `refs/stash` entries made on the branch | `git stash drop` / `git stash clear` |
| **HEAD's reflog** (every commit you ever checked out or created while on the branch) | reflog expiry, see below |

The HEAD reflog is the one people forget. If you ever worked on the branch, HEAD's reflog holds entries pointing at its commits, and those entries keep the commits alive after the branch ref is gone.

### How long the commits survive after deletion

With default configuration, removal happens in two stages during `git gc`. Git runs `git gc --auto` on its own after some commands, so this happens without you asking.

1. **Reflog expiry.** Reflog entries pointing at commits that are no longer reachable from the current tip expire after `gc.reflogExpireUnreachable`, which defaults to **30 days**. Entries still reachable expire after `gc.reflogExpire`, which defaults to **90 days**. After you delete a branch, its commits usually fall into the 30-day class.
2. **Pruning.** Once no ref or reflog entry refers to them, the objects are loose-unreachable. `git gc` deletes loose unreachable objects older than `gc.pruneExpire`, which defaults to **2 weeks**.

So a deleted branch's commits typically remain recoverable for **about 30 to 45 days** after the last time HEAD touched them. For a branch nobody has checked out in years, the HEAD reflog entries have usually expired already. In that case, the objects become prunable as soon as the branch ref and the remote-tracking ref are gone, and they disappear at the next gc that runs more than two weeks later. Check your settings with:

```bash
git config --get gc.reflogExpire
git config --get gc.reflogExpireUnreachable
git config --get gc.pruneExpire
```

### Recovering within the window

If you recorded the tip hash in step 1:

```bash
git branch <branch> 1a2b3c4
```

If you did not:

```bash
git reflog | grep -i '<branch>'              # "checkout: moving from <branch> to ..." entries
git fsck --unreachable --no-reflogs | grep commit   # dangling commits; inspect with git show
```

`git fsck --lost-found` writes dangling commits to `.git/lost-found/commit/`, where you can inspect them one at a time.

### Immediate local purge (rarely justified)

To make the deletion final on this machine right now, instead of in a month:

```bash
git reflog expire --expire-unreachable=now --all
git gc --prune=now
```

**This is repository-wide, not branch-scoped.** It destroys every other recovery path in the repository at the same moment: dropped stashes, pre-rebase commits, abandoned amend chains, and the tips of any other branch you deleted recently. The only benefits are disk space and certainty that the objects are gone locally. For ordinary cleanup, neither is worth the loss, so let the default schedule do the work.

### Remote copies and the limits of "forever"

Deleting a branch from your clone and from `origin` removes it from your **working set**. It does not guarantee that the content no longer exists anywhere:

- **Other clones.** Every machine or server that fetched the branch keeps its own copy of the objects, subject to its own reflogs and gc schedule. Each one needs `git fetch --prune` (and, for local branches there, `git branch -D`).
- **GitLab server-side.** Removing the branch removes the ref. GitLab also keeps hidden refs for merge requests (`refs/merge-requests/<iid>/head`), so commits that ever belonged to an MR stay reachable on the server even after the branch is deleted. Server-side pruning follows GitLab's repository housekeeping, not your local gc.
- **Protected branches.** GitLab refuses `git push origin --delete` for a protected branch until you unprotect it in the project settings.
- **Secrets and personal data.** If the reason for "forever" is that the branch contains a credential or sensitive data, treat the data as already disclosed. Rotate the credential first. Removing it from history is a separate, larger operation (`git filter-repo`, plus GitLab's documented procedure for purging repository data) and is out of scope for this page.

---

[^twodot]: `git diff HEAD master` compares two snapshots and ignores history. If both sides changed after the fork, each sign is ambiguous. A `+` may be master's addition *or* the branch's deletion. A `-` may be the branch's addition *or* master's deletion. A file marked "new" may just be a file master created later. The three-dot diff removes the ambiguity by using the merge base as the old side.

[^cherry]: Patch-id matching fails on squash-merges, because many commits collapse into one patch that matches none of them individually. It also fails when a commit was re-applied with even minor edits. If any of the branch was ever squash-merged or hand-ported, verify by content: check whether hunks from the three-dot diff already exist in master. Also, if master was ever merged *into* `<branch>`, the merge base moves forward, and the three-dot diff shows only work since that merge.
