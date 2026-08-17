---
title: Reviewing and Merging GitLab Merge Requests from the Command Line
description: Local-first workflow for reviewing, editing, and merging MRs without the GitLab web UI, including glab CLI usage.
published: true
date: 2026-08-17T00:00:00.000Z
tags: git, gitlab, glab, merge-requests, cli
editor: markdown
dateCreated: 2026-08-17T00:00:00.000Z
---

# Reviewing and Merging GitLab Merge Requests Locally

## Core concept

A merge request is, mechanically, nothing exotic: it's a branch on the remote plus metadata (discussion threads, approval state) layered on top by GitLab. Everything reviewable — commits, diff, code — is ordinary git objects, fetchable and inspectable with the tools you already use. The web UI is one lens on that data, not the data itself.

The conceptual shift: stop thinking "review the MR," start thinking "fetch the branch and compare it against the merge target."

---

## Getting the branch onto your machine

**Same-repo collaborator** (has Developer access, pushes branches directly — this is the current CNF setup with Steve):

```bash
git fetch origin
git checkout steve/mapping-milestone-2   # or whatever he named it
```

`git fetch` updates your local knowledge of all remote branches without touching your working tree — new commits land in your object database, and `origin/*` remote-tracking refs move. `checkout` then gives you a local branch tracking his.

**Fork-based contributor** (source branch lives on their fork): GitLab exposes a ref that resolves regardless of where the source branch physically lives:

```bash
git fetch origin merge-requests/22/head:mr-22
git checkout mr-22
```

Read as: "fetch the remote ref on the left, store it locally under the name on the right." Worth knowing even in the same-repo case — it's unambiguous, giving you exactly what GitLab considers the MR rather than a branch name you might mistype.

---

## Reading the change

The review question is: what does this branch add relative to where it will merge? In DAG terms — which commits are reachable from the MR branch but not from the target branch, and what's the cumulative diff?

```bash
# Commit list: reachable from mr-22, not reachable from master
git log --oneline master..mr-22

# Cumulative diff
git diff master...mr-22
```

### Two-dot vs. three-dot — the trap everyone falls into

- `git diff master..mr-22` (two dots) compares the **tips** of both branches. If `master` has moved since the MR branch forked, the diff gets polluted with everything `master` did since, shown in reverse.
- `git diff master...mr-22` (three dots) compares against the **merge base** — the common ancestor — showing only what the MR branch actually changed. This is almost always what you want for review.

Confusingly, `git log` inverts this convention: for `log`, two dots is the normal, useful one (`master..mr-22` = commits in mr-22 not in master). Git's UI archaeology at its finest — no consistent rule, just memorize the pair per command.

---

## Re-reviewing after revisions

The reviewer never has to re-read the whole branch from scratch.

```bash
git fetch origin
git range-diff master mr-22@{1} mr-22
```

`git range-diff` compares the old version of the branch against the new one — a diff *of diffs* — showing what changed between revisions of the MR rather than making you re-review everything. `mr-22@{1}` uses the reflog: "where this branch pointed before the last update." A simpler variant for a quick look:

```bash
git diff mr-22@{1} mr-22
```

---

## Making changes yourself

**Request changes, let them revise (the default for anything substantive).** They push new commits to the same branch; you `git fetch` and re-review with `range-diff` as above.

**Edit it yourself when it's faster than describing it.** If the branch lives in the shared repo:

```bash
git checkout steve/mapping-milestone-2
# make the edit
git commit -am "Normalize SRID handling in tile query"
git push origin steve/mapping-milestone-2
```

Two cautions:

1. **Coordinate before pushing to someone else's branch.** If they have unpushed local work, you've created a divergence they now have to reconcile. A one-line heads-up costs nothing.
2. **Contractual observation, not a git one:** if milestone payment is conditioned on *their* code push, interleaving your commits into a milestone branch muddies what counts as their delivered work. Keep edits as clearly attributed, separate commits — never amend or squash theirs — so the authorship record git already maintains stays legible for invoicing.

**Never rebase or force-push someone else's branch.** Rewriting published history that another person is building on is the one genuinely destructive move in this entire workflow. If a rebase is ever warranted on their behalf, do it on their machine, under their control.

---

## Fork mechanics (if a contributor forks instead of getting Developer access)

If they've ticked "Allow commits from members who can merge" on their MR, you can push directly to their fork:

```bash
git remote add steve git@gitlab.com:stevendsaylor/codenforce.git
git commit -am "Declare SRID on parcel geometry columns"
git push steve initial-mapping-db-patch:initial-mapping-db-patch
```

Sanity check after adding any collaborator remote — namespaces differ by one path segment and are easy to fat-finger:

```bash
git remote -v
```

**Note on CNF's current setup:** the fork model was evaluated and abandoned in favor of adding Steve as a Developer-role contributor on the main repo directly, with `master` branch protection enforced. Same-repo access with branch protection eliminates fork-remote bookkeeping entirely; the fork section above is retained for reference in case a future contributor arrangement reverts to it.

### Syncing a fork after upstream changes (if ever needed again)

One-time setup on the contributor's machine — their clone knows about their fork but not the upstream repo:

```bash
git remote add upstream git@gitlab.com:TechnologyRediscovery/boroughforge.git
git fetch upstream
```

Then, incorporating upstream changes:

```bash
# Merge — preserves history exactly as it happened
git checkout mapping-milestone-2
git merge upstream/master

# Rebase — replays their commits on top of new master, linear history
git rebase upstream/master
```

**For a git-newcomer on a fork-based MR: merge, not rebase.** Rebase rewrites published commits, forcing `git push --force-with-lease` to update the MR — workable, but force-pushing is not an operation worth teaching under deadline pressure. Rewritten SHAs also silently invalidate any line-anchored MR discussion threads. The merge is boring and safe: one merge commit, ordinary push, MR updates automatically, and the three-dot diff still isolates only their changes since the merge base moved forward with it.

If a conflict surfaces, it should surface on *their* machine, in *their* working tree — they're the one who has to reconcile their code against the schema or API change, with you available for questions, rather than you silently resolving it and them discovering the resolution later.

**Sequencing note:** if an upstream change (e.g., a schema migration) is coming regardless, push it early — before reviewing the next milestone, not after. Every commit written against the stale schema is rework. Syncing against `upstream/master` at the *start* of each milestone converts schema drift from a review-time surprise into a known starting condition — worth folding into the state-of-work rhythm.

---

## Merging

**Locally:**

```bash
git checkout master
git merge --no-ff mr-22
git push origin master
```

`--no-ff` forces a merge commit even when a fast-forward is possible, keeping the branch visible as a discrete unit in history. For milestone-based deliverables, that explicit "this blob of commits was milestone 2" structure in the DAG has direct value — it's what makes the git history itself legible as a record of contractual milestones, independent of GitLab's own metadata. GitLab detects the merge and closes the MR automatically once pushed.

**Via web UI** (still sometimes the better call): closes the MR tidily and records approval metadata coherently. Since TCVCOG-adjacent work may eventually need to answer audit-trail questions, the UI merge is the slightly more defensible habit when approval provenance matters — the CLI merge is faster but leaves GitLab's approval record unset even though the git history is identical either way.

---

## The CLI middle ground: `glab`

GitLab's official CLI wraps the MR metadata layer so you rarely need the browser at all:

```bash
glab mr list                 # see open MRs
glab mr checkout 22          # does the fetch-and-checkout dance for you
glab mr diff 22
glab mr view 22 --comments   # read the discussion thread without the browser
glab mr note 22 -m "parcel_geom needs SRID 2272 not 4326 — county data ships in State Plane South"
glab mr approve 22
glab mr merge 22
```

`glab mr checkout` is the one command actually worth adopting outright — it's the `refs/merge-requests` fetch above, without needing to remember the ref syntax. The rest is take-or-leave depending on how much browser time you want to eliminate.

**Install note (Ubuntu/amd64):** grab the `.deb` matching your architecture from GitLab's `glab` releases page — `dpkg --print-architecture` confirms `amd64` on tangoonefour — rather than a generic install script.

**SSH note:** if `glab mr checkout` fails with `Permission denied (publickey)` on a machine that has never SSH'd to gitlab.com before, that's an unregistered key, not a `glab` bug — GitLab needs the machine's public key added under user SSH settings before any `git@gitlab.com` operation (including the ones `glab` runs under the hood) will authenticate.

---

## Quick reference

| Task | Command |
|---|---|
| Fetch an MR by number | `glab mr checkout 22` or `git fetch origin merge-requests/22/head:mr-22` |
| List commits unique to the MR | `git log --oneline master..mr-22` |
| Full diff, merge-base isolated | `git diff master...mr-22` |
| Diff between MR revisions | `git range-diff master mr-22@{1} mr-22` |
| Comment without the browser | `glab mr note 22 -m "..."` |
| Merge, preserving branch unit | `git merge --no-ff mr-22` then `git push origin master` |
| Merge via CLI, closes MR | `glab mr merge 22` |

---

*Prepared as a command-line reference for CNF merge request workflow; supersedes ad hoc browser-UI review.*
