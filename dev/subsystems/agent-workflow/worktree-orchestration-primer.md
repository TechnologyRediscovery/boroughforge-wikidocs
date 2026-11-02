---
title: Running Several Coding Agents at Once with Git Worktrees
description: Step-by-step primer for a solo Java developer who orchestrates simultaneous coding-agent sessions on one repository using git worktrees, with a per-hunk review loop (git add -p) per worktree. Every command links to a command card with flags, risk profile, undo, and pinned official-doc links.
published: false
date: 2026-10-29T00:00:00.000Z
tags: subsystem:agent-workflow, audience:dev, type:primer, status:draft, status:has-planned-ref
editor: markdown
dateCreated: 2026-10-29T00:00:00.000Z
---

# Running Several Coding Agents at Once with Git Worktrees

> **Status: DRAFT, UNTESTED.** Written from the official Git 2.43.0 documentation. **Nothing here has been executed.** The agent that drafted it has no git-write access, by policy. [Step 1](#step-1-rehearse-in-a-scratch-repo) is a rehearsal in a throwaway repo under `/tmp`; do it before touching the real repository, then correct this page and flip `published` to `true`.
> **Quadrant:** How-to, with a short explanation of the shared-state hazards (§2).
> **Audience:** a solo Java developer (ECD) who runs 2 to 3 agent sessions in parallel and reviews every change by hand.
> **Verified against:** Git 2.43.0 documentation (installed version), bash. Facts the documentation does not state are marked **(not in the docs: verify in rehearsal)**.

This primer says *when* to run each command. The [command cards](/dev/subsystems/agent-workflow/worktree-command-cards) say *what the command does to Git's objects, refs, index and config, which flags it uses, what can go wrong, and how to undo it*, each with pinned links to the official docs. Every command below carries a card ID such as [W1]; read the card before you run it for the first time.

> 📅 **Planned — Fall 2026.** Agent authorization levels and per-worktree git logging are specified but not built (codenforce repo, `docs/subsystems/agent-workflow/`). Until they exist, every agent in this primer runs at today's single level: **writes files inside its own worktree, no git writes, no network, no database**. The [sandbox checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist) covers how to enforce and observe that.

> **VS Code can create the worktrees for you, and that changes the security model.** The Agents window offers **New Worktree** isolation per session ([Choose where an agent makes changes][vsc-isolation]). Per VS Code's documentation:
>
> - **Worktree sessions use Allow all** and do not offer manual approval prompts ([same page][vsc-isolation]). The "decline the prompt" habit in [§0](#when-an-agent-harness-asks-you-to-approve-a-git-command) gives **no protection** there; only the sandbox restricts the agent. The documentation is explicit that a worktree "does not restrict commands, network access, or access to files outside the worktree."
> - The session's Changes view offers **Commit Changes** (commits all current changes to the session branch) and **Merge Changes** (commits any uncommitted worktree changes, then merges into the session's base branch; [Delegate two tasks][vsc-delegate]). Neither is a hunk-level gate, so [Step 9](#step-9-review-one-worktree-at-a-time) must come *first*.
> - A new worktree holds only committed files from the chosen base branch. Ignored files (including `target/`) are absent unless `git.worktreeIncludeFiles` copies them. The experimental `git.worktreeSymlinkFolders` symlinks a folder instead, and changes made through the symlink affect the folder in the original checkout ([isolation page][vsc-isolation]). Do not symlink anything an agent must not modify.
> - Merge Changes requires the parent repository to be on the session's configured base branch ([Delegate two tasks][vsc-delegate]).
>
> **Both routes sit on the same Git machinery**, so the command cards describe either. This primer's default is the **manual route**: ECD runs `git worktree add` ([W1]) and opens the agent in **Folder** isolation with Manual permissions. It is the only route where "agents never run git writes" is enforced by an approval prompt as well as by the sandbox. Whether to adopt the Agents-window route is an open decision (📅 spec question Q-AW-9). If you do, apply Steps 3 and 5 to 12 unchanged and treat the sandbox checklist as mandatory.

---

## 0. Ground rules

1. **ECD runs every git command.** Agents may read the repository and `/tmp/`; outside the repo and `/tmp/` everything else is blocked. Git is read-only for agents (`status`, `diff`, `log`, `show`, branch listing). They never `add`, `commit`, `stash`, `checkout`, `merge`, or touch `.git/`.
2. **One writer per working tree.** This is why worktrees exist: the existing [single-tree review loop](/dev/reference/git/agent-edit-review-git-add-patch) forbids two agents in one checkout, and a worktree gives each agent its own checkout without a second clone.
3. **Review is a gate, not a formality.** No agent edit becomes accepted state, and no branch reaches `master`, without ECD deciding it hunk by hunk ([R4]) and building the accepted result ([Step 9](#step-9-review-one-worktree-at-a-time)).
4. **A command you do not understand does not run.** If you (or an agent harness) are about to approve a git command, find its card first. Cards use a three-level risk legend: 🔵 READ, 🟡 REVERSIBLE, 🔴 DESTRUCTIVE.
5. **Stay with the cards.** `git rebase`, `git reset --hard`, `git push --force`, `git worktree add -f/-B`, `git clean -x/-X`, `git gc` are deliberately *not* carded ([not carded](/dev/subsystems/agent-workflow/worktree-command-cards#deliberately-not-carded)). If you reach for one, write its card first.

### When an agent harness asks you to approve a git command

| The command's card says | Do this |
|---|---|
| 🔵 READ (for example `git status`, `git diff`, `git log`) | Fine to approve. Prefer `git --no-optional-locks` in anything automated ([O2]). |
| 🟡 REVERSIBLE or 🔴 DESTRUCTIVE | **Decline.** Under current policy a git write from an agent is a policy breach, whatever the harness offers. Run it yourself after reading its card. |
| No card exists | Decline and note it. Do not approve what you cannot explain. |

This table applies only to sessions that *ask*. Under **Allow all**, **Autopilot**, `/yolo`, `/autoApprove`, or a VS Code **New Worktree** session, nothing asks, and the sandbox is the only control ([approvals][vsc-approvals]).

---

## 1. The model in one picture

```text
/…/cnf/codenforce/                  MAIN checkout (branch: master), ECD only
├── .git/                           the ONE repository: objects, refs, config, hooks
│   ├── refs/heads/*                ALL branches   (shared by every worktree)
│   ├── refs/stash                  THE stash      (shared by every worktree)   ← §2 hazard 1
│   ├── hooks/                      hooks          (shared by every worktree)
│   └── worktrees/<id>/             one private admin dir per linked worktree:
│        ├── HEAD  index  logs/HEAD     its own checked-out commit, staging area, HEAD log
│        ├── gitdir                     back-pointer to <wt>/.git
│        └── locked                     present if locked (the safety catch)
│
/…/cnf/codenforce-wt/AW-1-xxx/      LINKED worktree A  (branch: feat/xxx-AW-1-…)
│   ├── .git                        a FILE, "gitdir: …/codenforce/.git/worktrees/<id>"
│   └── (working files, own target/, own index)
/…/cnf/codenforce-wt/AW-2-yyy/      LINKED worktree B  (branch: feat/yyy-AW-2-…)
```

Per-worktree versus shared, from the [git-worktree REFS section][wt-refs] and the [repository layout][layout-logs]:

| Thing | Scope |
|---|---|
| Working files, `target/`, the index (staging area), `HEAD`, `logs/HEAD` | **Per worktree** |
| Every branch and tag, **and `refs/stash`**, their reflogs, the object store | **Shared** |
| Repo `config` | Shared, unless you enable per-worktree config ([C1]) |
| Hooks, `info/exclude` | **Shared** |

Git itself calls multiple checkout "still experimental" ([BUGS][wt-bugs]). That is one more reason to rehearse first.

---

## 2. Hazards: why this is not "just make more directories"

Each hazard is repeated where it bites. Hazards 1 to 3 are the ones that lose work or corrupt state.

1. **The stash is shared.** `refs/stash` is under `refs/`, so every worktree sees and rewrites the same stash list. `stash@{0}` is whatever was stashed last *anywhere*, and the numbers shift when another worktree stashes. The existing `agent-rejected` function reads `stash@{0}` and is therefore unsafe across worktrees. **Fix:** tag every stash message with the worktree name ([R5]) and resolve it by message every time ([R6]); name the exact `n` on a drop ([R7]). Helpers are in [Appendix A](#appendix-a-helper-functions-untested).
2. **Two agents, one DB patch number.** `dbpatch_betaN.sql` takes N = highest + 1. Two agents on two branches compute the same N. ECD reserves a number per item *before dispatch* (scope card, [Step 3](#step-3-write-the-scope-card)). Agents write the SQL as text only; ECD alone reviews and runs it.
3. **Hot files conflict by construction.** Touch counts from `git log` over the last nine months:

   | File | Touches |
   |---|---|
   | `style.css` | 82 |
   | `docs/worklog.md` | 60 |
   | `docs/subsystem-status.md` | 57 |
   | `systemHome.xhtml` | 50 |
   | `CaseCoordinator.java` | 48 |
   | `pom.xml` | 36 |
   | `LetterCoordinator.java` | 33 |
   | `.github/copilot-instructions.md` | 23 |
   | `faces-config.xml` | 20 |

   Rule: **a hot file is owned by at most one live worktree at a time.** The standing "update the worklog and dashboard every turn" rule makes `docs/worklog.md` and the dashboard conflict between any two worktrees, so the default here is that agents supply their worklog and dashboard text in their final message and ECD pastes it at merge. Whether to allow in-worktree edits with a `union` merge driver is an open decision ([C6]; 📅 spec question).
4. **Java and Maven.**
   - Each worktree has its own cold `target/` (it is gitignored, so a new worktree starts without one).
   - Network is blocked, so builds must be offline (`mvn -o`) and need the dependencies already in the shared `~/.m2`.
   - Use `package`, never `install`: `install` writes into the shared `~/.m2` and two parallel builds can collide there. **(Maven behaviour, not in the Git docs: confirm in rehearsal.)**
   - A WildFly deploy is a serialization point and ECD does deploys, one at a time.
   - One VS Code window per worktree costs one Java Language Server each.
5. **Attribution.** All agent shell commands run as the single Unix user `echocdelta`, so the OS cannot tell agents apart. Identity must be *stamped* (environment variables, trace2, per-worktree git identity); see the [sandbox checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist). This gives transparency and accident detection, **not** protection against a hostile agent.
6. **Write access to `.git` is code execution.** Hooks and config keys such as `core.fsmonitor`, `core.pager`, `core.editor`, `core.sshCommand` run programs with *your* rights, outside the sandbox, the next time *you* run git ([C5]). The worktree's `.git` **file** can also be repointed at a directory an agent controls. Agents therefore must not be able to write the main `.git/`, and ECD checks each worktree's `.git` file before running git there ([Step 9](#step-9-review-one-worktree-at-a-time)).
7. **Locks and prune.** A locked worktree is never pruned automatically ([W3]); an unlocked worktree whose directory vanished is forgotten after three months ([W6]). Lock on creation, unlock only at teardown.

---

## Step 0: Preconditions

Run from the **main checkout**, on `master`:

```bash
git --version                       # installed: 2.43.0
git status --porcelain              # must print nothing
git worktree list                   # main checkout only, or the worktrees you expect
git stash list                      # ideally empty; note anything already there
git config --get extensions.worktreeConfig   # prints nothing unless already enabled
```

| Command | Risk | Why | Docs |
|---|---|---|---|
| `git --version` | 🔵 READ | confirms the version these cards were pinned to | [git `--version`][git-version] |
| `git status --porcelain` | 🔵 READ | stable machine format; empty means clean ([O2]) | [status `--porcelain`][status-porc] |
| `git worktree list` | 🔵 READ | main worktree first, then each linked one ([W2]) | [worktree `list`][wt-list] |
| `git stash list` | 🔵 READ | the shared list ([R6]) | [stash `list`][stash-list] |
| `git config --get <key>` | 🔵 READ | exit status 1 and no output when the key is unset ([C1]) | [config `--get`][config-get] |

---

## Step 1: Rehearse in a scratch repo

**ECD runs this; agents never do.** The goal is to execute every command in the real sequence on a repository you can throw away, and to settle the facts the docs leave open.

Everything lives under `/tmp/wt-rehearsal`. A card ID in a trailing comment means *read that card first*.

```bash
export SCR=/tmp/wt-rehearsal
mkdir -p "$SCR"                       # shell, not git
git init -b master "$SCR/main"        # scratch card below
cd "$SCR/main"
printf 'target/\n' > .gitignore
printf 'line1\nline2\nline3\n' > a.txt
mkdir target && printf 'x\n' > target/out.class    # ignored build output
git add -A                            # [R2]
git commit -m "seed"                  # [I1]

# per-worktree config needs this first; [C1] then [C2]
git config extensions.worktreeConfig true          # [C1]

git worktree add --lock --reason "rehearsal A" -b feat/rehearse-AW-1-a "$SCR/wtA" master   # [W1]
git worktree add --lock --reason "rehearsal B" -b feat/rehearse-AW-2-b "$SCR/wtB" master   # [W1]
git worktree list -v                  # [W2]

git -C "$SCR/wtA" config --worktree user.name "cnf-agent A"     # [C2]
git -C "$SCR/wtA" config --worktree user.email "agent-a@localhost"
git -C "$SCR/wtA" config --show-scope --list | grep user.      # [C1] verify scope = worktree
```

Then simulate two agents writing at the same time, and exercise the review loop in A:

```bash
# "agent A" edits an existing file and adds a new one; "agent B" edits too
printf 'line1 CHANGED\nline2\nline3\nline4 NEW\n' > "$SCR/wtA/a.txt"
printf 'new file\n' > "$SCR/wtA/b.txt"
printf 'B edit\nline2\nline3\n' > "$SCR/wtB/a.txt"
mkdir "$SCR/wtA/target" && printf 'x\n' > "$SCR/wtA/target/out.class"   # simulated Maven output (ignored)

cd "$SCR/wtA"
git ls-files --others --exclude-standard     # [R1] must list b.txt, must NOT list target/
git add -N -- b.txt                          # [R3]
git diff --name-status HEAD                  # [R8]
git add -p                                   # [R4] accept some hunks, REJECT at least one (note whether b.txt is offered)
git stash push --keep-index -m "agent-rejected wtA rehearsal"   # [R5]

cd "$SCR/wtB"
git stash push -m "agent-rejected wtB rehearsal"                # [R5] (nothing staged: B has no accepted hunks)
git stash list                               # [R6] BOTH entries visible from B: the stash is shared
git diff "stash@{1}^2" "stash@{1}"           # [R6] rejected hunks of whichever entry is wtA's
```

Then integrate, tear down, and test the destructive-edge questions:

```bash
cd "$SCR/wtA"
git status -sb                               # [O2] if b.txt is not fully staged, run: git add -- b.txt
                                             #      otherwise the worktree cannot be removed cleanly below
git commit -m "AW-1 rehearsal commit"        # [I1]
cd "$SCR/main"
git merge --no-ff --no-commit feat/rehearse-AW-1-a      # [I2] (run: git status --porcelain first)
git commit -m "Merge feat/rehearse-AW-1-a (AW-1)"
git log --first-parent --merges -n 5 master  # [A1]

git worktree unlock "$SCR/wtA"               # [W3]
git worktree remove "$SCR/wtA"               # [W5] Q: does it refuse because of ignored target/ ? is target/ deleted?
git branch --merged master                   # [O3]
git branch -d feat/rehearse-AW-1-a           # [I3]

git branch -d feat/rehearse-AW-2-b           # [I3] Q: refused while wtB has it checked out? (its tip is already merged, so any refusal is about the worktree)
git stash list                               # [R6] re-read
git stash drop "stash@{0}"                   # [R7] name n explicitly, after re-reading the list
git worktree prune -n -v                     # [W6] dry run only
```

When finished, unlock and remove wtB the same way ([W3], [W5]) and delete the directory `/tmp/wt-rehearsal`.

**Scratch card for the one command not carded elsewhere:**

- **`git init -b master "$SCR/main"`**: 🟡 REVERSIBLE. Creates a new empty repository (a `.git` directory with `objects`, `refs/heads`, `refs/tags` and template files) at the given path; changes nothing else. *Why a human gate:* it creates a repository on disk, and run in the wrong directory it would nest a repo inside the real one, so the path is explicit and under `/tmp`. *Flags:* `-b <branch-name>` names the initial branch (otherwise the default is `master` today but "subject to change", or `init.defaultBranch`); `[<directory>]` is the target. *Undo:* delete the scratch directory. *Docs:* [git-init](https://git-scm.com/docs/git-init), [`-b` L74][init-b], [synopsis L16][init-syn].

### Questions the rehearsal must answer

The documentation does not state these; the cards mark them **(not in the docs)**. Tick each, then correct the card.

- [ ] `git worktree remove` (no `-f`) succeeds with an **ignored** `target/` present, and `target/` is deleted with the directory. ([W5])
- [ ] `git branch -d` on a branch still **checked out in a linked worktree** is refused (or not). ([I3])
- [ ] `git add -p` offers a file marked with `git add -N` as a hunk, and `git stash push --keep-index` accepts such an entry. If not, use the whole-file fallback in [R3].
- [ ] A stash made in worktree A is visible from B and from main, and `stash@{n}` indices shift after B stashes. (Documented; confirm for yourself.) ([R5])
- [ ] `git worktree add` creates missing parent directories of `<wt>`. ([W1])
- [ ] Which commands fire `reference-transaction` (branch create/delete, commit, merge, stash)? Only if you test the hook ([C5]); needs a hook script and the exec bit.
- [ ] Open the scratch worktree in VS Code and run its Git and Java tooling: with `extensions.worktreeConfig` on, do the IDE and Maven git plugins still work? **This is the gate for [C1] on the real repo.**

---

## Step 2: Layout and naming

- **Parent directory for linked worktrees:** `/home/echocdelta/pierre15Home22DEC/cnf/codenforce-wt/`. One subdirectory per item: `<itemID>-<slug>` (for example `AW-1-worktree-primer`). The parent is a sibling of `codenforce/` so it is outside the repo and cannot be swept up by the repo's own tooling. Create it yourself first (`mkdir`), because whether `worktree add` creates missing parents is undocumented.
- **Branch:** the standing grammar `<type>/<slug>-<itemID>-<kebab>`, for example `feat/letters-III-H-compression` ([branch conventions](/dev/reference/git/git-branch-commit-conventions)).
- **Agent ID** is the worktree directory's basename (`AW-1-worktree-primer`). It appears in the stash message, the trace2 log, and the per-worktree identity, so one name finds everything.
- **Cross-repo tasks:** `boroughforge-wikidocs` is a separate repository with its own worktrees and its own stash. Use `git -C <path> worktree add …` ([git `-C`][git-C]) in that repo; the same cards apply. Do not mix a codenforce worktree and a wikidocs worktree under one agent unless the task needs both.
- **Concurrency limit:** start with **three** concurrent writers. Your review time, not the machine, is the bottleneck: each live worktree is one more review queue, one more cold build, and (if you open a window per worktree) one more Java Language Server. This is a recommendation, not a documented limit; adjust after a week of use.

---

## Step 3: Write the scope card

One per worktree, written *before* dispatch and kept in the agent's prompt. A scope card is what [R8] checks the agent's diff against.

```text
Item:              <itemID> <one-line goal>
Agent ID:          <worktree basename>
Branch:            <type>/<slug>-<itemID>-<kebab>
Worktree:          /home/echocdelta/pierre15Home22DEC/cnf/codenforce-wt/<itemID>-<slug>
Authorization:     writes inside its worktree only; no git writes; no DB; no network
Owned paths:       <the files/packages this agent may edit>
Forbidden paths:   <hot files held by another worktree>, pom.xml, faces-config.xml,
                   docs/worklog.md, docs/subsystem-status.md, .git/**, .vscode/**
DB patch number:   dbpatch_beta<N>.sql reserved (agent writes text only; ECD runs it)
Merge order:       <position>, because <reason: conflicts, dependencies>
```

Pick the merge order by hot-file overlap: merge the worktree that touches the fewest hot files first, the one with the most last, so each later merge is the only one resolving the shared files.

---

## Step 4: Create the worktree

```bash
cd /home/echocdelta/pierre15Home22DEC/cnf/codenforce        # main checkout, clean, on master
git worktree add --lock --reason "agent <agentId> / <itemID>" \
    -b <branch> /home/echocdelta/pierre15Home22DEC/cnf/codenforce-wt/<itemID>-<slug> master
git worktree list -v
```

- **Card:** [W1] (risk 🟡, flags `--lock`, `--reason`, `-b`, explicit start point `master`; refuses an existing branch name; **never `-f`/`-B`**). Verify with [W2]: the entry shows `locked` with your reason.
- Why `master` is named explicitly: with `-b`, an omitted start point defaults to the *current* `HEAD`, which is whatever the shell happened to be in.

---

## Step 5: Wire the sandbox and the workspace

Do this once per worktree; the [sandbox checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist) has the checkable version.

1. Open the agent session with the **worktree as its working folder**. The sandbox grants read-write access to the current working directory automatically; extra paths go in `chat.agent.sandbox.fileSystem.userConfiguredPaths` (`readwritePaths`, `readonlyPaths`, `deniedPaths`; denied beats read-only beats read-write) ([sandbox docs][vsc-sandbox]). Do **not** add the main checkout to `readwritePaths`. The checklist has the exact values.
2. Add the worktree as a VS Code workspace folder, or open it in its own window, so tools can see it. The path must be both writable *and* mapped; neither alone is enough.
3. Confirm the **main checkout, the main `.git/`, and the other worktrees are not writable** by this agent (checklist: effective-policy check with `/sandbox policy`).
4. Set the agent terminal's environment: `AGENT_ID`, `WORKTREE_ID`, `GIT_TRACE2_EVENT`, `GIT_TRACE2_ENV_VARS` ([C4]). Trace2 reads its settings only from system and global config, so per-worktree separation has to come from the environment.
5. Optionally enable per-worktree identity ([C1], then [C2]) once the Step 1 IDE question is answered.

---

## Step 6: Baseline the worktree

Immediately before the agent's first edit, on a clean worktree:

```bash
cd <wt>
wt-base          # Appendix A: shows status, asks before git add -A
```

- **Card:** [R2] (`git add -A` stages everything and *blesses it as accepted*, so it only runs on a tree you have just looked at; undo with `git restore --staged .`).
- A freshly created worktree is clean, so the baseline is simply `HEAD`. Later turns in the same worktree start from a clean tree too, because Step 10 commits what you accepted.

---

## Step 7: Dispatch

Prompt template. Fill the placeholders from the scope card.

```text
You are agent <agentId> working on <itemID>: <goal>.

Working directory: <wt>   (a git worktree on branch <branch>).
You may write ONLY under <wt> and /tmp. Everything else is read-only or blocked.

Owned paths:     <…>
Forbidden paths: <…>   If the task needs one of these, STOP and report; do not edit it.

Git: read-only commands only (status, diff, log, show, branch listing).
     Never run add, commit, stash, checkout, merge, rebase, reset, or anything under .git/.
Database: never connect to or query any database. If you need SQL, write it as text into
     dbpatch_beta<N>.sql (reserved for this item) and do not run it.
Build: mvn -o clean package -DskipTests   (offline; never `install`; do not pipe the output).

When finished, reply with: (1) a summary, (2) the list of files you touched,
(3) the worklog lines and dashboard changes you would have made, as text, (4) open questions.
```

---

## Step 8: While agents run

- **Do not review, build, or edit inside a worktree while its agent is working** (a write in the middle of a review makes your decisions apply to stale hunks).
- Watch without disturbing: `git --no-optional-locks status --porcelain` run in a worktree, and `git worktree list -v` ([O2], [W2]). `--no-optional-locks` (or `GIT_OPTIONAL_LOCKS=0`) skips "optional sub-operations that require taking a lock", which is the documented purpose for background processes.
- Do not run `git gc` (deliberately not carded) while any agent is active. Concurrent stashes from other worktrees are safe for your review only because every entry is tagged and resolved by message ([R5], [R6]); never address a stash by a remembered `stash@{n}`.
- Check the agent debug log and the trace2 file for the worktree (see the checklist) for anything outside the scope card.

---

## Step 9: Review one worktree at a time

Order matters: **identity of the tree, then scope, then hunks, then build.**

1. **Is the agent finished?** If the harness may still be running in the background, wait until it is idle.
2. **Check the worktree's `.git` file and editor config before running git there.** From the main checkout:

   ```bash
   wt-verify                        # Appendix A: compares each <wt>/.git to the expected admin dir
   ```

   It must say `ok`. A linked worktree's `.git` file should read `gitdir: <main>/.git/worktrees/<id>`; anything else means git commands in that directory would act on a different repository ([W4], [O1]). Also open `<wt>/.vscode/` and look for `tasks.json`/`settings.json` that did not exist before: they can run commands when the folder is opened.
3. **Orient** inside the worktree: `git rev-parse --show-toplevel --git-dir --git-common-dir` should show this worktree's path and the shared `.git` ([O1]).
4. **New files:** `git ls-files --others --exclude-standard -z` ([R1]). Each one is reviewed whole: read it, then `git add -N -- <file>` ([R3]) to keep it in the hunk flow, or remove it ([R9], always `-n` first).
5. **Scope check:** `git diff --name-status HEAD` against the scope card ([R8]). Any forbidden path in the output is a finding before you read a single hunk.
6. **Hunks:** `git add -p` ([R4]). `y` keep, `n` reject, `s` split, `e` edit. Do not hold a key down. One-keystroke mode ([C3]) is faster and easier to misuse.
7. **Park the rejects:** `git stash push --keep-index -m "agent-rejected <worktree> <timestamp>"` ([R5]). The helper `wt-review` runs steps 4 to 7 with the prompts built in.
8. **Build exactly what you accepted.** After the stash, the working tree equals the accepted state, which is the documented "testing partial commits" pattern ([stash example][stash-example]). Run, unpiped, in that worktree:

   ```bash
   mvn -o clean package -DskipTests
   ```

   (`clean package`, never `install`; offline.)
9. **Look at what you rejected** with `wt-rejected-show` ([R6]) before dropping anything. Dropping is a separate, manual, named act ([R7]).

---

## Step 10: Integrate

```bash
# in the agent's worktree, after Step 9 left git diff empty:
git commit -m "<itemID> <subject>"                           # [I1] never --no-verify
```

```bash
# in the MAIN checkout, on master, clean tree, in the merge order from the scope card:
git status --porcelain
git merge --no-ff --no-commit <branch>                       # [I2]
git diff --cached --stat
git commit -m "Merge <branch> (<itemID>)"
mvn clean package -DskipTests                                # unpiped, per project rules
git log --first-parent -n 5                                  # one line per merged item
```

- **Why the main checkout:** `master` is checked out there and Git refuses to check one branch out in two worktrees ([W1], [I2]). Agent worktrees never check out `master`.
- **Why `--no-ff`:** each item stays a visible unit in history, as the branch conventions require.
- **Conflicts** in a hot file are expected on the second and later merges ([Step 2](#step-2-layout-and-naming) merge order). Resolve by hand. Abort with `git merge --abort` while conflicted ([I2]).
- **After each merge**, the other open worktrees are behind `master`. This primer does **not** use `git rebase` or `git reset` to catch them up (not carded). Resolve conflicts once, at merge time, in the main checkout. If a worktree must see another item's code *before* merge, that is a sign the two items are not independent: finish and merge one first.
- **Deploy:** ECD, one build at a time.
- **If you use VS Code's Agents window instead:** its **Merge Changes** action performs the commit and merge for you ([Delegate two tasks][vsc-delegate]). VS Code advises one integration branch as the base and merging each session separately; if you merge manually, use `git merge --no-ff <session-branch>` and do not also apply the same changes through another integration action. This primer's merge order and unpiped build ([I2]) still apply; the button does not run them.

---

## Step 11: Tear down

```bash
git worktree unlock <wt>                       # [W3]
git worktree remove <wt>                       # [W5] NO -f. If it refuses, stop and look.
git branch --merged master                     # [O3] confirm the branch is listed
git branch -d <branch>                         # [I3] NOT -D
git worktree prune -n -v                       # [W6] dry run
```

- If `worktree remove` refuses, something is untracked or modified in the worktree: that is the safety net working. Look with [R1] and [R8]. Do not reach for `-f`.
- Remove the worktree *before* deleting the branch ([I3]).
- Remove the worktree's path from the sandbox `allowWrite` list and from the workspace folders.
- Rotate or archive the worktree's trace2 file, then delete the stash entries tagged with this worktree's name once reviewed ([R7]).

---

## Step 12: Hygiene sweep (weekly, or whenever more than three worktrees exist)

```bash
wt-sweep           # Appendix A
```

It lists, read-only: every worktree with its lock reason and `prunable` state ([W2]); changed-file counts per worktree ([O2]); the whole shared stash ([R6]); merged branches ready for [I3]; and the prune dry run ([W6]). Anything locked for more than a week with no commits, any `agent-rejected` stash older than a week, and any worktree whose branch is already merged is a decision for ECD: finish it or tear it down.

📅 *Planned:* an automated stale-worktree report is part of the authorization-and-logging spec; until then `wt-sweep` is the manual version.

---

## Cheat sheet

| Moment | Command | Card |
|---|---|---|
| Create | `git worktree add --lock --reason "…" -b <branch> <wt> master` | [W1] |
| Inspect | `git worktree list -v` | [W2] |
| Baseline | `wt-base` (runs `git add -A` after you confirm) | [R2] |
| New files | `git ls-files --others --exclude-standard -z`, `git add -N -- <f>` | [R1], [R3] |
| Scope | `git diff --name-status HEAD` | [R8] |
| Review | `git add -p` | [R4] |
| Park rejects | `git stash push --keep-index -m "agent-rejected <wt> <ts>"` | [R5] |
| See rejects | `wt-rejected-show` | [R6] |
| Drop one | `git stash drop "stash@{<n>}"` after re-reading the list | [R7] |
| Commit | `git commit -m "<itemID> …"` | [I1] |
| Merge | `git merge --no-ff --no-commit <branch>` in main | [I2] |
| Tear down | `unlock`, `remove` (no `-f`), `branch -d` | [W3], [W5], [I3] |
| Audit | `git log --first-parent --merges`, `git reflog show HEAD` | [A1], [A2] |

---

## Troubleshooting

| Symptom | Likely cause | Look at |
|---|---|---|
| `worktree add` refuses because the branch is "already checked out" | the branch is live in another worktree; message text is not documented here | [W1]; do **not** use `-f` |
| `worktree remove` refuses | untracked files or modified tracked files inside the worktree | [R1], [R8], [R9]; do **not** use `-f` |
| `stash@{n}` shows the wrong entry | the stash is shared and another worktree stashed in between | [R5], [R6]; resolve by message with `wt-rejected-show` |
| `git branch -d` says "not fully merged" | the merge ([I2]) has not happened | [I3], [O3]; do **not** use `-D` |
| A hook never runs | no executable bit, or `core.hooksPath` points elsewhere | [C5] |
| Git or an IDE tool reports an unsupported extension after Step 5 | `extensions.worktreeConfig` and an older tool | [C1]; undo with `git config --unset extensions.worktreeConfig` |
| Offline build fails in a new worktree | dependency missing from `~/.m2`, not a Git problem | run once online in the main checkout, then `mvn -o` |
| Two agents' stashes look identical | the worktree name was left out of the `-m` message | [R5] |

---

## Appendix A: helper functions (UNTESTED)

> **Rehearse these in the scratch repo before they go in `~/.bashrc`.** They replace the single-tree `agent-base`, `agent-review`, `agent-rejected` from the [per-hunk review page](/dev/reference/git/agent-edit-review-git-add-patch) for use across worktrees. Each runs git only in the directory you are in, except `wt-verify` and `wt-sweep`, which read other worktrees from the main checkout. No function drops a stash, removes a worktree, or commits.

```bash
# Run from inside ONE worktree (or the main checkout for wt-verify / wt-sweep).

wt-name() { basename "$(git rev-parse --show-toplevel)"; }                    # [O1]

wt-base() {                                                                   # [R2]
  local out a
  out=$(git status --porcelain) || return
  if [ -z "$out" ]; then
    echo "clean: baseline = $(git branch --show-current) in $(wt-name)"       # [O3]
    return 0
  fi
  printf 'Uncommitted content in %s:\n%s\n' "$(wt-name)" "$out"
  read -r -p "Bless ALL of it as the accepted baseline (git add -A)? [y/N] " a
  [ "$a" = y ] || return 1
  git add -A && echo "baseline staged: $(git diff --cached --shortstat)"
}

wt-review() {                                                                 # [R1] [R3] [R8] [R4] [R5]
  local n untracked a
  n=$(wt-name)
  untracked=$(git ls-files --others --exclude-standard -z | tr '\0' '\n')
  if [ -n "$untracked" ]; then
    printf 'New files in %s (decide each as a whole file):\n%s\n' "$n" "$untracked"
    printf '  keep for review: git add -N -- <file>   then run wt-review again\n'
    printf '  remove:          git clean -n -d, then git clean -i -d\n'
    return 1
  fi
  git diff --name-status HEAD
  read -r -p "All paths inside the scope card? [y/N] " a
  [ "$a" = y ] || return 1
  git add -p
  if git diff --quiet; then
    echo "All pending hunks kept."
  else
    git stash push --keep-index -m "agent-rejected $n $(date +%F_%H%M%S)"
    echo "Rejected hunks parked for $n. View with: wt-rejected-show"
  fi
}

wt-rejected-show() {                                                          # [R6]
  local n ref
  n=$(wt-name)
  ref=$(git stash list --format='%gd %gs' | grep -F "agent-rejected $n " | head -n 1 | cut -d' ' -f1)
  [ -n "$ref" ] || { echo "no agent-rejected stash for $n" >&2; return 1; }
  echo "== $ref"
  git diff "$ref^2" "$ref"
}

wt-verify() {                                                                 # [O1] [W4]  run in MAIN
  local common top p got
  common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
  top=$(git rev-parse --show-toplevel)
  git worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r p; do
    [ "$p" = "$top" ] && continue
    got=$(head -n 1 "$p/.git" 2>/dev/null)
    case "$got" in
      "gitdir: $common/worktrees/"*) echo "ok       $p" ;;
      *)                             echo "SUSPECT  $p  (.git says: $got)" ;;
    esac
  done
}

wt-sweep() {                                                                  # [W2] [O2] [R6] [O3] [W6]  run in MAIN
  git worktree list -v
  echo; echo "== changed files per worktree"
  git worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r p; do
    printf '%5s  %s\n' "$(git --no-optional-locks -C "$p" status --porcelain | wc -l)" "$p"
  done
  echo; echo "== stash (shared by all worktrees)"; git stash list
  echo; echo "== branches merged into master (candidates for git branch -d)"; git branch --merged master
  echo; echo "== prune dry run"; git worktree prune -n -v
}
```

What each git call in these functions is, with its docs: `rev-parse --show-toplevel/--git-common-dir` ([O1]); `status --porcelain` ([O2]); `branch --show-current`, `--merged` ([O3]); `ls-files --others --exclude-standard -z` ([R1]); `diff --name-status`, `--cached` ([R8]); `diff --cached --shortstat` ([shortstat][dopt-shortstat]); `diff --quiet` exits 1 on differences and 0 on none ([`--quiet`/`--exit-code`][dopt-quiet]); `add -A` ([R2]); `add -p` ([R4]); `stash push --keep-index -m` ([R5]); `stash list --format='%gd %gs'` (`stash list` accepts log options, [stash `list`][stash-list]; `%gd` is the shortened reflog selector such as `stash@{0}` and `%gs` the reflog subject, [pretty-formats][pf-gd]); `diff "<stash>^2" "<stash>"` ([R6]); `worktree list [-v] [--porcelain]` ([W2], [porcelain format][wt-porcfmt]: the first attribute of each record is `worktree <path>`, main worktree listed first); `worktree prune -n -v` ([W6]); `-C <path>` runs git as if started in that path ([git `-C`][git-C]).

Known weak points to test in rehearsal: `grep -F` matching on the stash subject (the subject Git writes for `stash push -m` is not specified in the docs I pinned, so the trailing-space match on `agent-rejected <name> ` is an assumption); `wt-verify` assumes the main checkout's `git rev-parse --git-common-dir` resolves to the directory containing `worktrees/`.

---

[W1]: /dev/subsystems/agent-workflow/worktree-command-cards#w1-create-a-worktree-on-a-new-branch
[W2]: /dev/subsystems/agent-workflow/worktree-command-cards#w2-list-worktrees
[W3]: /dev/subsystems/agent-workflow/worktree-command-cards#w3-lock-and-unlock-a-worktree
[W4]: /dev/subsystems/agent-workflow/worktree-command-cards#w4-move-or-repair-a-worktree
[W5]: /dev/subsystems/agent-workflow/worktree-command-cards#w5-remove-a-finished-worktree
[W6]: /dev/subsystems/agent-workflow/worktree-command-cards#w6-prune-stale-admin-entries
[O1]: /dev/subsystems/agent-workflow/worktree-command-cards#o1-where-am-i-which-repo-does-this-directory-belong-to
[O2]: /dev/subsystems/agent-workflow/worktree-command-cards#o2-git-status-and-optional-locks
[O3]: /dev/subsystems/agent-workflow/worktree-command-cards#o3-which-branches-exist-which-are-merged-where-are-they-checked-out
[R1]: /dev/subsystems/agent-workflow/worktree-command-cards#r1-what-did-the-agent-create-that-git-diff-cannot-show
[R2]: /dev/subsystems/agent-workflow/worktree-command-cards#r2-baseline-stage-the-pre-agent-state
[R3]: /dev/subsystems/agent-workflow/worktree-command-cards#r3-make-new-files-visible-to-review
[R4]: /dev/subsystems/agent-workflow/worktree-command-cards#r4-accept-or-reject-changes-hunk-by-hunk
[R5]: /dev/subsystems/agent-workflow/worktree-command-cards#r5-park-the-rejected-hunks-worktree-tagged-stash
[R6]: /dev/subsystems/agent-workflow/worktree-command-cards#r6-inspect-rejected-hunks
[R7]: /dev/subsystems/agent-workflow/worktree-command-cards#r7-discard-a-reviewed-reject
[R8]: /dev/subsystems/agent-workflow/worktree-command-cards#r8-scope-check-did-the-agent-stay-inside-its-fence
[R9]: /dev/subsystems/agent-workflow/worktree-command-cards#r9-remove-leftover-untracked-files
[I1]: /dev/subsystems/agent-workflow/worktree-command-cards#i1-commit-the-accepted-hunks-in-the-agents-worktree
[I2]: /dev/subsystems/agent-workflow/worktree-command-cards#i2-merge-the-branch-into-master-preserving-the-branch
[I3]: /dev/subsystems/agent-workflow/worktree-command-cards#i3-delete-the-merged-branch
[C1]: /dev/subsystems/agent-workflow/worktree-command-cards#c1-enable-per-worktree-config
[C2]: /dev/subsystems/agent-workflow/worktree-command-cards#c2-per-worktree-identity
[C3]: /dev/subsystems/agent-workflow/worktree-command-cards#c3-one-keystroke-hunk-review
[C4]: /dev/subsystems/agent-workflow/worktree-command-cards#c4-per-worktree-git-activity-log-trace2
[C5]: /dev/subsystems/agent-workflow/worktree-command-cards#c5-hooks-for-all-worktrees-and-who-may-write-them
[C6]: /dev/subsystems/agent-workflow/worktree-command-cards#c6-keep-the-worklog-mergeable-across-worktrees-decision-needed
[A1]: /dev/subsystems/agent-workflow/worktree-command-cards#a1-what-was-merged-per-item
[A2]: /dev/subsystems/agent-workflow/worktree-command-cards#a2-every-ref-move-with-time-and-identity

[wt-list]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L109
[wt-refs]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L279
[wt-bugs]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L513
[wt-porcfmt]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L440
[layout-logs]: https://github.com/git/git/blob/v2.43.0/Documentation/gitrepository-layout.txt#L240
[stash-list]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L73
[stash-example]: https://github.com/git/git/blob/v2.43.0/Documentation/git-stash.txt#L339
[status-porc]: https://github.com/git/git/blob/v2.43.0/Documentation/git-status.txt#L38
[config-get]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L90
[git-version]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L42
[git-C]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L61
[init-b]: https://github.com/git/git/blob/v2.43.0/Documentation/git-init.txt#L74
[init-syn]: https://github.com/git/git/blob/v2.43.0/Documentation/git-init.txt#L16
[dopt-shortstat]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L248
[dopt-quiet]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L815
[pf-gd]: https://github.com/git/git/blob/v2.43.0/Documentation/pretty-formats.txt#L293
[vsc-isolation]: https://code.visualstudio.com/docs/agents/run/agents-window#_choose-where-an-agent-makes-changes
[vsc-delegate]: https://code.visualstudio.com/docs/agents/guides/delegate-two-tasks
[vsc-sandbox]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing
[vsc-approvals]: https://code.visualstudio.com/docs/agents/run/approvals
