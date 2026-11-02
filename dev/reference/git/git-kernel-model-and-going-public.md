---
title: Git the kernel way, and bridging a solo dev with agent worktrees to a public, forkable project
description: How Linus Torvalds designed git and how the Linux kernel actually uses it (trees, maintainers, mailing-list patches, pull requests), mapped onto what CodeNforce must add to go from one machine with agent worktrees to a codebase strangers can fork, patch, and send merge requests to
published: true
date: 2026-10-29T00:00:00.000Z
tags: git, development, explanation, open-source, governance, agent-workflow, type:explanation
editor: markdown
dateCreated: 2026-10-29T00:00:00.000Z
---

# Git the kernel way, and the bridge from "solo + agents" to "strangers can contribute"

**Audience:** the solo maintainer (and anyone helping) who already runs one repo with a few agent
worktrees and now wants to know what changes when people on the network can fork it, patch it, and
send changes back.

**Doc type:** explanation (Diátaxis), with a checklist and a command sheet at the end.

**Read first (optional):** [git-mental-model](/dev/reference/git/git-mental-model) covers objects,
refs, HEAD and linked worktrees. This page does not repeat it; it explains *why git is shaped that
way* and *how a very large project uses it with strangers*.

> **Provenance note.** Part 1 and Part 2 summarize git's history and the kernel's own process
> documents ([How the development process works](https://docs.kernel.org/process/2.Process.html),
> [Submitting patches](https://docs.kernel.org/process/submitting-patches.html)). Numbers such as
> cadence are approximate; check those documents before quoting them. Part 3 is CodeNforce-specific
> and reflects the repo as of **2026-10-29**.

---

## The one-screen version

| Question | Kernel answer | CodeNforce today | CodeNforce once public |
|---|---|---|---|
| Who decides what lands in the main line? | Linus, from pulls he trusts | ECD alone | ECD (plus named owners later) |
| Who proposes changes? | Anyone, as patches on a mailing list | Agents in worktrees, plus occasional collaborators (the `steve` remote) | Anyone, as merge requests from forks |
| What does "fork" mean? | Nothing special: it is just a clone | A GitLab fork | The same, and the default contribution path |
| How does a change prove its author may contribute it? | `Signed-off-by` (Developer Certificate of Origin) | Nothing | `git commit -s` (DCO), enforced in CI |
| Where is "who owns which area" written? | `MAINTAINERS` file | Subsystem registry | Registry slugs mapped into `CODEOWNERS` |
| How are conflicts between pending changes found early? | `linux-next`, an integration tree rebuilt daily | Per-branch, by hand | A throwaway integration branch in CI |
| How are releases cut? | Two-week merge window, then weekly release candidates, then a tag | `dbpatch_betaN` plus milestone tags | Same, with signed tags |

The rest of the page unpacks each row.

---

## Part 1. How git works, the way Linus built it

### Why it exists

In April 2005 the kernel project lost its free use of BitKeeper, the proprietary tool it had been
using. Linus Torvalds wrote git in days (the first commit to git's own repository is dated
2005-04-07) and was running the kernel on it within weeks. In July 2005 he handed maintainership of
git itself to Junio Hamano, who still maintains it.

His stated goals explain every odd corner of git:

- **Fast**, even on a repository as large as the kernel.
- **Distributed**: no server is special, and every clone carries the full history.
- **Cheap branching and merging**, because thousands of people work in parallel.
- **Integrity**: any corruption or tampering must be detectable.
- **Simple underneath**: a small set of data structures that tools can build on.

### The five ideas

1. **Content-addressed storage.** Every object is stored under the hash of its own content. The same
   bytes always produce the same name, and changing one byte changes the name.
2. **Four object types.** *blob* (file contents), *tree* (a directory listing), *commit* (a tree plus
   parents, author, message) and *tag* (a signed or annotated label on an object).
3. **Snapshots, not diffs.** A commit points at a complete tree. Diffs are computed when you ask.
4. **History is a graph.** Each commit names its parents, so the history forms a directed acyclic
   graph. A merge is simply a commit with two parents.
5. **A branch is a name.** A ref is a file containing a hash. Creating a branch writes 41 bytes, which
   is why kernel developers use hundreds of them.

You can see idea 1 directly. This command needs no repository:

```bash
echo 'test content' | git hash-object --stdin
# d670460b4b4aece5915caf5c68d12f560a9fe3e4
```

The hash is the SHA-1 of the header `blob 13` plus a NUL byte plus the content. Anyone on any
machine gets the same answer. That is what lets two strangers' repositories agree, without a server,
on what a given commit *is*. (Git can also use SHA-256; SHA-1 remains the default.)

### Plumbing and porcelain

Git is a toolkit of small programs in the Unix tradition, in two layers:

| Layer | Examples | Who uses it |
|---|---|---|
| **Plumbing** | `hash-object`, `cat-file`, `update-index`, `write-tree`, `commit-tree`, `update-ref`, `rev-list` | Scripts and other tools |
| **Porcelain** | `add`, `commit`, `switch`, `merge`, `rebase`, `log`, `stash` | People |

`git commit` is roughly "write the index as a tree, make a commit object pointing at it, move the
current branch ref". Knowing that, a "mysterious" state (detached HEAD, a branch that moved, a lost
commit) becomes a question about which ref points where. See
[git-three-trees-recovery-primer](/dev/reference/git/git-three-trees-recovery-primer) for recovery.

### The tools built for the kernel workflow

These ship with git because the kernel needed them:

| Tool | What it does | Kernel use |
|---|---|---|
| `git format-patch` | Turns commits into email-ready patch files, one per commit | Preparing a patch series |
| `git send-email` | Sends them to a list and people | Submitting |
| `git am` | Applies a mailbox of patches as real commits, keeping author and message | Maintainer accepting a patch |
| `git request-pull` | Writes the "please pull from my tree" message | Maintainer to Linus |
| `git merge`, signed tags (`git tag -s`) | Combine histories; prove a tip is the maintainer's | Pull requests carry a signed tag |
| `git bisect` | Binary-searches history for the commit that broke something | Finding regressions |
| `git shortlog`, `git blame`, `git log -S` | Authorship and history archaeology | Everyday |

`git bisect` has a policy consequence worth remembering: **every commit should build and work**, or
bisecting across it is useless. That is why kernel reviewers insist on small, self-contained
commits, and why this repo's "one logical change per commit" habit pays off.

Git itself is still developed the same way: patches by email to its list, reviewed in the open.

---

## Part 2. How the kernel project actually uses it

### There is no center, only convention

Git has no concept of a "main repository". The kernel's canonical tree lives on kernel.org because
everyone has agreed to pull from it, not because git says so. The copies on GitHub are read-only
mirrors; pull requests opened there are not part of the process. "Forking" is not a feature; it is
just cloning, and every clone is a peer.

That is the key idea to carry into Part 3: **being the official repository is a social fact you
establish with governance, not a technical state you configure.**

### The chain of trust

```text
 contributor (anyone)
      |  patch series by email, public review on the subsystem list
      v
 reviewers (anyone who knows the area)
      |  Reviewed-by / Acked-by / Tested-by
      v
 subsystem maintainer's own git tree (networking, filesystems, drivers, ...)
      |  daily: merged into linux-next to expose conflicts
      |  merge window: "please pull" with a signed tag
      v
 Linus's tree (mainline)  --- weekly release candidates ---> tagged release
      |
      v
 stable trees (back-ported fixes, maintained separately)
```

- **Linus does not review thousands of patches.** He reviews pulls from dozens of maintainers he
  trusts. Trust is earned over time and recorded in `MAINTAINERS`.
- **Responsibility is written down.** `MAINTAINERS` names who owns each path; a helper script
  (`scripts/get_maintainer.pl`) tells a contributor whom to send a patch to.
- **`linux-next`** is an integration tree rebuilt frequently from all the maintainers' trees. It is
  not a place to develop; it exists so conflicts between *pending* changes show up before the merge
  window rather than during it.
- **Rhythm.** After a release there is a short merge window (about two weeks) where new features are
  pulled in. Then weekly release candidates (`-rc1`, `-rc2`, ...) accept fixes only, until the
  release. A cycle runs roughly two to three months. A predictable rhythm is what lets thousands of
  people plan.

### What a contribution looks like

- **One logical change per patch**, in a series if needed. Each commit builds.
- **Subject line `area: short summary`**, and a body that explains *why*, not just what.
- **Trailer tags** that record who did what: `Signed-off-by`, `Reviewed-by`, `Acked-by`,
  `Tested-by`, `Reported-by`, `Fixes:` (the commit being repaired), `Cc:` (including
  `stable@vger.kernel.org` for fixes that should be back-ported).
- **Public review in plain text.** Reviewers reply inline to the patch. The author revises and
  resends as v2, v3, and so on.
- **The Developer Certificate of Origin.** `Signed-off-by` is a statement by the *human author* that
  they have the right to submit the work under the project's license. It is a lightweight
  alternative to a signed contributor license agreement, and `git commit -s` adds it.

Modern kernel contributors often use the `b4` tool together with the lore.kernel.org mail archive
instead of raw `send-email` and `am`, but the model is the same: a patch is text, and review is
public.

### Why it scales

Four properties make this work for thousands of contributors, and they are the ones to copy:

1. **Small, reviewable units** with explanations.
2. **Named owners** for each area.
3. **A single integrator** who accepts only from people accountable for what they send.
4. **A rhythm** so everyone knows when changes can land.

---

## Part 3. The bridge: from one machine to a public project

### Where CodeNforce is now

You are already running the kernel model in miniature:

| Kernel role | Your equivalent today |
|---|---|
| Linus | ECD: the only person who merges to `master` |
| A subsystem maintainer's tree | An agent's branch in its own worktree |
| Patch series | The agent's commits on that branch |
| Mailing-list review | Per-hunk review with [git add -p](/dev/reference/git/agent-edit-review-git-add-patch), then a merge |
| Merge window and release | `dbpatch_betaN` batches and [milestone tags](/dev/reference/git/git-tagging-quick-reference) |
| `Cc:`-style provenance | The `Co-authored-by: Copilot` trailer |

Two facts about the repo as of 2026-10-29 matter:

- `origin` is `gitlab.com/echocharliedelta/codenforce`, and a **second remote, `steve`, already
  points at a collaborator's fork**. You have already done the fork workflow once: `git fetch steve`,
  look at what is on his branch, decide whether to merge it.
- The repository root has `LICENSE_GPLv3`, `.gitlab-ci.yml`, `.gitignore`, and a
  `.pre-commit-config.yaml`, but **no** `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
  `CODEOWNERS`, or merge-request template.

### A ladder, not a leap

Each rung adds exactly one capability, and you can stop on any rung:

| Rung | What you have | What it adds | What you must add |
|---|---|---|---|
| 0 | One folder, one branch | Nothing | Nothing |
| 1 | Worktrees on one machine | Parallel agents, isolated files | A rule that each agent owns a distinct set of files |
| 2 | One remote (GitLab) | Backup, a shared reference, CI | A protected default branch |
| 3 | Forks and merge requests | Strangers can propose changes | Governance files, DCO, secret hygiene, CI gate |
| 4 | Email patches (optional) | Review without any hosting account | Almost never worth it for this project |

The jump from rung 1 to rung 3 is smaller than it looks, because **a worktree and a fork are the
same idea at different distances**:

- A **worktree** is a second folder on your machine that shares your object store. Its branch is a
  proposal; you merge it after review.
- A **fork** is a second repository on someone else's account, with its own refs and its own
  permissions. Its branch is a proposal; you merge it after review.

In both cases the proposal is **untrusted input to `master`**. The same review gate applies to an
agent and to a stranger. What changes is the evidence you have about the author, which is why the
extra governance below exists.

### What to put in place

Ordered by how much damage skipping each one can do.

#### 1. History hygiene (before the repo is advertised)

- **Git history is permanent and public once public.** A secret removed in a later commit is still
  in the history, and every fork copies it.
- Review the **whole history, not just the tip**, for connection strings, credentials, API keys,
  personal data, and any data that identifies a municipality's residents or staff. One-off data
  scripts and exports at the repo root or in database folders are the usual suspects.
- Do it with a dedicated scanner (for example `gitleaks` or `trufflehog`) run by **you**, not an
  agent, and wire the same scanner into `.pre-commit-config.yaml` and CI so it keeps working.
- If something is found: rotate it first, then rewrite history (`git filter-repo`) and have
  everyone, including the `steve` fork, re-clone. Rotating comes first because a rewrite does not
  un-leak what was already fetched.
- Keep local-only configuration in `.gitignore`, and keep real data out of the repository.

> This item is deliberately **human-only**, matching the repo rule that agents never search for
> credentials or touch databases.

#### 2. A license that tooling can see

The license file is named `LICENSE_GPLv3`. Hosting sites and package tools look for conventional
names (`LICENSE`, `COPYING`), so consider renaming it. The kernel itself uses `COPYING` plus a
`LICENSES/` directory with SPDX identifiers. For GPLv3 the rule of thumb is "inbound equals
outbound": contributions come in under the same license the project goes out under.

#### 3. Contribution rules a stranger can read

Add `CONTRIBUTING.md` (short, linking here and to
[git-branch-commit-conventions](/dev/reference/git/git-branch-commit-conventions)), a
`CODE_OF_CONDUCT.md`, and a `SECURITY.md` that gives a **private** reporting path. A code
enforcement system holds municipal data, so "file a public issue with the stack trace and
screenshots" must not be the advice for vulnerabilities.

What `CONTRIBUTING.md` should state, in the kernel's spirit:

- One logical change per merge request; every commit builds.
- Branch grammar `<type>/<slug>-<itemID>-<kebab>` and commit subjects that cite the item id.
- The three-tier architecture rules (integrators, coordinators, backing beans) and where the
  [style guide](/dev/architecture/constitution) checks come from.
- Explain *why* in the commit body.
- Sign off every commit.

#### 4. Identity and the DCO

Adopt the **Developer Certificate of Origin** rather than a contributor license agreement: it is
lighter and widely understood. Contributors run `git commit -s`; CI rejects commits without a
matching `Signed-off-by`.

One CodeNforce-specific rule follows from what the DCO means: it is a **human's** certification. An
agent's `Co-authored-by` trailer records provenance, but the `Signed-off-by` must belong to a person
who reviewed the change and takes responsibility for it, which for agent work is you.

#### 5. Make `master` a protected, gated branch

- No direct pushes; changes arrive only through merge requests.
- Required: the pipeline must succeed, and only a maintainer may merge. With one maintainer, that
  already gives you the review gate. Per-MR approval rules and code-owner enforcement can depend on
  your GitLab tier; check before relying on them (a `CODEOWNERS` file is useful as documentation
  either way).
- Merge with `--no-ff` per the existing convention so a feature is one visible bubble in history.

The repo already has a `.gitlab-ci.yml`. Confirm what it gates; the target is a build and the unit
tests on every merge request.

#### 6. Name the owners

Create `CODEOWNERS` keyed on the registry's canonical slugs and on the package and directory paths
that belong to each subsystem. Today every line names ECD. The point is the *shape*: when a second
owner appears, the file already says where their authority starts. This is your `MAINTAINERS` file.

#### 7. A merge-request template

Put a template under `.gitlab/merge_request_templates/` that asks for: item id, subsystem slug,
whether a database patch is included, whether `dbFixedValueLookup.properties` changed, and a
checklist drawn from the style guide's violation signals.

#### 8. A cheap `linux-next`

When two open merge requests touch the same files you want to learn that *before* merge day. A
nightly job that merges every open feature branch into a throwaway `integration` branch and builds
it gives you that. Do not build it until two contributors are active at once.

### The problem unique to this project: numbered database patches

The constitution says schema patches are `dbpatch_betaN.sql` with **N = highest existing + 1**,
monotonic, never reused or skipped. That is a perfectly good rule for one author. With two open
merge requests, **both will claim the same N**, and neither knows until the second merge conflicts.

The kernel has no sequence numbers to collide on. Options here:

| Option | How it works | Trade-off |
|---|---|---|
| **A. Maintainer assigns N at merge** (recommended) | Contributors name their file `dbpatch_betaNEXT_<topic>.sql`; ECD renames it to the next number when merging, then runs it | Keeps the monotonic rule and ECD's role as the only person who touches the database |
| B. Timestamped names | `dbpatch_20261029_topic.sql` | No collisions, but loses ordering clarity and breaks the existing convention |
| C. Reservation issue | A contributor claims a number in an issue first | Extra process for little benefit |

Option A also matches how the project already behaves: database scripts are **human-only** to review
and run. If the patch seeds an ID that Java code references, the matching
`dbFixedValueLookup.properties` change must travel in the same merge request and be renumbered
consistently at merge.

### Handling agents and strangers with the same pipeline

| Step | Agent in a worktree | Stranger from a fork |
|---|---|---|
| Branch lives in | `../cnf-agent-N` on your disk | Their fork on GitLab |
| You get it by | Already local | `git fetch <remote>` or `glab mr checkout` |
| First look | `git diff` and `git add -p` per hunk | `git diff master...<remote>/<branch>` |
| Gate | Build, tests, violation greps | The same, plus CI and DCO |
| Landing | `git merge --no-ff` | `git merge --no-ff` (or the MR Merge button) |
| Accountability | You sign off | You sign off *after* their `Signed-off-by` |

Build the second column's gate once; both columns use it.

### Release rhythm

You already batch changes into numbered database patches and milestone tags. Keep that as your
merge window: accept features into a release for a stated period, then freeze and accept only fixes
until the tag. Use **annotated, signed** tags (`git tag -s`) for releases so anyone can verify the
tip is yours. The `releasenotes` page remains the user-facing record.

### What not to copy

The kernel's mailing-list machinery exists because of the kernel's scale and history. For a project
with a handful of contributors, forks and merge requests on GitLab give the same properties (public
review, attribution, small units) with far less ceremony. Revisit email patches only if a
contributor cannot or will not use a hosting account.

---

## Command sheet

### As a contributor (from a fork)

```bash
git clone git@gitlab.com:<you>/codenforce.git
git remote add upstream https://gitlab.com/echocharliedelta/codenforce.git
git fetch upstream
git switch -c feat/<slug>-<itemID>-<kebab> upstream/master
# work, commit with sign-off
git commit -s -m "feat(<slug>): <itemID> short summary"
git fetch upstream && git rebase upstream/master     # keep current before pushing
git push -u origin feat/<slug>-<itemID>-<kebab>      # then open the merge request
```

### As the maintainer (reviewing a fork or an agent worktree)

```bash
git fetch <remote>                                    # a fork; skip for a local worktree
git --no-pager log --oneline master..<remote>/<branch>
git diff master...<remote>/<branch>                   # three dots: only what the branch adds
git merge --no-ff <remote>/<branch>                   # after review, build, and DCO check
git --no-pager log --format=%B master..<remote>/<branch> | grep -c "Signed-off-by"
```

### Kernel-style, for reference

```bash
git format-patch -3 -o /tmp/out                       # last three commits as patch files
git send-email --to=<list> /tmp/out/*.patch
git am < mailbox                                      # maintainer applies, keeping authorship
git request-pull <base> <url> <signed-tag>            # "please pull" message
git tag -s v<x.y> -m "release <x.y>"                  # signed annotated tag
git bisect start; git bisect bad; git bisect good <rev>   # find the breaking commit
```

---

## Checklist: ready to open the door?

- [ ] Full-history secret and personal-data review done by a human; anything found rotated and, if needed, scrubbed.
- [ ] Scanner added to pre-commit and CI.
- [ ] License file discoverable by name.
- [ ] `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` (private reporting path) in place.
- [ ] DCO adopted and enforced in CI.
- [ ] `master` protected; merge requests only; CI and approval required.
- [ ] `CODEOWNERS` keyed on registry slugs.
- [ ] Merge-request template includes item id, database patch, and properties-file questions.
- [ ] Database patch numbering rule for contributors written down (Option A).
- [ ] README explains how another person spins up an instance.

## Related

- [Git mental model](/dev/reference/git/git-mental-model): objects, refs, and linked worktrees.
- [Git branch and commit conventions](/dev/reference/git/git-branch-commit-conventions): branch grammar, `--no-ff`, item id citation.
- [GitLab merge-request CLI primer](/dev/reference/git/gitlab-mr-cli-primer): reviewing merge requests with `glab`.
- [Per-hunk review of agent edits](/dev/reference/git/agent-edit-review-git-add-patch): the accept/reject gate for agent branches.
- [Git tagging quick reference](/dev/reference/git/git-tagging-quick-reference): annotated tags for releases.
- [System constitution](/dev/architecture/constitution): §4 git conventions and §5 database patches.
- [Subsystem registry](/system/subsystem-registry): canonical slugs, including the X-series entry for agent workflow.
