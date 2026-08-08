# BoroughForge / codeNforce Wiki Documentation Workflow

## Purpose

This workflow governs how documentation moves from code-aware drafting into the published Wiki.js documentation site.

The documentation system uses three connected components:

1. The GitLab codeNforce source repository
2. The GitHub `boroughforge-wikidocs` repository
3. The Wiki.js documentation site backed by PostgreSQL and Git sync

## Core Principle

The GitHub `boroughforge-wikidocs` repository is the canonical source for published documentation.

Wiki.js renders documentation from the GitHub repository. The Wiki.js browser editor should not be used for normal editing of published pages.

## The Three-Writer Model

This repository has **three independent writers**, and every rule in this document exists to keep them from colliding:

1. **Human editors** — clone locally, edit, commit, push. Own everything except the generated-draft path.
2. **GitLab CI** — mirrors LLM-generated draft skeletons from the source repository. Owns `drafts/gitlab-generated/` and nothing else.
3. **Wiki.js Git sync** — pulls published content on a timer. Pushes only in the emergency-edit case (see below), and consider disabling push entirely.

The ownership partition is path-level: CI writes only to its draft directory, humans write everywhere else, and Wiki.js is (ideally) a reader. Each writer must assume the others may have pushed since it last looked, which is why the rebase-before-push discipline described below applies to **all three**, not just humans.

## System Roles

### GitLab Source Repository

The GitLab repository is used for code-aware drafting. LLM tools working inside the source repository may generate documentation skeletons using knowledge of the actual codebase.

GitLab CI mirrors generated draft documentation into the GitHub documentation repository.

GitLab CI owns only the generated draft area:

```text
drafts/gitlab-generated/
```

### GitHub Documentation Repository

The GitHub `boroughforge-wikidocs` repository is the canonical human-edited documentation repository.

Humans edit documentation by cloning this repository locally, editing in an IDE or text editor, committing, and pushing.

Published documentation lives in folders such as:

```text
dev/
sysadmin/
users/
properties/
permitting/
inspections/
cecases/
assets/
```

### Wiki.js Site

Wiki.js is the rendered documentation site.

Wiki.js imports changes from the GitHub documentation repository through Git sync.

The Wiki.js browser editor is reserved for emergency edits only. Any emergency browser edit must be reconciled into the Git history immediately — see the Emergency Edits section for the exact sequence, because doing it out of order arms a conflict trap.

## Rebase: What It Is and Why This Workflow Uses It

### The mechanics

Git history is a graph of immutable commits, each pointing at its parent. Two operations reconcile divergent lines of history:

- **Merge** creates a new commit with two parents. Both histories survive exactly as they happened, joined by a merge commit.
- **Rebase** rewrites one line of history as if it had been written on top of the other all along. Git finds the commits on your branch that the other line lacks, converts each into a patch, and replays those patches on the new base — producing **brand-new commits** with new SHAs. The originals are abandoned (recoverable via reflog for a while, but no longer part of any branch).

Before, where you committed A and B locally while the remote gained C and D:

```text
      A — B          <- your local commits
     /
X — Y — C — D        <- origin/main moved while you worked
```

After `git rebase origin/main`:

```text
X — Y — C — D — A' — B'    <- linear; A' and B' are new commits with the same content
```

### What `git pull --rebase` does

Plain `git pull` is fetch + merge: if you and the remote have both moved, it produces a merge commit ("Merge branch 'main' of github.com...") that records nothing except that two people edited concurrently. `git pull --rebase` is fetch + rebase: your local **unpushed** commits are replayed on top of the updated remote tip. History stays a straight line.

### Why rebase is safe *here*

The iron law of rebase: **never rewrite commits that anyone else has built upon.** Replacing published SHAs forces everyone downstream to reconcile against history that changed under them, and it is the operation that creates the need for force-pushing.

`git pull --rebase` satisfies this law by construction: the only commits it rewrites are your local unpushed ones, which nobody has seen. This is why rebase-pull is safe as a daily habit even for people who would never rebase a shared branch.

### Why rebase is *right* here

This repository is single-branch, multiple-writer, direct-push: no feature branches, no merge requests, everyone commits to `main`. In that topology, merge-pulls generate a content-free merge commit every time two writers overlap, and Wiki.js surfaces this Git history as the page-history view readers see. Rebase-pull keeps `main` linear, so the published history reads as a clean sequence of documentation edits.

Note the contrast with the codeNforce source repository, where milestone feature branches are merged with `--no-ff` precisely to **preserve** merge structure: there, branches are deliverable units worth seeing in the graph. Here, there are no units to preserve — just interleaved small edits — so linearity wins. Same principles, opposite conclusions, because the repository topologies differ.

### Cautions for using `--rebase` in other contexts

Do not carry this habit into situations where its safety condition fails:

- **Never rebase a branch that has been pushed and that anyone else may have fetched or built on.** In the codeNforce repository this means: never rebase a merge-request branch after review has begun, and never rebase another contributor's branch at all. Rewritten SHAs invalidate line-anchored review discussion and force downstream force-pushes.
- **Never resolve a rejected push with `--force`.** A rejected push means the remote moved; the answer is `git pull --rebase` (or a merge), never overwriting the remote. If you ever believe a force-push is necessary, stop and reconstruct how you got there first.
- **Conflicts during a rebase are resolved per replayed commit**, not once at the end. Three local commits touching contested lines may mean three resolution rounds, with `git rebase --continue` after each. If you get lost mid-rebase, `git rebase --abort` returns you cleanly to your pre-rebase state — nothing is lost.
- For prose documentation, conflicts are rare and small. In code repositories with long-lived branches, rebase conflicts compound; that is a reason to prefer merges there, not a reason to avoid `--rebase` pulls here.

## Standard Documentation Lifecycle

1. A code-aware LLM drafts a skeleton page in the GitLab source repository.

2. The file is placed under:

```text
drafts/gitlab-generated/
```

3. GitLab CI mirrors the generated draft into the GitHub documentation repository.

4. A human editor reviews the generated draft in a local clone of the GitHub documentation repository.

5. The human editor promotes useful content into the appropriate published documentation folder. Promotion includes the human revision pass and the AI-assistance disclosure required before publication.

6. The human editor commits and pushes changes to the GitHub documentation repository.

7. Wiki.js imports the changes during its periodic Git sync.

## Editing Rules

### Generated Drafts

Files under `drafts/gitlab-generated/` may be overwritten by GitLab CI at any time.

Do not treat generated draft files as durable human-edited documentation. Anything worth keeping gets promoted out of the draft path by a human commit.

### Published Documentation

Published documentation is edited in the GitHub documentation repository.

Do not edit published pages in the Wiki.js browser UI during normal work.

### Staging Discipline: Why `git add <changed-files>` and Never `git add .`

Human commits must stage files **by name**:

```bash
git add users/permits-overview.md dev/patch-conventions.md
```

Never `git add .` in this repository. The generated-draft path is tracked in Git and owned by CI; a blanket add from a working tree that contains mirrored drafts sweeps CI-owned files into a human commit, blurring the ownership boundary this entire document exists to define. The explicit add is not a stylistic preference — it is the human side of the same path-ownership rule imposed on the CI job below. Run `git status` first, read the list, stage what you actually edited.

## Emergency Wiki.js Edits

Emergency Wiki.js browser edits are allowed only when a published page must change faster than the Git flow allows.

The reconciliation sequence matters, because Wiki.js pushes on a **timer**, not immediately:

1. Make the emergency edit in the Wiki.js browser editor.
2. **Confirm the edit has reached GitHub before pulling.** Either trigger a manual sync from the Wiki.js admin storage panel, or verify on GitHub that the Wiki.js-authored commit exists. Pulling before the sync fires retrieves nothing and leaves a conflict armed: your next local edit to the same page will collide with the Wiki.js commit whenever it eventually lands.
3. Then, in your local clone:

```bash
git pull --rebase origin main
```

4. The emergency edit is now part of normal Git history, and subsequent edits to that page happen in the standard flow.

**Configuration recommendation:** if emergency edits are genuinely rare, configure the Wiki.js Git storage module for one-way sync (pull only, push disabled). An emergency edit then lives only in the Wiki.js database until a human transcribes it into the repository — deliberately inconvenient, which is the incentive to use the real flow, and it removes the third writer's push path entirely. If bidirectional sync is kept, the race described in step 2 exists permanently and this section is the mitigation.

## Conflict Avoidance Rules for GitLab CI

GitLab CI must not mirror or overwrite the entire GitHub documentation repository.

GitLab CI may only write to its explicitly owned generated-draft path:

```text
drafts/gitlab-generated/
```

The CI mirror job must not use broad commands such as:

```bash
git add .
rsync --delete ./ wiki-target/
```

The CI job stages and commits only known generated paths.

**The CI job needs the same rebase-before-push discipline as humans.** A human push can land between the CI job's clone and its push; without a pull, the job's push is intermittently rejected — and the tempting one-character "fix" of adding `--force` would overwrite human commits. The mirror script must include, immediately before its push:

```bash
git pull --rebase origin main
```

This is safe for the same structural reason it is safe for humans: the only commits being replayed are the job's own unpushed draft-mirror commits, confined to the CI-owned path, so the rebase cannot conflict with human edits elsewhere in the tree.

## Preferred Human Editing Flow

```bash
# One-time setup (a fresh clone is already current;
# no pull needed immediately after cloning)
git clone git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
cd boroughforge-wikidocs

# Each editing session begins by syncing:
git pull --rebase origin main

# edit documentation

# Review what changed, then stage by name -- never `git add .`
git status
git add <changed-files>
git commit -m "Update documentation"

# Close the race between your last sync and your push:
# if another writer pushed while you edited, this replays
# your commit on top of their work; then push.
git pull --rebase origin main
git push origin main
```

The second `pull --rebase` is not ritual: a push is rejected whenever the remote has moved since your last fetch, and in a three-writer repository the remote moves. Rebase-pull immediately before pushing closes that window.

## Summary

GitLab is the code-aware drafting system.

GitHub is the canonical documentation editing repository.

Wiki.js is the rendered documentation site.

Three writers share one branch; path ownership keeps their edits disjoint, and rebase-pull before every push keeps the shared history linear. Published documentation has one active source of truth: the GitHub documentation repository.
