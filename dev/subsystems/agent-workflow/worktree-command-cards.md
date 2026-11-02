---
title: Worktree & Review Command Cards
description: One card per git command a human runs when orchestrating several coding agents on one repo via git worktrees, each with risk profile, flags, what it touches, undo, and pinned official-doc links.
published: false
date: 2026-10-29T00:00:00.000Z
tags: subsystem:agent-workflow, audience:dev, type:reference, status:draft
editor: markdown
dateCreated: 2026-10-29T00:00:00.000Z
---

# Worktree & Review Command Cards

> **Status: DRAFT, UNTESTED.** Every card below was written from the official Git documentation. **No command on this page has been executed** by the agent that drafted it (agents have no git-write access, by policy). Rehearse the whole sequence in a throwaway scratch repo under `/tmp` first: [primer Step 1](/dev/subsystems/agent-workflow/worktree-orchestration-primer#step-1-rehearse-in-a-scratch-repo).

These cards back the [worktree orchestration primer](/dev/subsystems/agent-workflow/worktree-orchestration-primer). The primer says *when* to run a command; the card says *what the command really does to Git's objects, refs, index, and config, and what it can break*.

## How to read a card

**Who runs it.** Every card on this page is **ECD only**. Agents are read-only outside the repo and `/tmp/`, git is read-only for agents, and everything else is blocked (see the [agent sandbox checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist)). The cards exist so that when the agent harness asks you to approve a command, or when you type one yourself, you know exactly what you are approving.

**Risk legend** (same convention as [removing a Linux user account](/dev/subsystems/server-architecture/removing-a-linux-user-account)):

- 🔵 **READ**: inspects state; writes nothing durable (see the optional-locks note under [O2](#o2-git-status-and-optional-locks)).
- 🟡 **REVERSIBLE**: changes the repo; an inverse command or a reflog entry restores it.
- 🔴 **DESTRUCTIVE**: can discard work that Git can no longer reconstruct. Always dry-run or look first.

**Fields.** Each card lists the command, **Risk** (with the reason), **Why a human gate**, **Touches** (which of working tree, index, refs, object store, config, `.git/worktrees/<id>/` it changes), **Flags**, **Refuses when / watch out**, **Undo**, **Verify**, and **Docs** (man page plus the exact source line at tag `v2.43.0`).

**Doc pinning.** The installed Git is **2.43.0**. The man pages on git-scm.com track the newest release (and `git-worktree/2.43.0` redirects to an older version), so every cite also links the AsciiDoc source **at tag `v2.43.0`** with a line number. A tag link never moves; the man-page link is for readability. Where a statement is *not* in the cited docs it is marked **(not in the docs: verify in rehearsal)**.

**Placeholders.** `<wt>` is the worktree path, `<branch>` follows the [branch grammar](/dev/reference/git/git-branch-commit-conventions) `<type>/<slug>-<itemID>-<kebab>`.

**Shared vs per-worktree, in one paragraph** ([git-worktree REFS][wt-refs], [gitrepository-layout][layout-hooks]): `HEAD` and the index are per-worktree; every ref under `refs/` (all branches, tags, **and `refs/stash`**) is shared, except `refs/bisect`, `refs/worktree`, `refs/rewritten`. The repo `config` is shared unless `extensions.worktreeConfig` is on. Hooks, `info/exclude`, branch reflogs and the object database live in `$GIT_COMMON_DIR` and are shared; only `logs/HEAD` is per-worktree ([layout `logs` L240][layout-logs]). Almost every hazard in the primer comes from one of these sharings.

---

## Group W: worktree lifecycle

### W1. Create a worktree on a new branch

```bash
git worktree add --lock --reason "agent <agentId> / <itemID>" \
    -b <branch> <wt> master
```

- **Risk:** 🟡 REVERSIBLE. Creates one directory and a few admin files; no existing file is modified.
- **Why a human gate:** It writes a new directory tree, creates a shared ref visible to every worktree, and fixes the branch name that later review and merge depend on. The agent sandbox cannot (and should not) write outside its assigned directory.
- **Touches:**
    - Working tree: creates `<wt>/` and checks out `master`'s files into it.
    - `<wt>/.git`: a *file* (not a directory) holding `gitdir: <main>/.git/worktrees/<id>`.
    - Admin dir: `$GIT_COMMON_DIR/worktrees/<id>/` with its own `HEAD`, `index`, `gitdir`, and (because of `--lock`) a `locked` file holding the reason ([DETAILS L343][wt-details]).
    - Refs: creates `refs/heads/<branch>`, **immediately visible in every worktree** (shared), and its reflog.
    - Hooks: runs `post-checkout` with the null-ref as first parameter, unless `--no-checkout` ([githooks L199][hook-postcheckout]).
    - Config and object store: unchanged (shared).
- **Flags:**
    - `-b <branch>`: create the branch at `<commit-ish>` and check it out. **Refuses if the branch already exists.** `-B` would instead *reset* an existing branch ([L189][wt-b]); do not use `-B` here, because silently resetting a branch is exactly the accident `-b` prevents.
    - `--lock` + `--reason`: equivalent to `git worktree lock` after `add`, "but without a race condition" ([L225][wt-lockopt], [L267][wt-reason]). Locked means it cannot be pruned, moved, or removed until you unlock it (W3), which makes teardown a deliberate act.
    - `<commit-ish>` (`master`): the start point. If omitted, `-b` defaults to `HEAD` of whichever worktree you run it from, so name it explicitly.
    - **Not used:** `-f/--force` lets two worktrees check out the same branch or reuse a missing path ([L172][wt-force]). Two writers on one branch defeats the design; never pass it.
- **Refuses when / watch out:**
    - `<branch>` is already checked out in another worktree (the safeguard `--force` overrides).
    - A new worktree starts with **no `target/`** (gitignored, so not checked out): the first Maven build is cold and per-worktree.
    - The docs call multiple checkout "still experimental" ([BUGS L513][wt-bugs]).
    - `<wt>` must sit inside the agent sandbox's `allowWrite` list *and* inside the VS Code workspace's mapped folders, or the agent cannot write to it.
- **Undo:** W5 (remove) then I3 (`git branch -d`). Nothing is lost: no commits exist yet.
- **Verify:** `git worktree list -v` (W2) shows `<wt>`, the commit, `[<branch>]`, and `locked` with the reason.
- **Docs:** [git-worktree](https://git-scm.com/docs/git-worktree) · [`add` L66][wt-add], [`-b` L189][wt-b], [`--lock` L225][wt-lockopt], [DETAILS L343][wt-details] · [githooks `post-checkout`][hook-postcheckout]

### W2. List worktrees

```bash
git worktree list -v               # human view; shows lock reasons
git worktree list --porcelain -z   # script view: stable, NUL-terminated
```

- **Risk:** 🔵 READ.
- **Why on this page:** it is the output you verify every other worktree command against, and the `--porcelain` form is the stable contract the sweep and dispatcher scripts parse.
- **Touches:** nothing; reads `$GIT_COMMON_DIR/worktrees/*`.
- **Flags:**
    - `-v`: adds the lock reason and prunable reason on indented lines ([LIST OUTPUT FORMAT L397][wt-listfmt]).
    - `--porcelain`: machine-readable and stable; each worktree is a block of `key value` lines, blocks separated by a blank line ([L239][wt-porcelain]).
    - `-z`: NUL instead of newline, so a path containing a newline cannot corrupt parsing ([L245][wt-porcelain]).
    - `-v` and `--porcelain` are alternatives in the synopsis; do not combine them.
- **Reading it:** `locked` = protected from prune, move, remove. `prunable` = the directory is gone but the admin entry remains; W6 clears it.
- **Docs:** [git-worktree](https://git-scm.com/docs/git-worktree) · [`list` L109][wt-list], [`--porcelain` L239][wt-porcelain], [LIST OUTPUT FORMAT L397][wt-listfmt]

### W3. Lock and unlock a worktree

```bash
git worktree lock   --reason "<why>" <wt>
git worktree unlock <wt>
```

- **Risk:** 🟡 REVERSIBLE. Creates or deletes the `locked` file in the admin dir.
- **Why a human gate:** lock state is the safety catch on W5 and W6; an agent must not be able to release it.
- **Touches:** `$GIT_COMMON_DIR/worktrees/<id>/locked` only.
- **Flags:** `--reason <string>` is stored as plain text in that file and shown by `list -v`.
- **Watch out:** a locked worktree is skipped by *automatic* prune too ([layout `worktrees/<id>/locked` L283][layout-locked]), so a locked-and-forgotten worktree lives forever. The sweep reports locked worktrees by age.
- **Undo / Verify:** the opposite command; `git worktree list -v`.
- **Docs:** [git-worktree](https://git-scm.com/docs/git-worktree) · [`lock` L118][wt-lock], [`unlock` L165][wt-unlock], [DETAILS L343][wt-details]

### W4. Move or repair a worktree

```bash
git worktree move   <wt> <new-wt>     # only after unlocking
git worktree repair [<wt>...]         # re-link after a manual mv
```

- **Risk:** 🟡 REVERSIBLE. Rewrites the two-way pointer between `<wt>/.git` and `$GIT_COMMON_DIR/worktrees/<id>/gitdir`.
- **Why a human gate:** these pointer files decide *which repository a directory belongs to*. A wrong pointer makes git in that directory act on a different `.git` (see "inspect the `.git` file" in the [sandbox checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist)).
- **Touches:** the worktree's `.git` file and `worktrees/<id>/gitdir`. The branch, index, and commits are untouched.
- **Flags:** `move` refuses a locked worktree unless `--force` is given **twice**; do not, unlock first. `move` cannot move the main worktree or a worktree with submodules. `repair`, run in the *main* worktree, re-links linked worktrees after the main one was moved ([`move` L125][wt-move], [`repair` L143][wt-repair], [`--force` L172][wt-force]).
- **Undo / Verify:** move it back, or `repair` again; then `git worktree list --porcelain` paths match reality and `cat <wt>/.git` shows the expected `gitdir:` line.
- **Docs:** [git-worktree](https://git-scm.com/docs/git-worktree) · [`move` L125][wt-move], [`repair` L143][wt-repair], [DETAILS L343][wt-details]

### W5. Remove a finished worktree

```bash
git worktree unlock <wt>
git worktree remove <wt>          # no -f. If it refuses, STOP and look.
```

- **Risk:** 🔴 DESTRUCTIVE. In the clean case it deletes a directory whose content is already committed or already discarded; with `-f` it discards uncommitted work.
- **Why a human gate:** it deletes a directory tree. Whether anything in it is un-reviewed work is a human judgment; the agent does not decide its own work is disposable.
- **Touches:** deletes `<wt>/` and its `worktrees/<id>/` admin dir. **The branch and its commits stay**: the ref is shared and untouched.
- **Flags:**
    - *(none)*: the safe form. "Only clean worktrees (no untracked files and no modification in tracked files) can be removed" ([L136][wt-remove]). That refusal is your safety net: leftover agent files block removal until you look at them.
    - `-f`: overrides the clean check. `-f -f`: also overrides a lock ([L172][wt-force]). **Never use either** on an agent worktree you have not reviewed.
- **Watch out:** the docs say only untracked files and tracked modifications block removal. They do not say what happens to *ignored* build output such as `target/`; expect it to be deleted with the directory. **(not in the docs: verify in rehearsal)** VS Code's *Delete Worktree* command is documented to remove ignored files "even when Git reports no changes" ([VS Code: remove a worktree][vsc-wt-remove]); that sentence is about the VS Code command, not about `git worktree remove`.
- **Undo:** none for uncommitted work. Committed work survives on the branch (`git branch -vv`; re-create a worktree with W1 minus `-b`).
- **Verify:** `git worktree list` no longer shows it; `ls <wt>` fails.
- **Docs:** [git-worktree](https://git-scm.com/docs/git-worktree) · [`remove` L136][wt-remove], [`--force` L172][wt-force]

### W6. Prune stale admin entries

```bash
git worktree prune -n -v     # dry run: report only
git worktree prune -v        # only after reading the dry run
```

- **Risk:** 🔵 READ for `-n`; 🟡 REVERSIBLE for the real run (deletes admin metadata only, never a working directory or commits).
- **Why a human gate:** it deletes `worktrees/<id>/` entries. If a worktree lives on an unmounted drive, pruning forgets it (the case `lock` exists for).
- **Touches:** `$GIT_COMMON_DIR/worktrees/<id>/` for entries whose directory is missing. Locked entries are skipped.
- **Flags:** `-n/--dry-run` removes nothing, reports ([L230][wt-dryrun]). `-v` reports what is pruned. `--expire <time>` prunes only entries older than `<time>` ([L261][wt-expire]).
- **Automatic pruning:** `git gc` runs `git worktree prune --expire 3.months.ago`; `gc.worktreePruneExpire` changes the grace period ([config gc L106][cfg-gc-prune]). A missing, unlocked worktree is silently forgotten after three months.
- **Undo:** `git worktree repair` re-links only if the directory still exists.
- **Verify:** `git worktree list` has no `prunable` lines.
- **Docs:** [git-worktree](https://git-scm.com/docs/git-worktree) · [`prune` L132][wt-prune], [`--dry-run` L230][wt-dryrun] · [config/gc][cfg-gc-prune]

---

## Group O: orientation (all read-only)

### O1. Where am I? Which repo does this directory belong to?

```bash
git rev-parse --show-toplevel --git-dir --git-common-dir
git rev-parse --git-path HEAD
```

- **Risk:** 🔵 READ.
- **Why on this page:** scripts and hooks that serve several worktrees must ask Git which paths are per-worktree instead of assuming `.git/`. The docs say so directly: "do not make any assumption about whether a path belongs to `$GIT_DIR` or `$GIT_COMMON_DIR`… Use `git rev-parse --git-path`" ([DETAILS L343][wt-details]).
- **Flags:** `--show-toplevel`: root of *this* working tree ([L260][revparse-top]). `--git-dir`: this worktree's private admin dir (`<main>/.git/worktrees/<id>` in a linked worktree). `--git-common-dir`: the shared `.git` ([L244][revparse-common]). `--git-path <p>`: resolves `<p>` correctly per Git's sharing rules, e.g. `HEAD` to the per-worktree path and `refs/heads/master` to the shared one ([L253][revparse-path]).
- **Docs:** [git-rev-parse](https://git-scm.com/docs/git-rev-parse) · [`--git-common-dir` L244][revparse-common], [`--git-path` L253][revparse-path], [`--show-toplevel` L260][revparse-top]

### O2. `git status` and optional locks

```bash
git status -sb --show-stash
git --no-optional-locks status --porcelain     # for monitors and sweep scripts
```

- **Risk:** 🔵 READ, with one caveat: plain `git status` may *refresh the index file* as a side effect, which takes the index lock.
- **Why on this page:** a monitoring script running `git status` inside an agent's worktree can collide with another git command in that same worktree. `GIT_OPTIONAL_LOCKS=0` / `--no-optional-locks` skips "optional sub-operations that require taking a lock", and the docs name this use: "useful for processes running in the background" ([git L201][git-nolock], [L959][git-optlocks]).
- **Flags:** `-s` short format, `-b` branch line ([L27, L31][status-short]). `--show-stash` shows the stash count, which is shared across worktrees ([L35][status-stash]). `--porcelain` is stable for scripts across versions and config ([L38][status-porc]).
- **Docs:** [git-status](https://git-scm.com/docs/git-status) · [git](https://git-scm.com/docs/git) · [`--porcelain` L38][status-porc], [`--no-optional-locks` L201][git-nolock], [`GIT_OPTIONAL_LOCKS` L959][git-optlocks]

### O3. Which branches exist, which are merged, where are they checked out?

```bash
git branch --show-current
git branch -vv                    # twice-verbose: also prints linked-worktree paths
git branch --merged master        # safe-to-delete candidates
git branch --no-merged master     # unmerged work: do NOT delete
```

- **Risk:** 🔵 READ.
- **Flags:** `--show-current` prints the current branch, or nothing if HEAD is detached ([L187][branch-cur]). `-vv` shows sha, subject, upstream, and **the path of the linked worktree** holding each branch ([L192][branch-vv]). `--merged <commit>` lists branches whose tips are reachable from `<commit>` ([L295][branch-merged]); `--no-merged` is the inverse.
- **Docs:** [git-branch](https://git-scm.com/docs/git-branch) · [`-vv` L192][branch-vv], [`--merged` L295][branch-merged]

---

## Group R: per-hunk review loop (inside one worktree)

This is the [existing single-tree review loop](/dev/reference/git/agent-edit-review-git-add-patch) run **inside the agent's worktree**, with one change: stash entries are tagged with the worktree name, because `refs/stash` is shared (R5). Every command below is run by ECD with the current directory set to the agent's `<wt>`.

### R1. What did the agent create that `git diff` cannot show?

```bash
git ls-files --others --exclude-standard -z
```

- **Risk:** 🔵 READ.
- **Why it matters:** `git diff` and `git add -p` only look at *tracked* files. A brand-new file written by an agent is invisible to both until it is tracked or marked intent-to-add (R3). `.gitignore` is honoured, so `target/` is hidden.
- **Flags:** `-o/--others` shows untracked files ([L53][lsfiles-o]). `--exclude-standard` applies `.git/info/exclude`, per-directory `.gitignore`, and the user's global excludes ([L125][lsfiles-excl]). `-z` NUL-terminates and does not quote names ([L99][lsfiles-z]).
- **Docs:** [git-ls-files](https://git-scm.com/docs/git-ls-files) · [`-o` L53][lsfiles-o], [`--exclude-standard` L125][lsfiles-excl]

### R2. Baseline: stage the pre-agent state

```bash
git status --porcelain          # must be empty first
git add -A
```

- **Risk:** 🟡 REVERSIBLE. Changes this worktree's index only.
- **Why a human gate:** `git add -A` stages *everything*, including content nobody has reviewed. Run at the right moment it makes the agent's later edits show up in `git diff`; run at the wrong moment it silently blesses them.
- **Touches:** this worktree's **index** (per-worktree, so other worktrees are unaffected) and the object database (staged content is stored). No refs change.
- **Flags:** `-A/--all` "adds, modifies, and removes index entries to match the working tree" ([L130][add-A]). Ignored files are not added by default ([DESCRIPTION L17][add-desc]).
- **Rule:** run it **at dispatch time on a clean worktree, before the agent's first edit**, never after. After the agent has edited, use R3 then R4.
- **Watch out:** it also stages any untracked file that `.gitignore` does not cover, such as a stray secrets file. The empty `status --porcelain` check first is what protects you.
- **Undo:** `git restore --staged .` (`-S/--staged` restores only the index, [git-restore L58][restore-staged]). Working-tree files are untouched.
- **Docs:** [git-add](https://git-scm.com/docs/git-add) · [`-A` L130][add-A], [DESCRIPTION L17][add-desc]

### R3. Make new files visible to review

```bash
git add -N -- <new-file> ...        # intent-to-add: path recorded, content not staged
```

- **Risk:** 🟡 REVERSIBLE. Records only that a path will be added later.
- **Why:** afterwards the new file's whole content appears as an unstaged change in `git diff`, so it gets reviewed instead of slipping in via a later `git add -A`.
- **Not in the docs: verify in rehearsal.** The `add` page documents only the `git diff` (and `commit -a`) effect. Whether `git add -p` (R4) also offers an intent-to-add file as a hunk, and how `git stash push --keep-index` (R5) treats such an entry, is **not stated**. If either misbehaves, fall back to reviewing each new file whole with `git diff -- <file>` and then keeping it with `git add -- <file>` or removing it (R9).
- **Flags:** `-N/--intent-to-add`: "Record only the fact that the path will be added later. An entry for the path is placed in the index with no content. This is useful for, among other things, showing the unstaged content of such files with `git diff`" ([L154][add-N]).
- **Undo:** `git restore --staged -- <file>`.
- **Docs:** [git-add](https://git-scm.com/docs/git-add) · [`-N` L154][add-N]

### R4. Accept or reject changes hunk by hunk

```bash
git add -p
```

- **Risk:** 🟡 REVERSIBLE. Moves chosen hunks from the working tree into the index; the working-tree file itself is not modified.
- **Why a human gate:** this *is* the human review. Each `y` is you accepting a piece of the agent's code.
- **Touches:** this worktree's index only.
- **Keys** ([git-add L338-357][add-patch]): `y` stage this hunk · `n` do not stage this hunk · `q` quit, stage neither this nor remaining hunks · `a` stage this and all later hunks in the file · `d` stage neither this nor later hunks in the file · `g` go to a hunk · `/` search hunks by regex · `j`/`J` leave undecided and go to the next undecided / next hunk · `k`/`K` the same, backwards · `s` split the hunk · `e` edit the hunk by hand · `?` help.
- **Watch out:** `e` can produce a patch that no longer applies; deleting all lines of the patch stages nothing ([EDITING PATCHES L365][add-edit]). `a` accepts *all remaining hunks in that file*, so use it only after reading the file. Do not hold `y`. One-keystroke mode is C3.
- **Undo:** `git restore --staged -p` re-offers staged hunks for un-staging ([git-restore `-p` L48][restore-p]).
- **Docs:** [git-add (Interactive mode)](https://git-scm.com/docs/git-add#_interactive_mode) · [`-p` L96][add-p], [`patch` L330][add-patch]

### R5. Park the rejected hunks (worktree-tagged stash)

```bash
git stash push --keep-index -m "agent-rejected <wt-basename> <timestamp>"
```

- **Risk:** 🟡 REVERSIBLE. The rejected work is saved in a commit; it is not deleted.
- **Why a human gate:** it rewrites the working tree. Afterwards, rejected hunks are no longer on disk in the worktree; they are reachable only through the stash.
- **Touches:** the working tree and index of *this* worktree, **and the shared ref `refs/stash` plus its reflog**, which every worktree sees.
- **Flags:**
    - `push -m <message>`: the stash description ([git-stash L53][stash-push]). **Put the worktree basename in it**: the stash list is shared, and the message is the only reliable way to tell whose rejects are whose.
    - `-k/--keep-index`: "All changes already added to the index are left intact" ([L189][stash-keep]). The docs' own "Testing partial commits" pattern is `git add --patch`, then `git stash push --keep-index` to "save all other changes to the stash", then build and test what remains ([L339][stash-example]). That is also your moment to run `mvn package` on exactly the accepted state.
    - **Not used:** `-u` (include untracked) and `-a` (also ignored files, i.e. `target/`). Untracked agent files are not stashed; you decide per file (R1, R9).
    - `-p` (interactive stash) "implies `--keep-index`" ([L196][stash-patch]); not needed because you already staged with R4.
- **The hazard:** `stash@{0}` is whatever was stashed **last in any worktree**. Another worktree stashing between your push and your next command shifts every index, so never refer to a stash by a remembered `stash@{n}`. Resolve it by message each time (R6).
- **Undo:** `git stash apply <stash>` re-applies it ([L113][stash-apply]); the entry stays in the list until R7.
- **Docs:** [git-stash](https://git-scm.com/docs/git-stash) · [refs/stash L43][stash-ref], [`push` L53][stash-push], [`--keep-index` L189][stash-keep], [DISCUSSION L267][stash-disc] · [git-worktree REFS L279][wt-refs]

### R6. Inspect rejected hunks

```bash
git stash list                                   # ALL worktrees' stashes
git stash show -p "stash@{<n>}"                  # patch form of one entry
git diff "stash@{<n>}^2" "stash@{<n>}"           # just the rejected hunks
```

- **Risk:** 🔵 READ.
- **Why the `^2` diff works:** a stash is a commit whose *tree* is the working-tree state `W`, whose first parent is `HEAD` at the time, and whose second parent `I` records the index state ([DISCUSSION L267-282][stash-disc]). With `--keep-index`, `I` holds your accepted hunks and `W` holds accepted plus rejected, so `diff I W` is exactly what you rejected.
- **Flags:** `stash list [<log-options>]` names each entry, its branch, and a description ([L73][stash-list]). `stash show [<diff-options>] [<stash>]` shows a diffstat by default; `-p` gives a patch ([L89][stash-show]). `stash@{n}` selects by reflog position of `refs/stash` ([L43][stash-ref]).
- **Docs:** [git-stash](https://git-scm.com/docs/git-stash) · [`list` L73][stash-list], [`show` L89][stash-show], [DISCUSSION L267][stash-disc]

### R7. Discard a reviewed reject

```bash
git stash list                      # re-read it RIGHT NOW; confirm the message and n
git stash drop "stash@{<n>}"
```

- **Risk:** 🔴 DESTRUCTIVE. It removes the entry from the `refs/stash` reflog; the commit becomes unreachable and subject to garbage collection.
- **Why a human gate:** irreversible, and the shared stash makes "wrong entry" a real failure mode.
- **Touches:** shared `refs/stash` and its reflog.
- **Flags:** `drop [<stash>]` removes a single entry ([L138][stash-drop]). It defaults to `stash@{0}`, which can be *another worktree's* entry. Always name `<n>`.
- **Undo:** none through stash. In the short term the commit still exists as an unreachable object, but recovering it needs its hash, which `drop` prints.
- **Docs:** [git-stash](https://git-scm.com/docs/git-stash) · [`drop` L138][stash-drop]

### R8. Scope check: did the agent stay inside its fence?

```bash
git diff --name-status HEAD                 # tracked: what changed, and how
git ls-files --others --exclude-standard    # untracked: R1
git diff --cached --stat                    # what you accepted so far
```

- **Risk:** 🔵 READ.
- **Why:** compares what the agent *actually* touched with the scope card's owned and forbidden paths (hot files, `pom.xml`, `faces-config.xml`, `style.css`, the DB patch file). A forbidden path in this output is a review finding before you read any hunk.
- **Flags:** `--name-status` prints status letters and names ([L336][dopt-status]); `--name-only` just names ([L331][dopt-name]); `--stat` a diffstat ([L214][dopt-stat]); `--diff-filter=` selects by status such as `A`, `M`, `D` ([L633][dopt-filter]). `--cached` compares the index to a commit, default `HEAD` ([git-diff L43][diff-cached]); `--staged` is a synonym.
- **Docs:** [git-diff](https://git-scm.com/docs/git-diff) · [diff-options](https://git-scm.com/docs/diff-options) · [`--cached` L43][diff-cached], [`--name-status` L336][dopt-status]

### R9. Remove leftover untracked files

```bash
git clean -n -d          # dry run: list only
git clean -i -d          # then decide interactively
```

- **Risk:** 🔴 DESTRUCTIVE. Untracked files are in no commit and no stash; Git cannot recover them.
- **Why a human gate:** deletes data Git has never recorded. By default `git clean` refuses to run without `-f` or `-i` (`clean.requireForce`) for this reason ([L36][clean-f]).
- **Flags:** `-n/--dry-run` shows what would be removed ([L49][clean-n]). `-i/--interactive` lets you pick per path ([L44][clean-i]). `-d` recurses into untracked directories ([L28][clean-d]).
- **Never use:** `-x` (ignores `.gitignore`, so it removes `target/` and any ignored local config) or `-X` (removes *only* ignored files) ([L63, L71][clean-x]). A second `-f` also removes nested git repositories ([L36][clean-f]).
- **Undo:** none. That is why `-n` first is mandatory.
- **Docs:** [git-clean](https://git-scm.com/docs/git-clean) · [`-n` L49][clean-n], [`-i` L44][clean-i], [`-d` L28][clean-d], [`-x` L63][clean-x]

---

## Group I: integrate

### I1. Commit the accepted hunks (in the agent's worktree)

```bash
git commit -m "<itemID> <subject>"
```

- **Risk:** 🟡 REVERSIBLE (local, unpushed).
- **Why a human gate:** creates the commit object and moves the branch ref; per policy agents never commit. Under the [branch conventions](/dev/reference/git/git-branch-commit-conventions) the itemID belongs in the subject.
- **Touches:** object database (new commit), `refs/heads/<branch>` (shared), the branch reflog, `HEAD` of this worktree.
- **Flags:** `-m <msg>` ([L182][commit-m]). Do **not** pass `-n/--no-verify`: it bypasses the `pre-commit` and `commit-msg` hooks ([L214][commit-nv]).
- **Identity:** author and committer come from `user.name`/`user.email`. A per-worktree identity (C2) makes each branch's commits attributable.
- **Undo:** the commit stays reachable through the branch reflog. Un-committing (`git reset`) is **not carded**; write its card before using it.
- **Docs:** [git-commit](https://git-scm.com/docs/git-commit) · [`-m` L182][commit-m], [`--no-verify` L214][commit-nv] · [githooks](https://git-scm.com/docs/githooks)

### I2. Merge the branch into `master`, preserving the branch

```bash
# in the MAIN checkout, on master, with a clean tree:
git status --porcelain
git merge --no-ff --no-commit <branch>
git diff --cached --stat
git commit -m "Merge <branch> (<itemID>)"
```

- **Risk:** 🟡 REVERSIBLE until pushed (`git merge --abort` before the commit; `ORIG_HEAD` and the reflog after it). After a push, only `git revert -m 1` is acceptable (not carded; write its card first).
- **Why a human gate:** moves `master`, the integration branch. Merge order across worktrees decides who resolves conflicts, which is a human call.
- **Touches:** the main checkout's working tree and index, object database, `refs/heads/master`, `ORIG_HEAD`.
- **Where:** the **main checkout**, because `master` is checked out there and Git refuses to check out one branch in two worktrees. Agent worktrees never check out `master`.
- **Flags:**
    - `--no-ff`: fast-forward is the default when the current branch is an ancestor of the merged one, and "this behavior can be suppressed with the `--no-ff` option" ([git-merge L160-172][merge-ff], [merge-options L47][mopt-noff]). `--no-ff` forces a real merge commit so each item stays a visible unit in history, as the conventions page requires. It is what makes `git log --first-parent master` show one line per item ([rev-list-options L129][rl-first]).
    - `--no-commit`: perform the merge and stop before creating the commit ([merge-options L2][mopt-nocommit]), giving you a last look at the combined result.
- **Watch out:** "Running `git merge` with non-trivial uncommitted changes is discouraged" ([L58][merge-warn]): confirm a clean tree first. After a conflict, `git merge --abort` tries to reconstruct the pre-merge state ([L101][merge-abort]). Hot-file conflicts (`docs/worklog.md`, the dashboard, `style.css`) are *expected*; resolve by hand.
- **Undo:** `git merge --abort` while conflicted. After the merge commit exists but before any push, `ORIG_HEAD` is set to the pre-merge tip ([L41][merge-orig]); getting back to it needs `git reset --hard` (🔴, not carded: write its card first).
- **Verify:** `mvn clean package -DskipTests` (unpiped, per project rules), then `git log --first-parent -n 5`.
- **Docs:** [git-merge](https://git-scm.com/docs/git-merge) · [`--no-ff` merge-options L47][mopt-noff], [FAST-FORWARD MERGE L160][merge-ff], [`--abort` L101][merge-abort]

### I3. Delete the merged branch

```bash
git branch --merged master          # confirm it is listed
git branch -d <branch>
```

- **Risk:** 🟡 REVERSIBLE with `-d`; 🔴 with `-D`.
- **Why a human gate:** deletes a ref (and its reflog).
- **Flags:** `-d`: "The branch must be fully merged in its upstream, or in `HEAD` if no upstream was set" ([L98][branch-d]); this is the built-in safety check. `-D` is `--delete --force` and skips it ([L104][branch-D]): use only for a branch you have decided to abandon.
- **Order:** remove the worktree first (W5), then delete the branch. The docs do not state what `branch -d` does for a branch still checked out in a worktree, so do not rely on a refusal. **(not in the docs: verify in rehearsal)**
- **Undo:** the commits remain until gc; the tip hash is in the `-d` output.
- **Docs:** [git-branch](https://git-scm.com/docs/git-branch) · [`-d` L98][branch-d], [`--merged` L295][branch-merged]

---

## Group C: configuration, hooks, and logging (one-time setup)

### C1. Enable per-worktree config

```bash
git config --get core.bare       # must print nothing or false
git config --get core.worktree   # must print nothing
git config extensions.worktreeConfig true
```

- **Risk:** 🟡 REVERSIBLE, with a compatibility cost: it affects **every worktree and every tool** that reads this repo.
- **Why a human gate:** it changes repository format rules. "Older Git versions will refuse to access repositories with this extension" ([git-worktree L308][wt-config]). Any tool that reads the repo through its own Git implementation instead of the `git` binary may refuse it too. **(not in the docs: verify in rehearsal with your IDE and Maven git plugins)**
- **Touches:** `$GIT_COMMON_DIR/config` (one key). Afterwards each worktree also reads `$GIT_DIR/config.worktree`, which overrides the shared config ([extensions.worktreeConfig L10][cfg-ext]).
- **Pre-checks:** `core.worktree` must move to `config.worktree`, and so must `core.bare` if true ([L10][cfg-ext]). `git config --get` exits 1 and prints nothing when the key is absent ([L90][config-get]), which is the result you want; `core.bare` normally prints `false`.
- **Undo:** `git config --unset extensions.worktreeConfig`, after moving any worktree-scoped values you want to keep.
- **Verify:** `git config --show-scope --list` annotates each key with its scope (`worktree`, `local`, `global`) ([L248][config-scope]).
- **Docs:** [git-config](https://git-scm.com/docs/git-config) · [config/extensions L10][cfg-ext], [git-worktree CONFIGURATION FILE L308][wt-config]

### C2. Per-worktree identity

```bash
cd <wt>
git config --worktree user.name  "cnf-agent <agentId>"
git config --worktree user.email "agent-<agentId>@localhost"
```

- **Risk:** 🟡 REVERSIBLE. Needs C1 first: without `extensions.worktreeConfig`, `--worktree` silently behaves like `--local` and writes the *shared* config ([git-config `--worktree` L143][config-wt]), which would rename every worktree's identity.
- **Why a human gate:** identity is what review and audit trust.
- **Touches:** `$GIT_COMMON_DIR/worktrees/<id>/config.worktree`.
- **What it affects:** the author and committer of commits made in that worktree, and the identity recorded in reflog entries ([git L561, L575][git-author]). Under today's policy agents make no commits, so this attributes **the commits you make on the agent's branch**, and the commits of any future L2 agent; it is **not** a log of agent shell activity (that is C4).
- **Undo:** `git config --worktree --unset user.name`, and the same for `user.email`.
- **Docs:** [git-config](https://git-scm.com/docs/git-config) · [`--worktree` L143][config-wt], [`GIT_AUTHOR_NAME` L561][git-author]

### C3. One-keystroke hunk review

```bash
git config --global interactive.singleKey true
```

- **Risk:** 🟡 REVERSIBLE. Global config; affects every repo.
- **Effect:** answer `y`/`n`/`s` without pressing Enter in `add -p`, `checkout -p`, `restore -p`, `commit -p`, `reset -p`, `stash -p`. "Silently ignored if portable keystroke input is not available; requires the Perl module `Term::ReadKey`" ([config interactive L1][cfg-inter]).
- **Tradeoff:** speed versus accidental acceptance. Do not hold a key down.
- **Undo:** `git config --global --unset interactive.singleKey`.
- **Docs:** [git-config](https://git-scm.com/docs/git-config) · [interactive.singleKey L1][cfg-inter], [git-add L357][add-single]

### C4. Per-worktree Git activity log (trace2)

```bash
# NOT git config: set in the agent terminal's environment (see the sandbox checklist)
export GIT_TRACE2_EVENT=/tmp/agent-logs/<wt-basename>.jsonl
export GIT_TRACE2_ENV_VARS=AGENT_ID,AGENT_LEVEL,WORKTREE_ID
```

- **Risk:** 🟡 REVERSIBLE (unset the variables). Writes a log record on every Git invocation.
- **Why a human gate:** it decides what is recorded and where; the log path must be writable by the very process being logged.
- **Why env vars, not config:** "Trace2 config settings are only read from the system and global config files; repository local and worktree config files and `-c` command line arguments are not respected" ([config trace2 L1][cfg-trace2]). Per-worktree config cannot set it, so **per-worktree separation has to come from the environment of the process (the agent's terminal) that runs Git**.
- **Touches:** only the target file.
- **Flags:**
    - `GIT_TRACE2_EVENT=<absolute-path>`: JSON event stream, appended ([git L852][git-trace2], [api-trace2 L107][t2-event]). If the target is a directory, "traces will be written to files (one per process) underneath the given directory" ([target values L5][trace2-target]), which can mean thousands of files; one append file per worktree is easier to rotate. `trace2.maxFiles` caps directory targets ([config trace2][cfg-trace2]).
    - `GIT_TRACE2_ENV_VARS=a,b,c`: records the named environment variables in each trace, so agent identity and level are stamped on every Git command ([`trace2.envVars`][cfg-trace2]).
- **What each trace contains:** `cmd_name` (the Git subcommand and its parent hierarchy, [L463][t2-name]), `cmd_ancestry` (parent process names; "may not be implemented on all platforms", [L449][t2-ancestry]), `def_repo` with the **worktree path** ([L679][t2-repo]), `def_param` for config and env values ([L665][t2-param]), and `start`/`exit` with the argv and exit code.
- **Limits (be honest about them):** this is **transparency, not enforcement**. A process that controls its own environment can unset the variables, and the log file must be writable by that process, so it can also be edited. Use it to *detect accidents*, not to stop a hostile agent. The stronger design (separate Unix user plus a kernel audit trail) is an open question in the spec.
- **Docs:** [api-trace2](https://git-scm.com/docs/api-trace2) · [git (`GIT_TRACE2_EVENT`)](https://git-scm.com/docs/git) · [config trace2 L1][cfg-trace2], [target values L5][trace2-target]

### C5. Hooks for all worktrees (and who may write them)

```bash
git config core.hooksPath <abs-dir-outside-the-repo>     # or place files in $GIT_COMMON_DIR/hooks
chmod +x <abs-dir>/reference-transaction
```

- **Risk:** 🟡 REVERSIBLE, with **high impact**: hooks execute whenever *you* run the matching Git command.
- **Why a human gate:** a hook is a program that runs with your full user rights, **outside the agent sandbox**, the next time you run Git. Anyone who can write the hooks directory (or `.git/config`, which can also name programs through `core.fsmonitor`, `core.pager`, `core.editor`, `core.sshCommand`, [config core][cfg-core]) can run code as you. This is the strongest reason the hooks path must be **unwritable by agents** (see the [sandbox checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist)).
- **Shared by all worktrees:** `hooks` is a common-dir path, "ignored if `$GIT_COMMON_DIR` is set and `$GIT_COMMON_DIR/hooks` will be used instead" ([layout L165][layout-hooks]). One hook set serves every worktree, so a hook must identify its own worktree (`git rev-parse --show-toplevel`, O1).
- **Hooks worth having:**
    - `reference-transaction` ([L483][hook-reftx]): invoked by "any Git command that performs reference updates". The argument is `prepared`, `committed` or `aborted`; stdin has one line per ref, `<old-value> SP <new-value> SP <ref-name> LF`. A non-zero exit in the `prepared` state aborts the transaction, so this hook can *enforce* (for instance, refuse updates to `refs/heads/master` from a worktree below an authorization level); the exit status is ignored for the other states, and symbolic refs are not covered. Which commands fire it (branch create/delete, commit, merge, stash) is **to be confirmed in rehearsal**.
    - `post-checkout` ([L199][hook-postcheckout]): also runs after `git worktree add` (unless `--no-checkout`), a natural place to log worktree creation.
    - `post-commit` ([L181][hook-postcommit]) and `post-merge` ([L221][hook-postmerge]): notification only; they cannot affect the outcome of the command.
    - `pre-commit` ([L97][hook-precommit]) and `commit-msg` ([L165][hook-commitmsg]): can reject a commit; `git commit --no-verify` is documented to bypass them.
- **Mechanics:** the default is `$GIT_DIR/hooks`, changed with `core.hooksPath` ([githooks L20][hook-path], [config core L499][cfg-core-hooks]). Hook files without the executable bit are **ignored** ([L18][hook-exec]): the most common reason "my hook never ran".
- **Undo:** `git config --unset core.hooksPath`.
- **Docs:** [githooks](https://git-scm.com/docs/githooks) · [gitrepository-layout](https://git-scm.com/docs/gitrepository-layout) · [`reference-transaction` L483][hook-reftx], [`core.hooksPath` L499][cfg-core-hooks]

### C6. Keep the worklog mergeable across worktrees (decision needed)

```gitattributes
docs/worklog.md merge=union
```

- **Risk:** 🟡 REVERSIBLE, **with a data-shape risk**: the `union` driver "takes lines from both versions, instead of leaving conflict markers. This tends to leave the added lines in the resulting file in random order and the user should verify the result. Do not use this if you do not understand the implications" ([gitattributes L1094][attr-union]).
- **Why on this page:** the standing rule that every turn appends to the worklog guarantees a conflict between any two worktrees (`docs/worklog.md` has 60 touches in nine months, the dashboard 57). `union` removes the conflict for an append-only ledger.
- **Do not use it** on `docs/subsystem-status.md`: that is a table whose rows are *edited in place*, and `union` would keep both the old and the new row.
- **Status:** proposal only, recorded as an open question in the spec (📅 planned, codenforce repo). Do not add it until you have seen a merge result in a rehearsal.
- **Docs:** [gitattributes](https://git-scm.com/docs/gitattributes) · [built-in merge drivers L1073][attr-builtin], [`union` L1094][attr-union]

---

## Group A: audit (read-only)

### A1. What was merged, per item

```bash
git log --first-parent --merges -n 20 master
git log --since="2 weeks ago" --author="<agentId>"
```

- **Risk:** 🔵 READ.
- **Flags:** `--first-parent` follows only the first parent at each merge, giving one line per merged item ([L129][rl-first]). `--merges` prints only merge commits ([L109][rl-merges]). `--since`, `--author` filter by date and author pattern ([L24, L43][rl-since]).
- **Docs:** [git-log](https://git-scm.com/docs/git-log) · [`--first-parent` L129][rl-first], [`--merges` L109][rl-merges]

### A2. Every ref move, with time and identity

```bash
git reflog show HEAD                          # THIS worktree's HEAD history
git log -g --date=iso -n 20 refs/stash        # the shared stash's own history
```

- **Risk:** 🔵 READ.
- **Why:** the reflog is the recovery tool for most mistakes above and the cheapest audit trail already on (`core.logAllRefUpdates` is true here: "Updates to a ref are logged to `$GIT_DIR/logs/<ref>`", [config core L348][cfg-core-reflog]). `reflog show` is an alias for `log -g --abbrev-commit --pretty=oneline` ([git-reflog L39][reflog-show]).
- **Per-worktree vs shared:** `logs/HEAD` is per-worktree; branch and stash reflogs are shared ([layout `logs` L240][layout-logs]), so `git reflog show HEAD` run in an agent's worktree shows only what happened in *that* worktree.
- **Expiry:** `gc.reflogExpire` defaults to 90 days (30 for unreachable entries) ([config gc L114][cfg-gc-reflog]).
- **Docs:** [git-reflog](https://git-scm.com/docs/git-reflog) · [rev-list-options `-g` L308][rl-g]

---

## Deliberately not carded

- **`git checkout -p <stash> -- <file>`**: when a tree-ish is given it applies the chosen hunks in reverse onto the working tree *and* the index ([git-checkout `-p` L276][checkout-p]), which is easy to misread. The R6 diff plus a manual edit is safer.
- **`git rebase`, `git reset --hard`, `git push --force`, `git worktree add -f/-B`, `git clean -x/-X`**: each can discard or rewrite history or work; none is needed by the primer. If you reach for one, write its card first.
- **`git gc`, `git reflog expire`, `git prune`**: they delete the recovery net the cards above rely on.

---

[wt-add]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L66
[wt-list]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L109
[wt-lock]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L118
[wt-move]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L125
[wt-prune]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L132
[wt-remove]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L136
[wt-repair]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L143
[wt-unlock]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L165
[wt-force]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L172
[wt-b]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L189
[wt-lockopt]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L225
[wt-dryrun]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L230
[wt-porcelain]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L239
[wt-expire]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L261
[wt-reason]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L267
[wt-refs]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L279
[wt-config]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L308
[wt-details]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L343
[wt-listfmt]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L397
[wt-bugs]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L513
[layout-hooks]: https://github.com/git/git/blob/v2.43.0/Documentation/gitrepository-layout.txt#L165
[layout-logs]: https://github.com/git/git/blob/v2.43.0/Documentation/gitrepository-layout.txt#L240
[layout-locked]: https://github.com/git/git/blob/v2.43.0/Documentation/gitrepository-layout.txt#L283
[hook-exec]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L18
[hook-path]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L20
[hook-precommit]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L97
[hook-commitmsg]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L165
[hook-postcommit]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L181
[hook-postcheckout]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L199
[hook-postmerge]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L221
[hook-reftx]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L483
[add-desc]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L17
[add-p]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L96
[add-A]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L130
[add-N]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L154
[add-patch]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L330
[add-single]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L357
[add-edit]: https://github.com/git/git/blob/v2.43.0/Documentation/git-add.txt#L365
[stash-ref]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L43
[stash-push]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L53
[stash-list]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L73
[stash-show]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L89
[stash-apply]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L113
[stash-drop]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L138
[stash-keep]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L189
[stash-patch]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L196
[stash-disc]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L267
[stash-example]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L339
[clean-d]: https://github.com/git/git/blob/v2.43.0/Documentation/git-clean.txt#L28
[clean-f]: https://github.com/git/git/blob/v2.43.0/Documentation/git-clean.txt#L36
[clean-i]: https://github.com/git/git/blob/v2.43.0/Documentation/git-clean.txt#L44
[clean-n]: https://github.com/git/git/blob/v2.43.0/Documentation/git-clean.txt#L49
[clean-x]: https://github.com/git/git/blob/v2.43.0/Documentation/git-clean.txt#L63
[merge-orig]: https://github.com/git/git/blob/v2.43.0/Documentation/git-merge.txt#L41
[merge-ff]: https://github.com/git/git/blob/v2.43.0/Documentation/git-merge.txt#L160
[merge-warn]: https://github.com/git/git/blob/v2.43.0/Documentation/git-merge.txt#L58
[merge-abort]: https://github.com/git/git/blob/v2.43.0/Documentation/git-merge.txt#L101
[mopt-nocommit]: https://github.com/git/git/blob/v2.43.0/Documentation/merge-options.txt#L2
[mopt-noff]: https://github.com/git/git/blob/v2.43.0/Documentation/merge-options.txt#L47
[branch-cur]: https://github.com/git/git/blob/v2.43.0/Documentation/git-branch.txt#L187
[branch-vv]: https://github.com/git/git/blob/v2.43.0/Documentation/git-branch.txt#L192
[branch-d]: https://github.com/git/git/blob/v2.43.0/Documentation/git-branch.txt#L98
[branch-D]: https://github.com/git/git/blob/v2.43.0/Documentation/git-branch.txt#L104
[branch-merged]: https://github.com/git/git/blob/v2.43.0/Documentation/git-branch.txt#L295
[commit-m]: https://github.com/git/git/blob/v2.43.0/Documentation/git-commit.txt#L182
[commit-nv]: https://github.com/git/git/blob/v2.43.0/Documentation/git-commit.txt#L214
[config-get]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L90
[config-wt]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L143
[config-scope]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L248
[restore-p]: https://github.com/git/git/blob/v2.43.0/Documentation/git-restore.txt#L48
[restore-staged]: https://github.com/git/git/blob/v2.43.0/Documentation/git-restore.txt#L58
[checkout-p]: https://github.com/git/git/blob/v2.43.0/Documentation/git-checkout.txt#L276
[revparse-common]: https://github.com/git/git/blob/v2.43.0/Documentation/git-rev-parse.txt#L244
[revparse-path]: https://github.com/git/git/blob/v2.43.0/Documentation/git-rev-parse.txt#L253
[revparse-top]: https://github.com/git/git/blob/v2.43.0/Documentation/git-rev-parse.txt#L260
[status-short]: https://github.com/git/git/blob/v2.43.0/Documentation/git-status.txt#L27
[status-stash]: https://github.com/git/git/blob/v2.43.0/Documentation/git-status.txt#L35
[status-porc]: https://github.com/git/git/blob/v2.43.0/Documentation/git-status.txt#L38
[lsfiles-o]: https://github.com/git/git/blob/v2.43.0/Documentation/git-ls-files.txt#L53
[lsfiles-z]: https://github.com/git/git/blob/v2.43.0/Documentation/git-ls-files.txt#L99
[lsfiles-excl]: https://github.com/git/git/blob/v2.43.0/Documentation/git-ls-files.txt#L125
[diff-cached]: https://github.com/git/git/blob/v2.43.0/Documentation/git-diff.txt#L43
[dopt-stat]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L214
[dopt-name]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L331
[dopt-status]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L336
[dopt-filter]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L633
[rl-since]: https://github.com/git/git/blob/v2.43.0/Documentation/rev-list-options.txt#L24
[rl-merges]: https://github.com/git/git/blob/v2.43.0/Documentation/rev-list-options.txt#L109
[rl-first]: https://github.com/git/git/blob/v2.43.0/Documentation/rev-list-options.txt#L129
[rl-g]: https://github.com/git/git/blob/v2.43.0/Documentation/rev-list-options.txt#L308
[reflog-show]: https://github.com/git/git/blob/v2.43.0/Documentation/git-reflog.txt#L39
[git-nolock]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L201
[git-author]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L561
[git-trace2]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L852
[git-optlocks]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L959
[t2-event]: https://github.com/git/git/blob/v2.43.0/Documentation/technical/api-trace2.txt#L107
[t2-ancestry]: https://github.com/git/git/blob/v2.43.0/Documentation/technical/api-trace2.txt#L449
[t2-name]: https://github.com/git/git/blob/v2.43.0/Documentation/technical/api-trace2.txt#L463
[t2-param]: https://github.com/git/git/blob/v2.43.0/Documentation/technical/api-trace2.txt#L665
[t2-repo]: https://github.com/git/git/blob/v2.43.0/Documentation/technical/api-trace2.txt#L679
[trace2-target]: https://github.com/git/git/blob/v2.43.0/Documentation/trace2-target-values.txt#L5
[attr-builtin]: https://github.com/git/git/blob/v2.43.0/Documentation/gitattributes.txt#L1073
[attr-union]: https://github.com/git/git/blob/v2.43.0/Documentation/gitattributes.txt#L1094
[cfg-ext]: https://github.com/git/git/blob/v2.43.0/Documentation/config/extensions.txt#L10
[cfg-inter]: https://github.com/git/git/blob/v2.43.0/Documentation/config/interactive.txt#L1
[cfg-trace2]: https://github.com/git/git/blob/v2.43.0/Documentation/config/trace2.txt#L1
[cfg-gc-prune]: https://github.com/git/git/blob/v2.43.0/Documentation/config/gc.txt#L106
[cfg-gc-reflog]: https://github.com/git/git/blob/v2.43.0/Documentation/config/gc.txt#L114
[cfg-core]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L64
[cfg-core-reflog]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L348
[cfg-core-hooks]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L499
[vsc-wt-remove]: https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees#_remove-a-worktree
