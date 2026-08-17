---
title: Git branch & commit conventions — naming, merge strategy, and history interrogation
description: Branch naming grammar, --no-ff merge policy, redundant itemID commit citation, milestone tagging, and the reachability/history commands that make deleted branches reconstructable
published: true
date: 2026-08-16T15:44:15.000Z
tags: git, development, tooling, workflow, conventions
editor: markdown
dateCreated: 2026-08-16T15:44:15.000Z
---

# Git branch & commit conventions

This document is the companion piece to
**[git-mental-model.md](/dev/reference/git-mental-model)**, which covers the object store, refs,
reachability, and worktrees from the ground up. That document explains *how git works*; this one
specifies *the conventions CNF actually follows on top of that mechanism* — branch naming, merge
strategy, commit-message discipline, and milestone tagging — plus the command set for
interrogating history before and after a branch is deleted.

Written for two audiences: Echo (who wrote the mechanism doc and doesn't need it re-explained)
and Steve or any future subcontractor (who needs the convention stated plainly enough to follow
without reconstructing the reasoning from git internals). Where a rule depends on the mechanism,
this doc links back to the relevant section of the mental-model doc rather than re-deriving it.

Governing document: **[constitution.md §4](/system/constitution#4-git-commit-conventions)**. This
page is the *explanatory* expansion of that section — worked examples, rationale, and the command
reference. The constitution stays short; this stays detailed.

---

## 1. Branch naming grammar

```
<type>/<slug>-<itemID>-<kebab>
```

| Field | Source | Values / format |
|---|---|---|
| `type` | Conventional Commits vocabulary | `feat`, `fix`, `docs`, `chore`, `refactor` |
| `slug` | Wikidocs subsystem registry | e.g. `workflow`, `letters`, `mapping`, `email` |
| `itemID` | The subsystem's dev index — the stable item id, **not** a sprint code | e.g. `13.5`, `III-H`, `FC-0` |
| `kebab` | A short human-readable descriptor of *this* branch's task | e.g. `predicate-whitelist`, `svix-sig-fix` |

**Worked examples from current CNF work:**

```
feat/workflow-13.5-predicate-whitelist
fix/email-svix-sig-timestamp-check
chore/db-pg17-upgrade
feat/mapping-parcel-zone-intersection
```

### Where the grant-sprint code goes — and where it doesn't

The sprint prefix (`lsa7`, `map3`, …) is real, useful information: it's what TCVCOG reporting
wants and what tells you *when* a thread of work happened. It is deliberately **not part of the
branch name**, for a reason grounded in the mechanism doc's reachability section: a branch name
is a mutable ref that gets deleted (`git branch -d`) the moment its dev-index item reaches `DONE`.
Anything encoded *only* in the branch name is gone the instant the ref is. The itemID persists
because it's re-stated in the commit message (§3, below) — content baked into an immutable
object. The sprint code has no equivalent permanent home in the commit itself, and doesn't need
one: it belongs in the **worklog**, which is where the constitution already says the durable
branch-to-work mapping lives (§3, Organ 1).

Concretely: `lsa7` is a worklog column, not a branch-name field.

```
## 2026-08-14
- workflow (feat/workflow-13.5-predicate-whitelist, lsa7): resolved gap 1 (slot/attribute
  conflation) — see dev index item 13.5
```

This also fixes the failure mode from the earlier `show-branch` log: an item that spans a sprint
boundary (`lsa7-docsci` → `lsa7-workflowimpl`, almost certainly one logical thread) no longer
needs two unrelated-looking branch names. It's one itemID (`workflow-13.5`) across however many
branches and sprints it actually takes, with each sprint's slice noted in the worklog instead of
smeared across the branch-naming axis that's about to be deleted.

---

## 2. Merge convention: `--no-ff`, always, for named work

```bash
git checkout master
git merge --no-ff feat/workflow-13.5-predicate-whitelist
```

**Why this is not optional.** A fast-forward merge just slides the branch pointer forward along
an existing chain — no new commit object, no record that a branch called
`feat/workflow-13.5-predicate-whitelist` ever forked off. `--no-ff` forces a merge commit with two
parent pointers even when a fast-forward is mechanically possible. Per the mental-model doc's
merge-outcomes section, that second parent pointer is stored in the commit object permanently —
so `git log --graph` keeps showing the fork-and-rejoin shape long after the branch ref itself is
deleted. This is the entire mechanism by which topology survives `git branch -d`; nothing about
the branch *name* survives, only the *shape* it left in the DAG.

This is doubly load-bearing for the milestone-gated subcontractor workflow: Steve's milestone
branches need `--no-ff` specifically so the merge commit is visible, dated evidence of a discrete
milestone integration event — contractually legible in a way a fast-forwarded, invisible merge
is not.

**Merge commit message convention:**

```
Merge branch 'feat/workflow-13.5-predicate-whitelist'

Resolves dev index item 13.5, gap 1 (slot/attribute dimension conflation).
See docs-overhaul-aug26 §12.5 for the registry crosswalk.
```

Git's default merge-commit template already includes the branch name; don't strip it. Add the
itemID and a one-line pointer to the relevant doc section — this is the second place (after the
individual commit subjects) where the itemID gets baked into something permanent.

---

## 3. Redundant itemID citation in commit subjects

```
feat(workflow): §13.5 slot/attribute predicate whitelist — resolve gap 1
```

Format: `<type>(<slug>): <itemID> <description>`

This feels repetitive with the branch name — it is, deliberately. The branch name is scaffolding;
per §1 above it disappears on `git branch -d`. The commit message is the only place the itemID
lives *after* that happens, because the message is part of the commit object's hash — immutable,
permanent, greppable regardless of what refs currently exist:

```bash
git log --oneline --all | grep '13\.5'
```

works identically before and after the branch is deleted, provided the itemID was in every
subject line and not only in the now-gone branch name. Putting the itemID in the branch name
*and* skipping it in the commit subject is the single most common way this convention silently
fails — the branch existing gives a false sense that the identifier is recorded somewhere durable
when it isn't yet.

---

## 4. Milestone tags

For milestone-gated subcontractor work (Steve's five-milestone T&M-capped agreement), a
lightweight tag at each milestone's closing commit gives a permanent, non-expiring marker
independent of whether the feature branch itself survives:

```bash
git tag milestone/mapping-m3-parcel-intersection <sha-of-final-commit>
git push origin milestone/mapping-m3-parcel-intersection
git branch -d feat/mapping-13-parcel-zone-intersection
```

`git tag --list 'milestone/*'` then gives a durable, addressable index of every milestone
endpoint, useful as the payment-triggering reference point independent of branch cleanup — see
the mental-model doc's tags section for the lightweight-vs-annotated distinction (lightweight is
sufficient here; reach for annotated only if you want a GPG-signed, dated record with its own
tagger identity — arguably worth doing for milestone tags specifically, since that *is* the kind
of thing that should carry a signature for contractual purposes).

---

## 5. Branch & history interrogation commands

Commands for answering "is this branch safe to delete," "what happened on this branch," and "can
I reconstruct this after the ref is gone." Cross-referenced against the reachability section of
the mental-model doc.

### Before deleting a branch

```bash
# Lists branches whose tips ARE reachable from HEAD — safe to -d
git branch --merged

# Same check against a specific ref instead of HEAD
git branch --merged master

# Lists branches whose tips are NOT reachable — -d will refuse these
git branch --no-merged

# Plumbing-level single-branch check; exit 0 = ancestor (safe), exit 1 = not
git merge-base --is-ancestor feat/workflow-13.5-predicate-whitelist master

# Commits on the branch NOT yet on master — empty output = fully integrated
git log master..feat/workflow-13.5-predicate-whitelist

# Divergence in both directions: < only on master, > only on the branch
git log --left-right --oneline master...feat/workflow-13.5-predicate-whitelist

# Visualize both branches' topology together before deciding
git log --oneline --graph --decorate master feat/workflow-13.5-predicate-whitelist
```

If the branch was integrated via squash or rebase (new SHAs, no shared ancestry), `--merged` and
`-d` will both say "not merged" even though the diff is fully in `master`. Verify with
`git log main..branch` (empty = actually integrated) and use `-D` deliberately — see the
mental-model doc's squash-merge caveat.

### After a branch is gone — reconstructing by itemID

```bash
# Full history of one dev-index item, regardless of how many branches/sprints it touched
git log --oneline --all | grep '13\.5'

# Same, but only on the currently checked-out branch's ancestry
git log --oneline | grep '13\.5'

# Full diff-and-message detail for every commit citing the item
git log --all --grep='13\.5' -p

# Just the merge commits for the item (topology view, not per-commit noise)
git log --all --grep='13\.5' --merges --oneline
```

`--grep` searches commit *messages*; it has nothing to search once a branch pointer that was the
only thing carrying that string is deleted — which is exactly the case for the itemID discipline
in §3 to matter.

### Milestone / tag inspection

```bash
# All milestone tags, most useful with a creation-date sort
git for-each-ref --format='%(refname:short) %(creatordate:short) %(subject)' refs/tags/milestone/ --sort=-creatordate

# Which commit a given milestone tag points to
git rev-parse milestone/mapping-m3-parcel-intersection^{}

# Full annotated-tag metadata, if annotated
git show milestone/mapping-m3-parcel-intersection
```

### Adjacent handy variations

```bash
# One-line log annotated with which local/remote refs point to each commit
git log --oneline --decorate --all

# show-branch: columnar view of several branches' ancestry at once
git show-branch feat/workflow-13.5-predicate-whitelist feat/mapping-13-parcel-zone-intersection master

# Format-controlled iteration over every branch, with itemID visible in the subject
git for-each-ref --format='%(refname:short)  %(objectname:short)  %(subject)' refs/heads/

# Find which branch(es) a specific commit was originally reachable from — reflog only,
# and only if the branch's own reflog hasn't expired (default 90d reachable / 30d unreachable)
git reflog show feat/workflow-13.5-predicate-whitelist

# Blame restricted to commits mentioning the itemID — useful when a file has mixed-purpose history
git log --all --grep='13\.5' --oneline -- path/to/file.java
```

---

## 6. Proposed constitution revision (§4)

Current constitution §4 establishes the branch grammar and the itemID-in-commit-subject rule
correctly, but doesn't say anything about merge strategy or milestone tags, and is silent on
where sprint codes belong — which is exactly the gap that produced the naming drift this document
was written to fix. Proposed replacement text:

> ## 4. Git & commit conventions
>
> - **Branches are short-lived and task-named:** `<type>/<slug>-<itemID>-<kebab>`.
>   - `type ∈ feat | fix | docs | chore | refactor` (Conventional Commits vocabulary).
>   - `slug` = registry slug.
>   - `itemID` = the dev index's stable item id where one exists (`III-H`, `FC-0`, `13.5`).
>   - Example: `feat/letters-III-H-compression`.
>   - **Grant-sprint codes (`lsa7`, `map3`, …) are worklog metadata, never a branch-name field.**
>     An item spanning multiple sprints keeps one branch-name identity across all of them; the
>     worklog line, not the branch name, records which sprint each entry belongs to.
> - **Merges into `master`/`main` use `--no-ff` for all named-item branches**, even when a
>   fast-forward is possible. The resulting merge commit's second parent pointer is the only
>   thing that survives branch deletion to preserve fork/rejoin topology in `git log --graph`.
> - **Commit subjects reference the item id** (`feat(letters): III.H parallelize compression`),
>   redundantly with the branch name, because the branch name does not survive `git branch -d`
>   and the commit message does. This redundancy is required, not optional — `git log --oneline
>   --all | grep III.H` must work identically before and after the branch is deleted.
> - **Milestone-gated work gets a lightweight tag** (`milestone/<slug>-<mN>-<kebab>`) at the
>   closing commit before the branch is deleted, giving a permanent, addressable reference point
>   for payment/contractual milestones independent of branch survival.
> - **The worklog records which branch (and sprint) each thread lived on.** Merge/delete a branch
>   when its dev index item reaches `DONE`; the worklog line and the itemID-tagged commit history
>   are the durable record after the branch is gone.

This keeps the section roughly the same length while closing three gaps: merge strategy is now
explicit rather than implied, milestone tags get a named home, and the sprint-code/branch-name
boundary is stated instead of left to be rediscovered the way it just was.
