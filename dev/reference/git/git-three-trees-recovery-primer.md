---
title: Git internals primer — three trees, status codes, hashing, and recovery mechanics
description: LLM generated explication of git diff/restore/stash mechanics, the index-as-snapshot model, status --short decoding, and SHA-1 hashing theory, developed during a working-tree deletion recovery
published: true
date: 2026-08-10T00:00:00.000Z
tags: git, version-control, recovery, sha1, internals
editor: markdown
dateCreated: 2026-08-10T00:00:00.000Z
---

> **Author:** Claude (Anthropic, model: Claude Fable 5), generated 2026-08-10 in conversation with Eric Darsow. Context: this document emerged from a live recovery session in the CodeNforce repository after an unexplained working-tree deletion of five methods from `CaseCoordinator.java`, and generalizes the mechanics used to diagnose and repair it.

# The three trees: Git's fundamental state model

Every Git operation discussed below is a movement of content between three complete snapshots:

1. **HEAD** — the last commit. HEAD is a pointer that normally points *to a branch name* (e.g., `master`), which in turn points to the tip commit. This indirection is what makes a branch advance when you commit: the new commit updates `master`, and HEAD follows because it references the branch, not a commit hash. The exception is *detached HEAD* (after `git checkout <hash>` or checking out a tag), where HEAD points straight at a commit.

2. **The index** (staging area) — a **complete snapshot of every tracked file**, not a queue of accumulated changes. This distinction is the most consequential correction to the common mental model. The index always contains the full content of the entire tracked file set, at some specific version per file. `git add x` means "overwrite the index's copy of `x` with the current working-tree copy" — a content copy into the snapshot, not an append to a changelist. Immediately after any commit, index and HEAD are identical; `add` then diverges the index file-by-file toward the working tree.

3. **The working tree** — the actual files on disk that editors, IDEs, and shell tools touch.

The snapshot model explains behaviors that baffle the delta model:

- Editing a file *after* `git add` and then committing produces a commit containing the **first** version — the commit is built from the index snapshot, which holds whatever was copied in at `add` time. Re-`add` to update it.
- `git restore <path>` without `--source` copies **from the index** to the working tree. This works as a recovery mechanism precisely because the index holds a complete file, not deltas needing replay.
- `git diff` output is *derived* at display time by comparing two snapshots. Git stores content; diffs are a presentation-layer artifact. (This is also why rename detection is heuristic — there's no change-log to consult, only snapshots to compare.)

The core arrows: `add` copies working tree → index; `commit` copies index → HEAD (creating a new commit, advancing the branch); `restore` copies index → working tree.

# git diff: the three comparison modes

`git diff` with no mode-selecting options compares the **index against the working tree** — unstaged changes only. Not HEAD against the working tree.

| Command | Left side | Right side | Shows |
|---|---|---|---|
| `git diff` | index | working tree | unstaged changes |
| `git diff --staged` (or `--cached`) | HEAD | index | what would be committed right now |
| `git diff HEAD` | HEAD | working tree | all uncommitted changes, staged or not |

**The `--` separator** is not a diff option; it is the general Git disambiguation token meaning "everything after this point is a pathspec, not a revision or option." Git commands accept revisions and paths positionally, and a file named `master` would otherwise be ambiguous. Often technically optional, always good hygiene, and it makes commands robust to unusual filenames:

```bash
git diff -- src/main/java/com/tcvcog/tcvce/coordinators/CaseCoordinator.java
```

A deletion appears as `-` lines in the diff — the expected output when previewing what a restore will discard. If a diff you intend to throw away shows *additional* hunks beyond the expected deletions, stop and cherry-pick with `git restore -p` rather than restoring the whole file.

# Decoding git status --short

Two fixed-width columns precede each path:

- **Column 1** — index vs. HEAD (what is staged)
- **Column 2** — working tree vs. index (what is unstaged)

Common patterns:

| Output | Meaning |
|---|---|
| ` M file` (space, then M) | Modified, **unstaged only**. Index still matches HEAD. |
| `M  file` (M, then space) | Modified and **fully staged**. Working tree matches index. |
| `MM file` | Staged modification *plus* further unstaged edits on top. |
| `?? file` | **Untracked** — no index entry at all; both comparisons are undefined, so Git uses a marker outside the normal alphabet. |
| `!! file` | Ignored (shown only with `--ignored`). |

The single character of left shift between ` M` and `M ` is the entire signal distinguishing "safe to restore from index" from "index is also contaminated." When column alignment is untrustworthy — paste buffers, terminal trimming — `git status --porcelain=v2 <path>` reports index and worktree states in separate labeled fields instead of relying on position. This is the general pattern-over-position principle applied to status parsing.

# Recovery from an uncommitted working-tree deletion

The scenario: tracked files lost content (a pure deletion) in the working tree only; the change was never staged. The verified procedure, scoped to only the damaged files so it cannot touch other legitimate uncommitted work in the same tree:

```bash
# 0. Verify the deletion is unstaged — the entire plan depends on this
git status --short path/to/DamagedFile.java
#  M path/to/DamagedFile.java     <-- leading space confirms index matches HEAD

# 1. Preview exactly what will be discarded
git diff -- path/to/DamagedFile.java path/to/other.xhtml

# 2. Restore just these files from the index (which equals HEAD here)
git restore -- path/to/DamagedFile.java path/to/other.xhtml

# 3. Confirm clean
git status --short

# 4. Rebuild
mvn clean package -DskipTests
```

**The load-bearing assumption:** `git restore` without `--source` restores from the *index*. If the deletion had been staged (a reflexive `git add .`, an IDE auto-stage), the index would also lack the content, and plain `restore` would "restore" the file to its still-broken staged state. Step 0 exists to test this. If column 1 shows `M`, the correct command becomes:

```bash
git restore --source=HEAD --staged --worktree -- <paths>
```

which resets both the index entry and the working-tree copy back to the commit. Verify state before destructive operations; here the verification is one status line read carefully.

# Safety rules: committing vs. switching branches

The organizing principle: **Git refuses operations that would overwrite uncommitted content it cannot recover, and silently permits everything else.**

## Committing — purely additive

`git commit` writes the index snapshot into a new commit and advances the branch. It never modifies the working tree and can never destroy work. The rules are inclusion rules:

- Only index content enters the commit. Tracked-but-unstaged modifications stay in the working tree, unharmed and uncommitted.
- **Untracked (`??`) files are never committed**, even by `git commit -a` — the `-a` option auto-stages modifications and deletions of *tracked* files only. The trap: a `-a` commit that omits a new referenced source file will not compile on a fresh clone. The commit risk is never lost work; it is *believing work is saved when it isn't*.

## Switching — where enforcement engages

`git switch <branch>` must rewrite working tree and index to match the target. Per-file rules:

- **Tracked, modified, and the file differs between current HEAD and target:** Git **refuses the switch entirely** ("Your local changes... would be overwritten"). Commit, stash, or discard first.
- **Tracked, modified, but the file is identical between the two branches:** the switch proceeds and **carries the uncommitted modifications along**. Uncommitted changes are not anchored to a branch. This enables the "started work on the wrong branch" fix (switch, then commit) but violates the intuitive model.
- **Untracked files:** normally left alone, persisting across switches. Exception: if the target branch *tracks a file at the same path*, the switch would unrecoverably overwrite the untracked content, so Git refuses.
- **`git switch -f` / `git checkout -f`** disables both protections. Discarded staged content is briefly fishable from dangling objects; discarded unstaged modifications and overwritten untracked files are gone.

## The recoverability lattice

Ordered by protection level:

1. **Committed** — recoverable essentially always; the reflog retains abandoned commits ~90 days even after branch deletion or hard reset.
2. **Staged, uncommitted** — `add` wrote a blob into the object database; `git fsck --lost-found` can resurrect the bytes (without filename) even after index loss.
3. **Tracked, modified, unstaged** — exists only in the working tree, but Git knows the path is valuable and refuses switches that would overwrite it.
4. **Untracked** — exists *nowhere in Git*. Protected against overwrite-by-switch, invisible to plain `stash`, exempt from all restore machinery, and one `git clean -fd` from nonexistence. For any new file worth keeping, an early `git add` is cheap insurance: it promotes the content from tier 4 to tier 2.

`git clean -fd` is the command that destroys untracked files irrecoverably — treat blanket cleanup recipes with suspicion when `??` lines exist.

# The stash workflow

## What a stash is

`git stash` creates **real commit objects** — at minimum one snapshotting the index and one snapshotting the working tree — and points the ref `stash` at the result, stacking prior stashes via that ref's reflog. The working tree and index are then reset to HEAD. Because stashes are commits, stashed content lives in the object database: inspectable with normal commit tooling and findable via `git fsck` even after a mistaken drop.

## Core cycle

```bash
git status --short                                   # know what the stash will contain
git stash push -m "letters pt3: mid-refactor"        # always message; default titles are useless later
git switch other-branch                              # ... urgent work ...
git switch master
git stash pop                                        # reapply and drop in one motion
```

**Untracked files require `-u`** (`--include-untracked`); plain `stash push` takes tracked changes only and leaves `??` files sitting in the tree. `-a` additionally grabs *ignored* files — almost never wanted (it will happily stash a `target/` build directory).

## pop vs. apply

- `git stash apply` — reapply, **keep** the stash. Right verb for replaying onto multiple branches or when uncertain.
- `git stash pop` — apply, then drop, but the drop is **conditional on a clean apply**. On conflict, pop applies what it can, leaves markers, and retains the stash so content cannot be lost mid-conflict. After resolving, `git stash drop` manually — forgetting this accumulates zombie stashes that were already applied.

## Inspection and addressing

```bash
git stash list
git stash show -p stash@{0}        # full patch
git stash show -p -u stash@{0}     # include untracked portion (Git >= 2.32)
```

`stash@{0}` is always most recent, and every push renumbers the stack — positional addressing with a shifting referent. For anything held longer than minutes, the message is the reliable identifier; `git stash list` before any drop or pop targeting a non-zero index is mandatory.

## Selective stashing

```bash
git stash push -p -m "just the OccPeriod experiments"     # interactive hunk selection
git stash push -m "xhtml only" -- path/to/one/file.xhtml  # pathspec-scoped
```

The pathspec form doubles as a forensic quarantine: stash suspect files' changes, examine at leisure with `stash show -p`, drop or reapply after the verdict — rather than discarding outright.

## Aged stashes: promote to a branch

```bash
git stash branch letters-pt3-rescue stash@{0}
```

Creates a branch **at the commit the stash was made from**, checks it out, reapplies conflict-free (replaying onto its own origin), and drops the stash — converting a floating stash into ordinary branch state resolvable by normal merge or rebase. Stashes lack branch legibility (no descriptive DAG structure, positional addressing, easy to drop), so anything living more than a day deserves promotion to a branch or an honest WIP commit. For solo work, `git commit -m "WIP: checkpoint"` followed by later amend or interactive rebase is often simpler than stash choreography and carries full tier-1 recoverability. The stash earns its place for *short-lived* set-asides.

# Hashing theory: why SHA-1 identifiers work, and where they break

Git identifies every object by SHA-1: 160 bits, rendered as 40 hex characters. Two files with byte-identical content hash identically regardless of location; a single flipped bit produces a completely different hash. The mathematical grounding has two independent pillars, and conflating them is the reasoning error to avoid.

## Uniqueness is impossible; the pigeonhole principle forbids it

There are exactly 2^160 possible SHA-1 values (~1.46 × 10^48). The input space is unbounded — even files of exactly 1 KiB number 2^8192. By pigeonhole, enormous numbers of distinct files necessarily share every hash value; collisions exist in unbounded abundance. A hash is emphatically not a unique fingerprint in the mathematical sense. The actual claim is probabilistic: no two files that will ever *actually exist or be constructed* will collide.

## Pillar one: accidental collisions and the birthday bound

Treating SHA-1 as an ideal random function, the probability that any two of *n* hashed objects collide is approximately n²/2^161, crossing ~50% near n ≈ 2^80 ≈ 1.2 × 10^24 objects. Calibration: ten billion people each committing a thousand objects per second for a century produce ~3 × 10^22 objects — still under the bound, at roughly 3% collision probability. A real repository with 10^5–10^6 objects sits around 10^-37 — orders of magnitude below the probability of an undetected hardware error corrupting the comparison result itself. Against nature, the reliance is unimpeachable: the hash is not the weak link; the silicon is.

## The avalanche effect

The all-bits-change-on-one-bit-flip property is engineered: each input bit flip should flip each output bit with probability ½, independently. SHA-1 achieves it via the Merkle–Damgård construction — input padded into 512-bit blocks, each passed through 80 rounds combining modular addition (nonlinear carry propagation), bitwise rotation (cross-position movement), and boolean mixing of state words, each block's output chaining into the next. After 80 rounds, one flipped input bit's influence is statistically indistinguishable from replacing the output with a fresh random value. The hash is not a summary of the file; it is a deterministic *sample* of a point in a 2^160-element space, constructed so that reaching the same point from different inputs requires either absurd luck (pillar one) or cryptanalysis (pillar two).

## Pillar two: engineered collisions — SHA-1 is broken here

Collision *resistance* — the claim that no feasible computation can find two colliding inputs even searching cleverly — has been falsified for SHA-1:

- **2017 (SHAttered, Google/CWI):** first public collision — two distinct PDFs, identical hashes — at ~2^63 operations, roughly 100,000× cheaper than brute force, by exploiting the internal round structure.
- **2020 (Leurent & Peyrin):** chosen-prefix collisions, where both colliding documents begin with attacker-chosen meaningful content, at costs within reach of a motivated private adversary.

Git's mitigations: it uses the hardened `sha1dc` implementation, which detects the bit-difference patterns all known collision attacks require and rejects such inputs; and a SHA-256 object format exists (since Git 2.29) as the long-term replacement, with ecosystem migration proceeding slowly.

Git-specific detail: object IDs hash `blob <length>\0<content>`, not the raw file bytes — so a file's Git ID differs from its `sha1sum`, and the length prefix forecloses certain trivial extension tricks.

## The precise epistemic position

Two independent claims requiring independent justification:

1. **"The probability of accidental collision is negligible"** — true, by the birthday bound, at a strength dominated by hardware error rates.
2. **"No one can manufacture a collision on purpose"** — false for SHA-1 since 2017; Git's continued safety rests on `sha1dc` and the practical difficulty of exploiting collisions within Git's object model, a materially weaker guarantee.

Ordinary same-repository operations — comparing one's own index against one's own HEAD — involve no adversary and sit entirely in pillar-one territory, where confidence is effectively total. The general lesson: "X is astronomically improbable" and "X cannot be caused deliberately" are different theorems, and SHA-1 is the canonical case where the first survived while the second fell.
