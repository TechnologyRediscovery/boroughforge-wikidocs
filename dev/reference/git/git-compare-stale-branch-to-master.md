---
title: Compare a stale branch against master
description: Find which files and commits on an old branch never reached master, and read diff signs correctly
published: true
date: 2026-09-27T00:00:00.000Z
tags: git, how-to, branching, diff
editor: markdown
dateCreated: 2026-09-27T00:00:00.000Z
---

# Compare a stale branch against master

**Quadrant:** how-to. **Use when:** an older branch tip holds work that may never have been merged, and master has since moved on.

Throughout, `<branch>` is the stale branch (e.g. `lsa7-cearblasts`).

## Fast path

```bash
git cherry -v master <branch>                         # 1. which commits are truly unapplied?
git diff --name-status -M master...<branch>           # 2. which files did the branch touch, and how?
git diff --stat=200 master...<branch> -- <path>       # 3. drill into a subtree
git diff master...<branch> -- <file>                  # 4. read the actual hunks
git merge-tree --write-tree master <branch>           # 5. dry-run merge, list conflicts (git ≥ 2.38)
```

Use **three dots** (`master...<branch>`) for `git diff`. Two-dot or two-argument forms mix in master's later work.[^twodot]

## Command reference

### File-level summaries (all against the merge base)

| Want | Command |
|---|---|
| One-line totals | `git diff --shortstat master...<branch>` |
| Status letter per file | `git diff --name-status -M master...<branch>` |
| Only files the branch created | `git diff --name-only --diff-filter=A master...<branch>` |
| Everything except deletions | `git diff --name-status --diff-filter=d master...<branch>` |
| Added/removed counts, tab-separated | `git diff --numstat -M master...<branch>` |
| Largest additions first | `git diff --numstat master...<branch> \| sort -k1,1nr \| head -20` |
| Histogram with `(new)` / `(gone)` markers | `git diff --compact-summary -M master...<branch>` |
| Rollup by directory | `git diff --dirstat=lines,cumulative master...<branch>` |

`--name-status` letters: `A` added, `M` modified, `D` deleted, `R087` renamed at 87% similarity, `C` copied, `T` type change. `-M` enables rename detection so a moved file doesn't count as one delete plus one add. In `--diff-filter`, capitals include a category and lowercase excludes it. In `--numstat`, binary files show `-` for both counts.

### Commit-level views

| Want | Command |
|---|---|
| Commits on the branch, not on master | `git log --oneline master..<branch>` |
| Same, with files per commit | `git log --oneline --stat master..<branch>` |
| Both sides since the fork, graphed | `git log --oneline --left-right --graph master...<branch>` |
| Branch commits whose patch is not already in master | `git log --oneline --cherry-pick --right-only master...<branch>` |

### Verify "never merged" before trusting it

```bash
git cherry -v master <branch>
```

`+` means no equivalent patch exists in master. `-` means an equivalent change is already there under a different hash, for example after a cherry-pick or rebase.[^cherry]

### Trial merge

```bash
git merge --no-commit --no-ff <branch>    # inspect, then:
git merge --abort
```

Alternatively, `git merge-tree --write-tree master <branch>` runs the merge without touching the working tree.

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

---

[^twodot]: `git diff HEAD master` compares two snapshots and ignores history. If both sides changed after the fork, each sign is ambiguous. A `+` may be master's addition *or* the branch's deletion. A `-` may be the branch's addition *or* master's deletion. A file marked "new" may just be a file master created later. Three-dot diff removes the ambiguity by using the merge base as the old side.

[^cherry]: Patch-id matching fails on squash-merges, because many commits collapse into one patch that matches none of them individually. If any of the branch was ever squash-merged, verify by content: check whether hunks from the three-dot diff already exist in master. Also, if master was ever merged *into* `<branch>`, the merge base moves forward, and the three-dot diff shows only work since that merge.
