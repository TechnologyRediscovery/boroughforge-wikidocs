---
title: Agent Simulation Segment Command Cards
description: One card per command a human runs to provision, observe, review and purge a local agent simulation segment under /tmp (S cards), to test its network fidelity with open-source tools (N cards), and to rehearse signing with throwaway keys (K cards), each with risk profile, flags, undo and pinned official-doc links.
published: false
date: 2026-10-30T00:00:00.000Z
tags: subsystem:agent-workflow, audience:dev, type:reference, status:draft
editor: markdown
dateCreated: 2026-10-30T00:00:00.000Z
---

# Agent Simulation Segment Command Cards

> **Status: DRAFT, UNTESTED.** Every card below was written from official documentation. **No command on this page has been executed** by the agent that drafted it (agents have no git-write access, no database access and no shell access outside `/tmp` and the mapped workspace folders, by policy). The simulation segment does not exist yet, and the standing hard boundaries are **not** amended. Nothing here changes them. Rehearse in phase 8b of the proposal before trusting any card.

These cards back the proposal `AW.8` (`docs/subsystems/agent-workflow/agent-sim-segment-proposal.md` in the codenforce repo; editor-only, not published). The proposal says *what* the segment is and *why*; a card says *what one command really does* and *what it can break*. They follow the format of the [worktree command cards](/dev/subsystems/agent-workflow/worktree-command-cards), with one added field, **Where it runs**.

Three groups:

- **S: the segment.** Create a run directory, seed it from a bundle, clone, neutralize, stamp the environment, replay, review, purge.
- **N: network fidelity.** Observe whether a sandboxed process can reach anything, with `dumpcap`, `tshark`, `curl`, `strace`, `ss`, `nsenter`.
- **K: signing rehearsal.** Throwaway-key `ssh-keygen -Y` ceremonies for the long-range goal (a signed, portable borough database). Rehearsal only; real keys never appear here.

## How to read a card

**Who runs it.** Cards in **S** and **N** are **ECD only**. Cards in **K** are what an agent may run inside a run of class `SIM-K`, in `$RUN/keys` only; ECD runs the same commands to learn the ritual. The real key ceremony (the proposal `PTC.0`) is human-only, with an admin present.

**Where it runs.** Each card says one of three places, because the answer changes what the command proves:

- **Plain terminal:** a normal terminal ECD opens himself. **Not sandboxed.**
- **Agent terminal in the sim window:** a command the agent's terminal tool executes inside the sandbox. The only place a probe tells you anything about the sandbox. ECD pastes an exact command and says only "run exactly this and report the output".
- **Either:** the card says what each tells you.

**Risk legend** (same as the [worktree cards](/dev/subsystems/agent-workflow/worktree-command-cards)):

- 🔵 **READ:** inspects state; writes nothing durable.
- 🟡 **REVERSIBLE:** creates or changes something an inverse command removes.
- 🔴 **DESTRUCTIVE:** removes data or widens privilege in a way that needs a deliberate undo.

**Fields.** Command, **Risk**, **Where it runs**, **Why a human gate**, **Touches**, **Flags**, **Watch out**, **Undo**, **Verify**, **Docs**. A statement that is *not* in the cited docs is marked **(not in the docs: verify in rehearsal)**.

**Doc pinning.** Git is **2.43.0**, so every Git cite links the AsciiDoc source **at tag `v2.43.0`** with a line number (a tag link never moves). Linux man pages link man7.org (they track current releases; your host's `man` is the authority for your versions). `ssh-keygen` links the OpenBSD page, which tracks the newest OpenSSH; **read your local `man ssh-keygen` too**.

**Placeholders and variables** (set once per terminal; each card assumes them):

- `<real-repo>`: the real CodeNForce repository (read by S2 only).
- `<run-id>`: for example `20261101-0930-cb1-transfer-rebase`.
- `RUN=/tmp/cnf-sim/<run-id>`: the run directory. `REPLAY=/tmp/cnf-sim/<run-id>.replay`: ECD's own replay clone (S6).
- `EVID`: ECD's evidence directory, **outside `/tmp`**, mode `0700`, chosen once.
- `<templates-dir>`: ECD's own folder (not under `/tmp`) holding the reviewed `sim-env.sh`.

## Two rules for every card (read these first)

**Rule 1. After the agent has run in a clone, ECD never runs git in it, and never executes anything from inside `$RUN`.** The agent can write the clone's `.git/config`, its hooks and every file in `$RUN`, and several Git config keys start programs: `core.hooksPath` ([L499][cfg-hooks]) redirects hooks; `core.pager` "is meant to be interpreted by the shell" ([L543][cfg-pager]); `core.editor` ([L516][cfg-editor]) and `core.sshCommand` ([L266][cfg-ssh]) name commands; `core.fsmonitor` ([L64][cfg-fsmon]) can enable a monitor. **(not in the docs: exactly which commands trigger each; assume any.)** Running `git log` there from an unsandboxed terminal could therefore run the agent's program with ECD's rights. Instead: **read files as text** (S7) and **replay in a second clone ECD creates himself** (S6). Running git in the clone is fine **before** the run starts (S3 to S5). Likewise, `sim-env.sh` is sourced with `.`, which *executes* it, so it lives **outside** `$RUN` (S5).

**Rule 2. Everything the agent wrote is untrusted text.** Read it with `cat -v` (shows control characters instead of acting on terminal escape sequences, [cat -v][man-cat]); check for symbolic links before copying anything out (S7); never paste a runbook line into a terminal you have not read.

---

## Group S: the segment

### S1. Create the segment root and one run directory

```bash
mkdir -m 0700 /tmp/cnf-sim                 # no -p: fails if the name already exists
RUN=/tmp/cnf-sim/<run-id>
mkdir -m 0700 "$RUN"
mkdir -m 0700 "$RUN/home" "$RUN/hooks" "$RUN/logs" "$RUN/out"
stat -c '%a %U %n' /tmp/cnf-sim "$RUN"
systemd-tmpfiles --cat-config | grep -n -E ' /tmp( |$)'
```

- **Risk:** 🟡 REVERSIBLE. Creates empty directories under `/tmp`.
- **Where it runs:** plain terminal.
- **Why a human gate:** this creates the one place agents would be liberal. The root's owner and mode decide who else on the host can read or tamper with any run, so a human sets them and looks at the result. (Agents may already write under `/tmp`; the segment adds guarantees on top, and they start here.)
- **Touches:** only `/tmp/cnf-sim/` and below.
- **Flags:**
    - `-m 0700`: "set file mode (as in chmod), not a=rwx - umask", so the mode does not depend on your umask ([mkdir(1)][man-mkdir]).
    - **No `-p`**, on purpose: `-p` means "no error if existing", which would silently adopt a directory someone else created first. Without it `mkdir` fails and you look.
    - `stat -c '%a %U %n'`: `%a` octal permission bits, `%U` owner name, `%n` file name ([stat(1)][man-stat]).
    - `systemd-tmpfiles --cat-config`: "Copy the contents of config files to standard output" ([systemd-tmpfiles(8)][man-tmpfiles8]). In the `/tmp` line, the **Age** column (the sixth: `Type Path Mode User Group Age Argument`, [tmpfiles.d(5)][man-tmpfiles5]) is how long `/tmp` keeps files. That value is distro configuration, so read it, do not assume it.
- **Watch out:**
    - The sticky bit on `/tmp` means "a file in that directory can be renamed or deleted only by the owner of the file, by the owner of the directory, and by a privileged process" ([inode(7)][man-inode]). That protects against other *users*, not against other *processes of yours*.
    - If `/tmp` is memory-backed on this host, a runaway clone fills RAM. **(not in the docs: check what backs `/tmp` with `df -h /tmp`, and watch run size with `du`, S7.)**
    - If `mkdir /tmp/cnf-sim` fails because it exists, **stop**. Look with `ls -ld` and `stat`. Do not "fix" it.
- **Undo:** `rmdir` each empty directory, deepest first.
- **Verify:** `stat` prints `700 <your-user> ...` for both paths; the `/tmp` line of the tmpfiles output exists; note its age.
- **Docs:** [mkdir(1)][man-mkdir] · [stat(1)][man-stat] · [systemd-tmpfiles(8)][man-tmpfiles8] · [tmpfiles.d(5)][man-tmpfiles5] · [inode(7)][man-inode]

### S2. Make the seed bundle from the real repository

```bash
git -C <real-repo> rev-parse --verify master                 # record this id in manifest.json
git -C <real-repo> bundle create "$RUN/seed.bundle" master
git -C <real-repo> bundle verify "$RUN/seed.bundle"
git -C <real-repo> bundle list-heads "$RUN/seed.bundle"
sha256sum "$RUN/seed.bundle"                                 # record this hash too
```

- **Risk:** 🟡 REVERSIBLE. Reads the real repository; writes one new file under `/tmp`.
- **Where it runs:** plain terminal.
- **Why a human gate:** it is the only moment real repository content enters the segment. What goes into the bundle is a decision about what an agent may read for the whole run. Reading the real repo is outside the agent's allowed area by design.
- **Touches:** reads the real repo's refs and objects; writes `$RUN/seed.bundle`. The cited docs describe the output as the bundle file and say nothing about writing into the repository. **(not in the docs: that no repository file is modified; compare `ls -l` timestamps of `<real-repo>/.git` if you care.)**
- **Flags:**
    - `-C <path>`: "Run as if git was started in `<path>`" ([git L61][g-C]).
    - `bundle create <file> <git-rev-list-args>`: the arguments must contain a **named ref** ([create L65][bundle-create]). `master` makes a **self-contained** bundle: "A self-contained bundle without any prerequisites can be extracted into anywhere, even into an empty repository, or be cloned from" ([L198][bundle-self]).
    - **Why not `HEAD` or a bare commit id:** a revision that does not resolve to a reference is refused: "fatal: Refusing to create empty bundle" ([L168][bundle-empty]).
    - **Not used:** `--all` includes refs such as `refs/remotes/*` ([L206][bundle-all]); that would carry far more history into the segment than `master`.
    - `bundle verify <file>`: checks the file "is valid and will apply cleanly to the current repository", exit code zero on success ([L71][bundle-verify]). Run it **inside a repository** (hence `-C`); whether it works outside one is **(not in the docs: verify)**.
    - `bundle list-heads <file>`: "Lists the references defined in the bundle" ([L83][bundle-heads]).
    - `rev-parse --verify`: strict resolution of one object name ([git-rev-parse L98][rp-verify]).
    - `sha256sum`: prints a SHA-256 digest ([sha256sum(1)][man-sha256]).
- **Watch out:**
    - The bundle carries **every committed byte reachable from `master`**. It excludes untracked and ignored files (so `.env`, local config and build output stay out), but anything ever committed is inside, including a secret committed years ago and later deleted. Decide that (proposal Q-SIM-6) **before** the first run.
    - A stale seed makes the simulation lie about conflicts: always bundle current `master` and record the id.
    - Check the size (`ls -lh "$RUN/seed.bundle"`) against the run's disk cap.
- **Undo:** `rm "$RUN/seed.bundle"`.
- **Verify:** `list-heads` shows exactly `refs/heads/master` at the id `rev-parse --verify` printed; `bundle verify` exits 0.
- **Docs:** [git-bundle](https://git-scm.com/docs/git-bundle) · [`create` L65][bundle-create], [`verify` L71][bundle-verify], [`list-heads` L83][bundle-heads] · [git-rev-parse](https://git-scm.com/docs/git-rev-parse)

### S3. Clone the seed into the run directory

```bash
env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git clone -b master "$RUN/seed.bundle" "$RUN/repo"
git -C "$RUN/repo" rev-parse HEAD 'HEAD^{tree}'
git -C <real-repo> rev-parse master 'master^{tree}'
ls -1 "$RUN/repo/.git/hooks"
```

- **Risk:** 🟡 REVERSIBLE. Creates `repo/`; changes nothing else.
- **Where it runs:** plain terminal. Running git in the clone is fine here and in S4, because the agent has not touched it yet (Rule 1).
- **Why a human gate:** a clone runs with *your* Git configuration, which may inject hooks or templates into the new repository. The human controls that environment once, at creation.
- **Touches:** `$RUN/repo/` (a new `.git` and a checked-out tree). Nothing in the real repository: the source is a single bundle file, not the repository's object directory. **(not in the docs I read: that no object is shared or hard-linked; `--local`, `--no-hardlinks` and `--shared` apply to clones from a repository path, see [git-clone](https://git-scm.com/docs/git-clone).)**
- **Flags:**
    - `-b <name>`: "point to `<name>` branch instead", the branch that gets checked out ([clone L209][clone-b]). The docs' own bundle example uses `git clone -b master` ([bundle L241](https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L241)), because a bundle may carry no `HEAD`.
    - `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_SYSTEM=/dev/null`: set to `/dev/null` they skip the global and system config files ([git L708][g-cfg]). This avoids `init.templateDir` ("the directory from which templates will be copied", [config init L1][cfg-init-tmpl]) copying your own hooks into the clone.
    - `'HEAD^{tree}'`: "the tree object of the commit" syntax `<rev>^{<type>}` ([gitrevisions L170][revs-type]). Quoted so the shell leaves `^` and braces alone.
- **Watch out:**
    - The default template still installs `*.sample` hook files; they are inert. **Any hook file without `.sample` is a finding.** **(not in the docs: whether your distro's default template differs; verify.)**
    - The clone's `origin` remote points at `seed.bundle`; S4 removes it.
- **Undo:** `rm -r "$RUN/repo"` (S8 rules apply).
- **Verify:** the two `rev-parse` outputs are **identical** (same commit id, same tree id as the real `master`); `ls` shows only `*.sample` files.
- **Docs:** [git-clone](https://git-scm.com/docs/git-clone) · [`-b` L209][clone-b] · [git (env vars)](https://git-scm.com/docs/git#_environment_variables) · [config/init][cfg-init-tmpl]

### S4. Neutralize the clone (before the run starts)

```bash
git -C "$RUN/repo" remote remove origin
git -C "$RUN/repo" config --local protocol.allow never
git -C "$RUN/repo" config --local core.hooksPath "$RUN/hooks"
git -C "$RUN/repo" config --local --list --show-origin
```

- **Risk:** 🟡 REVERSIBLE. Edits only `$RUN/repo/.git/config`.
- **Where it runs:** plain terminal. **Last time ECD runs git in this clone** (Rule 1).
- **Why a human gate:** this decides the clone's transport and hook policy. It must be set by a person before the agent can alter it.
- **Touches:** the clone's local config and its remote-tracking refs. Nothing outside `$RUN/repo/.git`.
- **Flags:**
    - `remote remove <name>`: "All remote-tracking branches and configuration settings for the remote are removed" ([git-remote L94][remote-rm]).
    - `protocol.allow never`: the default policy for every transport; "file" is "any local file-based path" ([config protocol L1][cfg-proto], [per-protocol L23][cfg-proto-name]). So a simulated `git fetch ../anything` is refused. **(not in the docs: whether `bundle` paths follow `file`; irrelevant here, the remote is gone.)**
    - `core.hooksPath <dir>`: look for hooks in `<dir>` instead of `$GIT_DIR/hooks` ([config core L499][cfg-hooks]). Hook *contents* are not carded here: ECD writes them, and the mechanics (executable bit, which hooks) are in [worktree card C5](/dev/subsystems/agent-workflow/worktree-command-cards#c5-hooks-for-all-worktrees-and-who-may-write-them).
    - `config --local --list --show-origin`: read only the repository file; show which file each value came from ([--local L134][gc-local], [--list L182][gc-list], [--show-origin L242][gc-origin]).
- **Watch out:**
    - **The agent can undo all of this** by editing its own `.git/config` (`git config protocol.allow always`). The design accepts that, because the clone is disposable and the **sandbox, not git config, is the boundary**. If the sandbox network is off, an `always` fetch fails at the sandbox. That is exactly what probes N5 and N6 measure.
    - A hook written into `$RUN/hooks` by ECD can be overwritten by the agent (it is in the writable run directory). Treat hook logs as *evidence of accidents*, not proof.
- **Undo:** `git -C "$RUN/repo" config --local --unset core.hooksPath` (and the same for `protocol.allow`); a removed remote can be re-added but there is no reason to.
- **Verify:** the `--list` output shows `protocol.allow=never`, the `core.hooksPath` value, and **no** `remote.origin.*` or `branch.master.remote` lines.
- **Docs:** [git-remote](https://git-scm.com/docs/git-remote) · [`remove` L94][remote-rm] · [git-config](https://git-scm.com/docs/git-config) · [config/protocol][cfg-proto] · [config/core][cfg-hooks]

### S5. Environment for every sim terminal (and for the replay)

File contents, kept **outside `/tmp`** at `<templates-dir>/sim-env.sh` (ECD writes it with his editor):

```bash
# usage:  SIM_ROOT=<dir> SIM_RUN_ID=<id>  .  <templates-dir>/sim-env.sh
: "${SIM_ROOT:?set SIM_ROOT first}"
: "${SIM_RUN_ID:?set SIM_RUN_ID first}"

export AGENT_ZONE=sim AGENT_RUN="$SIM_RUN_ID" AGENT_LEVEL=SIM

# git: no inherited config, no transport, no prompts, no pager, no editor
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_ALLOW_PROTOCOL=
export GIT_TERMINAL_PROMPT=false GIT_ASKPASS=/bin/false
export GIT_PAGER=cat GIT_EDITOR=true
export GIT_CEILING_DIRECTORIES="$SIM_ROOT"

# logging (env vars only: trace2 ignores repo-local config)
export GIT_TRACE2_EVENT="$SIM_ROOT/logs/trace2.jsonl"
export GIT_TRACE2_ENV_VARS=AGENT_ZONE,AGENT_RUN,AGENT_LEVEL

# determinism, so a replay can reproduce commit ids (fidelity F1)
export GIT_AUTHOR_NAME="Sim Agent"    GIT_AUTHOR_EMAIL="sim@invalid"
export GIT_COMMITTER_NAME="Sim Agent" GIT_COMMITTER_EMAIL="sim@invalid"
export GIT_AUTHOR_DATE="1793525400 +0000" GIT_COMMITTER_DATE="1793525400 +0000"
```

Check it (in a subshell, so your terminal stays clean):

```bash
( SIM_ROOT="$RUN" SIM_RUN_ID=<run-id>; . <templates-dir>/sim-env.sh; env | grep -E '^(AGENT_|GIT_)' )
```

- **Risk:** 🟡 REVERSIBLE. A text file and variables that exist only in shells that source it.
- **Where it runs:** the file is sourced by ECD in a subshell (S6 replay), and **must reach the agent terminal** in the sim window; that path is the first open item (below).
- **Why a human gate:** a sourced file is code executed with your rights. Only a human writes it, and it never lives where the agent can write.
- **Touches:** the environment of processes started afterwards. No files except the trace2 log named in `GIT_TRACE2_EVENT`.
- **Flags** (each is a documented environment variable of `git`):
    - `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM` = `/dev/null`: skip those files ([L708][g-cfg]); `GIT_CONFIG_NOSYSTEM` is the older switch for the system file ([L718][g-nosys]).
    - `GIT_ALLOW_PROTOCOL=` (empty): the documented rule is "behave as if `protocol.allow` is set to `never`, and each of the listed protocols … `always`" ([L924][g-proto]). Whether an **empty string counts as an empty list** is **(not in the docs: verify, VF-S4)**.
    - `GIT_TERMINAL_PROMPT=false` ([L704][g-prompt]); `GIT_ASKPASS=/bin/false`, a program that fails ([L697][g-ask]); confirm that path with `command -v false`.
    - `GIT_PAGER=cat` ("If it is set to an empty string or to the value "cat", Git will not launch a pager", [L642][g-pager]); `GIT_EDITOR=true` so no editor ever opens ([L652][g-editor]). The agent must use `git commit -m`; `rebase -i` uses `GIT_SEQUENCE_EDITOR` ([L658][g-seq]).
    - `GIT_CEILING_DIRECTORIES`: directories Git must not climb into while looking for a repository ([L518][g-ceil]).
    - `GIT_TRACE2_EVENT=<absolute path>` and `GIT_TRACE2_ENV_VARS`: the per-run activity log, stamped with agent identity ([L852][g-t2]; why environment variables rather than config: [worktree card C4](/dev/subsystems/agent-workflow/worktree-command-cards#c4-per-worktree-git-activity-log-trace2)).
    - Identity and dates ([name L561][g-aname], [email L566][g-aemail], [author date L571][g-adate], [committer date L585][g-cdate]). `1793525400 +0000` is 2026-11-01 09:30:00 UTC in "Git internal format: `<unix-timestamp> <time-zone-offset>`" ([date formats L7][g-datefmt]), the least ambiguous accepted form.
- **Watch out:**
    - **How these variables reach the agent's terminal is not established.** Candidate routes, none verified: (1) launch VS Code from a shell that exported them: `( SIM_ROOT="$RUN" SIM_RUN_ID=<run-id>; . <templates-dir>/sim-env.sh; code "$RUN" --profile "cnf-sim" )` ([profiles, command line][vsc-profile-cli]), but the [checklist LG-1](/dev/subsystems/agent-workflow/agent-sandbox-checklist) pitfall applies: `code` does not reach an *already running* instance; (2) a terminal-environment setting in the profile **(not in the docs I read: verify that one exists and applies to agent terminals)**; (3) neither, and rely on the sandbox plus the clone config of S4 plus the [checklist LG-2/LG-3](/dev/subsystems/agent-workflow/agent-sandbox-checklist). Test with `echo "$AGENT_RUN"` in an agent terminal.
    - **Do not export `HOME` into the VS Code process.** `HOME` for the *terminal* should be `$RUN/home`, but changing it for the editor itself would likely move VS Code's own user data (so the `cnf-sim` profile would not be found). **(not in the docs: verify.)** The block above therefore omits `HOME`; S6 sets it only in the replay subshell.
    - A pinned date makes every commit carry the same timestamp. The agent can override it per command; a **changed** date in the trace2 log is itself a review finding.
    - `GIT_EDITOR=true` makes `git commit` without `-m` abort ("empty commit message").
- **Undo:** close the shell; delete the file.
- **Verify:** the subshell prints the variables above; in an agent terminal `echo "$AGENT_RUN $AGENT_LEVEL"` prints `<run-id> SIM` (if empty, route (3)).
- **Docs:** [git (environment variables)](https://git-scm.com/docs/git#_environment_variables) · [git date formats](https://git-scm.com/docs/git-commit#_date_formats) · [api-trace2](https://git-scm.com/docs/api-trace2) · [bash parameter expansion, `${parameter:?word}`][bash-param]

### S6. Fidelity replay in a second clone (what "the sim worked" proves)

```bash
mkdir -m 0700 "$REPLAY" "$REPLAY/home" "$REPLAY/logs"
env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git clone -b master "$RUN/seed.bundle" "$REPLAY/repo"
cat -v "$RUN/out/candidate-runbook.md"          # READ every line first
( SIM_ROOT="$REPLAY" SIM_RUN_ID=<run-id>-replay
  . <templates-dir>/sim-env.sh
  export HOME="$REPLAY/home"
  cd "$REPLAY/repo" && exec bash --noprofile --norc -i )
#   ... inside that shell: type the runbook's commands by hand, one at a time, then `exit`
git -C "$REPLAY/repo" rev-parse HEAD 'HEAD^{tree}' > "$REPLAY/replay-state.txt"
diff -u "$RUN/out/expected-state.txt" "$REPLAY/replay-state.txt"
```

- **Risk:** 🟡 REVERSIBLE inside `$REPLAY`. **The runbook is agent-written text.** Reading it first is the control.
- **Where it runs:** plain terminal, in a replay root **ECD created**, never in the agent's `$RUN/repo` (Rule 1).
- **Why a human gate:** this is the only step where agent-authored commands touch anything ECD owns, and it exists to decide whether they may later be run for real. The human runs each line.
- **Touches:** `$REPLAY` only. Nothing in `$RUN` except reads.
- **Flags:**
    - `bash --noprofile --norc -i`: an interactive shell that skips the login and startup files ([bash, Invoking Bash][bash-invoke]), so your own aliases and environment do not leak into the replay.
    - `( ... )` subshell: variables set inside do not survive; `exec` replaces the subshell with the interactive shell.
    - `diff -u A B`: unified difference, exit status 0 when identical ([diff(1)][man-diff]).
    - Tree ids: equal tree ids mean equal contents and modes (fidelity **F0**); with the pinned identity and dates also equal commit ids (**F1**). The ladder and its limits are in the proposal §AW.8.7.
- **Watch out:**
    - **A green replay proves content, not environment.** Your real repo has hooks, a stash, linked worktrees and a different Git configuration that the clone does not. List them in the runbook's known gaps.
    - A runbook line that is not a `git` command (a download, a pipe into a shell, a path outside `$REPLAY`) is a **finding**, not a step to execute.
    - A mismatch is the whole value of the exercise: found with no risk.
    - Only on a match, and only by hand, run the same commands against the real repository (that part is a human git operation, outside these cards).
- **Undo:** S8 on `$REPLAY` (same rules).
- **Verify:** `diff` prints nothing and exits 0.
- **Docs:** [bash][bash-invoke] · [diff(1)][man-diff] · [gitrevisions `^{<type>}` L170][revs-type] · [git-clone](https://git-scm.com/docs/git-clone)

### S7. Review: read the run's artifacts as text, then copy out

```bash
cat -v "$RUN/out/candidate-runbook.md"
cat -v "$RUN/logs/trace2.jsonl"
cat -v "$RUN/repo/.git/logs/HEAD"                     # the reflog is a plain text file
du -s -h -x "$RUN"
find "$RUN" -type l                                   # must print nothing
ls -lR "$RUN/out" "$RUN/logs"
mkdir -m 0700 "$EVID/<run-id>"
cp -r "$RUN/out" "$RUN/logs" "$EVID/<run-id>/"
```

- **Risk:** 🔵 READ for the viewing lines; 🟡 REVERSIBLE for the copy (new files in `$EVID`).
- **Where it runs:** plain terminal. **No git command touches `$RUN/repo`** (Rule 1): the reflog is read as a file.
- **Why a human gate:** it moves agent-written bytes into ECD's own area. The symlink check and the reading step are what make that safe.
- **Touches:** reads `$RUN`; writes `$EVID/<run-id>/`.
- **Flags:**
    - `cat -v`: "use ^ and M- notation, except for LFD and TAB" ([cat(1)][man-cat]); control characters are shown, not interpreted.
    - `du -s -h -x`: `-s` one total, `-h` human-readable, `-x` stay on one file system ([du(1)][man-du]); compare to the manifest's disk cap.
    - `find "$RUN" -type l`: lists symbolic links ([find(1)][man-find]). **A link in `out/` or `logs/` could point at one of your private files**; a later `cat` of the copy would follow it. Anything printed here: stop and look.
    - `cp -r`: copy directories recursively ([cp(1)][man-cp]); without `-L` or `-H` links are copied as links, not followed. **(not in the cited man page text I read: confirm with `man cp` locally.)**
    - Reflog location: `logs/HEAD` is a per-repository file inside `.git` ([gitrepository-layout `logs` L240][layout-logs]). Its line format is **(not in the cited docs: read it as text and compare against the trace2 log).**
- **Watch out:**
    - The trace2 log and the reflog are in the agent-writable area, so both can be edited. They catch **accidents**. The independent record is ECD's capture (group N) and the VS Code transcript.
    - Compare what the agent *said* it ran with what the logs recorded. An extra command, a pinned-date change, or a path outside `$RUN` is a finding.
    - `$EVID` must be outside `/tmp`: `/tmp` is volatile ([S1](#s1-create-the-segment-root-and-one-run-directory)).
- **Undo:** `rm -r "$EVID/<run-id>"`.
- **Verify:** `find -type l` printed nothing; `ls "$EVID/<run-id>"` shows `out` and `logs`.
- **Docs:** [cat(1)][man-cat] · [du(1)][man-du] · [find(1)][man-find] · [cp(1)][man-cp] · [gitrepository-layout](https://git-scm.com/docs/gitrepository-layout)

### S8. Purge the run

```bash
ls -ld "$RUN"
du -s -h -x "$RUN"
rm -rI --one-file-system -- "${RUN:?}"
```

- **Risk:** 🔴 DESTRUCTIVE. Deletes a directory tree with no recovery.
- **Where it runs:** plain terminal, **after S7** (the copy-out) and after the verdict is recorded.
- **Why a human gate:** deletion with a variable in the path is the classic way to delete the wrong tree. A human confirms what `$RUN` is before one irreversible command.
- **Touches:** `$RUN` and everything below it. Nothing else.
- **Flags:**
    - `-r` recursive; `-I` "prompt once before removing more than three files, or when removing recursively" ([rm(1)][man-rm]); the prompt is your last look.
    - `--one-file-system`: "skip any directory that is on a file system different from that of the corresponding command line argument" ([rm(1)][man-rm]).
    - `--` ends option parsing. `--preserve-root` ("do not remove '/'") is documented as the **default** ([rm(1)][man-rm]).
    - `${RUN:?}`: "If parameter is null or unset, the shell writes the expansion of word … to the standard error"; a non-interactive shell exits, an **interactive shell does not exit but does not execute the command** ([bash][bash-param]). So an unset `RUN` cannot become `rm -r ""` or, worse, a shorter path.
    - There is no dry-run flag in the cited page, so the dry run is **looking**: `ls -ld`, `du`, the prompt.
- **Watch out:**
    - Git's object files are read-only by design, and `rm` may ask about write-protected files. **(not in the cited page: verify the exact prompts in rehearsal.)** Do not respond by adding `-f` until you have read the path again.
    - `$RUN` must be the run you mean: a stale value from an earlier run in the same terminal passes the `:?` test. Read the `ls -ld` line.
    - Purge `$REPLAY` the same way, as a separate command.
- **Undo:** none. That is why S7 copies out first.
- **Verify:** `ls -ld "$RUN"` now fails ("No such file or directory").
- **Docs:** [rm(1)][man-rm] · [du(1)][man-du] · [bash][bash-param]

---

## Group N: network fidelity

**What these cards can and cannot see.** Per the [network namespace](https://man7.org/linux/man-pages/man7/network_namespaces.7.html) and [unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html) pages, a Linux network namespace isolates networking resources and the abstract UNIX socket namespace. **Wireshark never sees UNIX-domain sockets** (they do not touch a network device), and a capture on a host interface sees only what *left* the namespace. Attempts blocked inside it leave no packet. That is why N5 (traffic probe) is paired with N6 (syscall trace) and N7 (socket census). The **probe design** is the same for N5 and N6: run each **twice**.

- **Control run, plain terminal:** the command is *not* sandboxed, so traffic is expected. This proves your capture and your analysis can see canary traffic at all. If the control shows nothing, the test is blind.
- **Test run, agent terminal in the sim window:** paste the **exact** command and say only "run exactly this command and report its output, nothing else". Expect no traffic.

**Canary targets.** `192.0.2.0/24` is TEST-NET-1, "provided for use in documentation and examples" ([RFC 5737][rfc5737]); `.invalid` is reserved so that resolvers can assume such names are invalid ([RFC 6761 §6.4][rfc6761]). Neither is a real host.

### N1. List capture interfaces

```bash
dumpcap -D
```

- **Risk:** 🔵 READ.
- **Where it runs:** plain terminal.
- **Why a human gate:** it reveals the host's interface names; you need the right one for N2. It is the first check of whether your capture privileges (N3) are set.
- **Touches:** nothing.
- **Flags:** `-D|--list-interfaces`: "Print a list of the interfaces on which Dumpcap can capture, and exit"; each line has a number and a name, and either can be given to `-i` ([dumpcap(1)][dumpcap-man]).
- **Watch out:** an empty list or a permission error means N3 is not done. **(not in the cited page: whether `-D` needs privileges on every distro; verify.)** Under a user-mode network stack (see [slirp4netns](https://github.com/rootless-containers/slirp4netns)) the sandbox's traffic may appear on the **host's** default-route interface, attributed to a host process, not on a separate interface. Use the control run to learn which interface carries canary traffic.
- **Undo:** none needed.
- **Verify:** you can name the interface that carries the control run's traffic (confirmed in N2/N4).
- **Docs:** [dumpcap(1)][dumpcap-man] · [Wireshark capture privileges][capprivs]

### N2. Capture to a file (evidence)

```bash
mkdir -m 0700 "$EVID/<run-id>-net"
dumpcap -i <iface> -f 'net 192.0.2.0/24 or port 53' -s 512 \
    -a duration:300 -w "$EVID/<run-id>-net/host.pcapng"
chmod 600 "$EVID/<run-id>-net/host.pcapng"
```

- **Risk:** 🟡 REVERSIBLE (writes a capture file), **but sensitive:** it records host traffic metadata (addresses, ports, DNS names, TLS server names).
- **Where it runs:** plain terminal (needs capture privileges, N3), running **while** the probes of N5 and N6 execute.
- **Why a human gate:** packet capture is privileged and records other programs' traffic. A human chooses scope, duration and where the file lives.
- **Touches:** only the output file.
- **Flags:**
    - `-i <iface>`: the interface from N1 ([dumpcap(1)][dumpcap-man]). With no `-i`, "choosing the first non-loopback interface if there are any" (same page), which may not be the one you meant.
    - `-f '<filter>'`: a capture filter in [pcap-filter(7)][pcap-filter] syntax: `net 192.0.2.0/24` ("the source or the destination … address of the packet belongs to" the network) and `port 53`. **`port 53` captures all DNS on the interface, not just the canary**; see the privacy note below.
    - `-s 512`: snapshot length, bytes kept per packet. Headers and DNS names fit; payload is mostly dropped. **(not in the cited pages: whether 512 bytes keeps the TLS server name of large TLS hellos; verify.)**
    - `-a duration:300`: autostop after 300 seconds; `-b filesize:`/`-b files:` make a ring buffer instead ([dumpcap(1)][dumpcap-man]).
    - `-w <file>`: output file. The default format is pcapng (`-n` "is the default", deprecated).
    - `-p` (not used) disables promiscuous mode but "cannot be used to ensure that the only traffic that is captured is traffic sent to or from the machine" ([dumpcap(1)][dumpcap-man]).
- **Watch out:**
    - **Privacy and secrets.** A capture holds who your machine talked to. It must be `0600` in a `0700` directory outside `/tmp`, and be deleted when the verdict is recorded. Do **not** decrypt harness TLS (that would expose prompts and tokens); classify the harness's own traffic by destination and server name only.
    - **DNS visibility depends on the resolver setup.** If the host uses a local stub resolver, a canary lookup may appear on the loopback interface, not the NIC. The control run tells you where to look. **(not in the cited pages: verify with the control run.)**
    - **Blind spots (repeated from above):** blocked in-namespace attempts leave no packet; UNIX sockets are invisible; with a user-mode stack, process attribution is lost.
- **Undo:** `rm "$EVID/<run-id>-net/host.pcapng"`.
- **Verify:** after the **control** probe, N4 shows packets to `192.0.2.1` and a DNS query for the `.invalid` name; after the **test** probe, it shows none.
- **Docs:** [dumpcap(1)][dumpcap-man] · [pcap-filter(7)][pcap-filter] · [Wireshark capture privileges][capprivs]

### N3. Give your user capture privileges (decide deliberately)

```bash
sudo setcap cap_net_raw,cap_net_admin+eip /usr/sbin/dumpcap      # or /usr/bin/dumpcap
getcap /usr/sbin/dumpcap
```

or the group method, from the same page:

```bash
sudo groupadd --system wireshark
sudo gpasswd -a $USER wireshark
sudo chgrp wireshark /usr/sbin/dumpcap
sudo chmod o-rx /usr/sbin/dumpcap
sudo setcap cap_net_raw,cap_net_admin+eip /usr/sbin/dumpcap      # chgrp clears file capabilities
```

- **Risk:** 🔴 DESTRUCTIVE in the sense of **privilege**: it permanently lets a normal user capture **all traffic on the host**, including other programs' traffic and the database's loopback traffic. Reversible only by undoing the exact steps.
- **Where it runs:** plain terminal; system-administration commands (`sudo`). This is the only card with `sudo`.
- **Why a human gate:** it widens privilege on the machine. Under the standing rules agents never do this, and never ask to.
- **Touches:** file capabilities (or ownership/mode) of the `dumpcap` binary; for the group method, the system group database.
- **Flags:**
    - `setcap cap_net_raw,cap_net_admin+eip <dumpcap>`: the documented file-capabilities method. Wireshark's guidance: "the vast majority of Wireshark's code is run as a normal user", only `dumpcap` needs privilege. Use `/usr/bin` if the error says `dumpcap` is not in `/usr/sbin` ([capture privileges][capprivs]).
    - The wiki's **set-UID** alternative (`chown root`, `chmod u+s`) is for systems without file capabilities; **not recommended here**.
    - Group method: create the group `wireshark`, add yourself, make the binary group-owned, remove "other" access ([capture privileges][capprivs]); log out and in (or `newgrp wireshark`).
    - **Debian and Ubuntu:** the wiki points to `README.Debian` in the package's `packaging/debian` directory rather than giving commands. **That file was not read while drafting this page**; follow your package's own instructions.
- **Watch out:**
    - Once `dumpcap` has these rights, **any process of yours** can capture. Prefer the group method on a machine you trust; revisit if this host ever has other users.
    - Package updates can reset file capabilities. **(not in the cited page: verify after an update.)** Re-check with `getcap`.
- **Undo:** `sudo setcap -r /usr/sbin/dumpcap` removes capabilities (`setcap -r` is documented in the `setcap(8)` page, **not fetched here: read `man setcap`**); `sudo gpasswd -d $USER wireshark` leaves the group.
- **Verify:** `getcap` lists the capabilities; as a normal user, `dumpcap -D` (N1) lists interfaces.
- **Docs:** [Wireshark capture privileges][capprivs] · [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)

### N4. Analyze a capture (no privileges needed)

```bash
tshark -r "$EVID/<run-id>-net/host.pcapng" -q -z conv,ip
tshark -r "$EVID/<run-id>-net/host.pcapng" -Y 'ip.addr == 192.0.2.0/24'
tshark -r "$EVID/<run-id>-net/host.pcapng" -Y 'dns.qry.name contains "invalid"' \
    -T fields -e frame.number -e ip.src -e dns.qry.name
```

- **Risk:** 🔵 READ.
- **Where it runs:** plain terminal.
- **Why a human gate:** the captured file is sensitive evidence, and one `tshark` option in particular must never be used (below).
- **Touches:** reads the capture; writes nothing.
- **Flags:**
    - `-r <file>`: read a capture file instead of sniffing ([tshark(1)][tshark-man]).
    - `-q`: quiet; with `-z` shows only the statistic.
    - `-z conv,ip`: a table of every IP conversation in the capture ([tshark `-z conv`][tshark-man]); anything that is not the harness's destinations and not a canary needs an explanation.
    - `-Y '<display filter>'`: only matching packets are printed. `ip.addr == 192.0.2.0/24` uses CIDR notation, as the [Wireshark display filter guide](https://www.wireshark.org/docs/wsug_html_chunked/ChWorkBuildDisplayFilterSection.html) shows (`ip.addr == 129.111.0.0/16`). Field names are in the field references for [`ip`](https://www.wireshark.org/docs/dfref/i/ip.html), [`dns`](https://www.wireshark.org/docs/dfref/d/dns.html) and [`frame`](https://www.wireshark.org/docs/dfref/f/frame.html).
    - `-T fields -e <field>`: print only the named fields.
- **Watch out:**
    - **Never run `tshark -z credentials`** on these files. It "Collect[s] credentials (username/passwords)" from FTP, HTTP, IMAP, POP and SMTP and prints the password ([tshark(1)][tshark-man]). It has no purpose in this program.
    - **Pass criteria** (proposal §AW.8.9), for a `SIM-N` run: zero packets to `192.0.2.0/24`; zero DNS queries for the `.invalid` canary; nothing else that is not harness traffic.
    - Do not open evidence from a run you did not capture yourself.
- **Undo:** none (read only).
- **Verify:** for the control capture, the 192.0.2.1 conversation and the DNS query appear (the capture can see canary traffic). Otherwise the whole test is blind.
- **Docs:** [tshark(1)][tshark-man] · [Wireshark display filters](https://www.wireshark.org/docs/wsug_html_chunked/ChWorkBuildDisplayFilterSection.html)

### N5. Traffic canary (curl to TEST-NET and `.invalid`)

```bash
curl -sS -I --noproxy '*' --connect-timeout 3 -m 5 http://192.0.2.1/ ; echo "exit=$?"
curl -sS -I --noproxy '*' --connect-timeout 3 -m 5 http://sim-canary.invalid/ ; echo "exit=$?"
```

- **Risk:** 🟡 REVERSIBLE. Sends at most one SYN to a documentation address and one DNS query for a reserved name; nothing answers.
- **Where it runs:** **both**, as described above: a **control** in a plain terminal (while N2 captures), then the **test** pasted into the agent terminal of the sim window (while N2 captures).
- **Why a human gate:** it deliberately attempts network access. A human chooses the canaries and is the one asking the agent to run a *fixed* line, never an open "test the network" task.
- **Touches:** the network stack; no files.
- **Flags** (from [curl(1)][curl-man]):
    - `-s -S`: silent, but still show errors; `-I` HEAD only.
    - `--noproxy '*'`: "The only wildcard is a single `*` character, which matches all hosts, and effectively disables the proxy", so a proxy variable in the environment cannot redirect the probe.
    - `--connect-timeout 3`: limits the connection phase (DNS plus handshakes); `-m 5`: total time limit.
    - Exit codes, documented in the same page: **6** could not resolve host, **7** failed to connect, **28** operation timeout.
- **Watch out:**
    - **How to read the exit code.** The control run is expected to time out (28) or fail to connect (7), because nothing answers; the point is that the **packets are visible on the wire**. In the test run, an exit of **28 after the full 3 seconds, with packets on the wire in N2/N4,** means the sandbox let the attempt reach a real route, a **leak**. An immediate 6 or 7 with **no packets** is the pass.
    - Do not point the canary at an address you do not control, and do not use `ping` (it needs raw sockets and tells you less).
- **Undo:** none.
- **Verify:** compare control vs test in N4 (pass criteria there). Keep both captures with the verdict.
- **Docs:** [curl(1)][curl-man] · [RFC 5737][rfc5737] · [RFC 6761 §6.4][rfc6761]

### N6. Syscall trace of the same probe

```bash
strace -f -tt -e trace=%network -o "<dir>/probe.strace" \
    curl -sS -I --noproxy '*' --connect-timeout 3 -m 5 http://192.0.2.1/
```

- **Risk:** 🟡 REVERSIBLE. Traces one `curl`; writes one file.
- **Where it runs:** **both.** Control: plain terminal, `<dir>` = `$EVID/<run-id>-net`. Test: agent terminal in the sim window, `<dir>` = `$RUN/logs` (the only place it can write); ECD reads the file with `cat -v` afterwards.
- **Why a human gate:** `strace` uses `ptrace`, which is a debugging capability; whether it is allowed in the sandbox is itself a finding.
- **Touches:** the traced process and the output file.
- **Flags** ([strace(1)][strace-man]):
    - `-f` (`--follow-forks`): also trace child processes.
    - `-tt`: absolute timestamps with microseconds.
    - `-e trace=%network`: "Traces all the network related system calls" (`socket`, `connect`, `sendto`, …); this includes `AF_UNIX` attempts, which Wireshark cannot see.
    - `-o <file>`: write the trace to a file instead of stderr.
- **Watch out:**
    - **What it adds over N5:** it sees every *attempt*, with the failing error code, even when no packet ever leaves the namespace. A test run that shows `connect(...) = -1 <error>` and an empty capture is the strongest pass.
    - **`strace` may be unable to run in the sandbox at all** (the host's ptrace policy, or the sandbox's filters). **(not in the docs: verify, VF-S7.)** If it fails to start, record that; it is not a pass.
    - It slows the traced process; it traces **the probe**, not the agent.
- **Undo:** `rm` the trace file.
- **Verify:** the control trace contains `connect(` lines to `192.0.2.1`; the test trace shows what the sandbox did with them.
- **Docs:** [strace(1)][strace-man]

### N7. Socket census (UNIX-domain sockets, the biggest blind spot)

```bash
ss -x -a -p -n
ss -x -l -p
```

- **Risk:** 🔵 READ.
- **Where it runs:** plain terminal (the host's view). A view from inside the sandbox needs N8 or a test-run paste.
- **Why a human gate:** sockets such as `ssh-agent`, `gpg-agent`, container daemons and D-Bus are doors to privileged services. Knowing what is reachable is the audit's central question.
- **Touches:** reads kernel socket tables.
- **Flags** ([ss(8)][ss-man]): `-x` UNIX sockets; `-a` all (listening and not); `-l` listening only; `-p` the process using each socket; `-n` numeric (no name resolution).
- **Watch out:**
    - Pathname sockets are governed by file permissions and the sandbox's path rules; **abstract sockets** (a null first byte in the path) are governed by the network namespace ([unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html), [network_namespaces(7)](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)).
    - `ss` is a **snapshot**, not a log. Process names for other users' sockets may need privileges. **(not in the cited page: verify.)**
    - It tells you what exists, not what the sandbox lets a process reach.
- **Undo:** none (read only).
- **Verify:** you can list which UNIX sockets exist and who owns them. Reconcile that list with the sandbox's path rules: any socket the sandbox's filesystem policy would let a process open needs a reason.
- **Docs:** [ss(8)][ss-man] · [unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html)

### N8. Look from inside the sandbox's network namespace

```bash
nsenter --target <pid> --net --no-fork -- dumpcap -D
nsenter --target <pid> --net --no-fork -- ss -x -a -n
```

- **Risk:** 🟡 REVERSIBLE in effect, but **privileged**, and with real chances of failure or surprise.
- **Where it runs:** plain terminal, against the PID of a **sandboxed process** (for example, a long-running command ECD asked the agent to start; N5's `curl` is too short-lived).
- **Why a human gate:** you are attaching to another process's namespace. The question is whether you may, and whether it shows the truth.
- **Touches:** nothing persistent; it runs the named program in the target's network namespace.
- **Flags** ([nsenter(1)][nsenter-man]): `-t|--target <pid>`: the process whose namespaces to enter; `-n|--net`: its network namespace; `-F|--no-fork`: run the program directly without forking.
- **Watch out:**
    - **Whether `nsenter --net` works for a process in an unprivileged user namespace is not established.** (not in the docs: verify, VF-S7.) You may need privileges, or it may fail outright. A failure is a finding about your observation options, not about the sandbox.
    - Capturing inside the namespace sees traffic **at the namespace boundary**, including attempts that go nowhere. It needs the exact interface name (unknown until rehearsed).
- **Undo:** none (nothing changed).
- **Verify:** the interface list (or socket list) is **different from the host's** (otherwise you are looking at the host namespace).
- **Docs:** [nsenter(1)][nsenter-man] · [network_namespaces(7)](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)

---

## Group K: signing rehearsal with throwaway keys

**Purpose.** Rehearse the rituals the long-range goal needs (generate a key, sign a file, verify with an allowed-signers file, handle expiry, revocation and tampering) **without real keys, real data or a real database**. A throwaway key never leaves `$RUN/keys` and is never added to any real allowed-signers file. The sim signature namespace is `cnf-sim@codenforce.invalid`, so it can **never verify as a real signature**: the [signature format](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig) binds each signature to a namespace "to prevent cross-protocol attacks caused by signatures intended for one intended domain being accepted in another", and the [ssh-keygen page][ssh-keygen-man] recommends `NAMESPACE@YOUR.DOMAIN` names for custom uses.

**Who runs.** The agent in a `SIM-K` run inside `$RUN/keys`, or ECD (or a new trusted user with an admin watching) in a scratch directory. The real ceremony is not on this page.

### K1. Generate a throwaway keypair

```bash
mkdir -m 0700 "$RUN/keys"
ssh-keygen -t ed25519 -N '' -C 'sim-signer@codenforce.invalid' -f "$RUN/keys/sim_signer"
ls -l "$RUN/keys"
ssh -V
```

- **Risk:** 🟡 REVERSIBLE. Creates two files in a directory you made.
- **Where it runs:** agent terminal in a `SIM-K` run, or a plain terminal in a scratch directory.
- **Why a human gate:** this is the step the real ceremony will repeat, so it should look the way you want the real one to. Here the key is deliberately disposable.
- **Touches:** `$RUN/keys/sim_signer` (private) and `sim_signer.pub`.
- **Flags** ([ssh-keygen(1)][ssh-keygen-man]): `-t ed25519` key type (EdDSA is specified in [RFC 8032][rfc8032]); `-N ''` an **empty passphrase** (acceptable *only* because the key is disposable); `-C` the comment stored in the key; `-f` the output file.
- **Watch out:**
    - **The real ceremony must not use an empty passphrase, and should not use a key file at all:** a hardware-bound key type (`ed25519-sk`, a FIDO authenticator that needs a physical touch) is listed on the same page. That choice belongs to the trust proposal (`PTC.0`), not here.
    - The OpenBSD page tracks the newest OpenSSH; **your installed `ssh-keygen` may lack some options.** `ssh -V` prints the version; compare with `man ssh-keygen` locally.
- **Undo:** `rm -r "$RUN/keys"`.
- **Verify:** `ls -l` shows `sim_signer` readable by the owner only (`-rw-------`; **not stated in the cited page: check it**) and `sim_signer.pub`.
- **Docs:** [ssh-keygen(1)][ssh-keygen-man] · [RFC 8032][rfc8032]

### K2. Sign a file (detached signature)

```bash
printf 'id,name\n1,example\n' > "$RUN/out/sample.csv"
ssh-keygen -Y sign -f "$RUN/keys/sim_signer" -n cnf-sim@codenforce.invalid "$RUN/out/sample.csv"
ls -l "$RUN/out"
```

- **Risk:** 🟡 REVERSIBLE. Writes `sample.csv` and `sample.csv.sig`.
- **Where it runs:** same as K1.
- **Why a human gate:** signing is the act of vouching. Here it vouches for nothing, deliberately.
- **Touches:** `$RUN/out/`.
- **Flags** ([ssh-keygen(1)][ssh-keygen-man], `-Y sign`):
    - `-f`: the key. It "may refer to either a private key, or a public key with the private half available via ssh-agent"; use the **private key file** here so no agent is involved.
    - `-n <namespace>`: required; "An additional signature namespace, used to prevent signature confusion across different domains of use".
    - Output: "Signatures are written to the path of the input file with `.sig` appended."
    - `-O hashalg=sha256|sha512`: the hash applied to the message first (default **sha512**). The proposal for real signing (`PTC.0`) will need a decision on this.
- **Watch out:** the signature is over the file's **bytes**. For tabular data a canonical byte form must be chosen first (see `PTC.0`); this card signs a toy file.
- **Undo:** `rm "$RUN/out/sample.csv" "$RUN/out/sample.csv.sig"`.
- **Verify:** `sample.csv.sig` exists and starts with `-----BEGIN SSH SIGNATURE-----` (the armored format in [PROTOCOL.sshsig](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig)).
- **Docs:** [ssh-keygen(1)][ssh-keygen-man] · [PROTOCOL.sshsig](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig)

### K3. Verify with an allowed-signers file

```bash
echo "sim-signer@codenforce.invalid namespaces=\"cnf-sim@codenforce.invalid\" $(cut -d' ' -f1,2 "$RUN/keys/sim_signer.pub")" \
    > "$RUN/keys/allowed_signers"
ssh-keygen -Y verify -f "$RUN/keys/allowed_signers" -I sim-signer@codenforce.invalid \
    -n cnf-sim@codenforce.invalid -s "$RUN/out/sample.csv.sig" < "$RUN/out/sample.csv" ; echo "exit=$?"
```

- **Risk:** 🟡 REVERSIBLE. Writes `allowed_signers`.
- **Where it runs:** same as K1.
- **Why a human gate:** the allowed-signers file **is** the trust decision: who may sign, for what, until when. In the real system, writing it is an admin act (`PTC.0`).
- **Touches:** `$RUN/keys/allowed_signers`.
- **Flags** ([ssh-keygen(1)][ssh-keygen-man], "ALLOWED SIGNERS" and `-Y verify`):
    - File format: each line is `principals options keytype base64-key`; `#` lines are comments. The principal is a `USER@DOMAIN` pattern.
    - `namespaces="<list>"`: "the signature namespace embedded in the signature object and presented on the verification command-line must match the specified list before the key will be considered acceptable".
    - `-Y verify`: the message comes on **standard input**; `-s` the signature file, `-I` the signer identity, `-n` the namespace, `-f` the allowed-signers file. "Successful verification by an authorized signer is signalled by `ssh-keygen` returning a zero exit status."
    - `cut -d' ' -f1,2`: keeps the key type and the base64 key, drops the comment field of the `.pub` file ([cut(1)](https://man7.org/linux/man-pages/man1/cut.1.html)).
- **Watch out:** the exact wording of the success message is **(not in the cited page)**; rely on `exit=0`.
- **Undo:** `rm "$RUN/keys/allowed_signers"`.
- **Verify:** `exit=0` for the matching case.
- **Docs:** [ssh-keygen(1)][ssh-keygen-man]

### K4. Negative tests: tampering, wrong namespace, wrong identity

```bash
cp "$RUN/out/sample.csv" "$RUN/out/sample-tampered.csv" && printf 'x' >> "$RUN/out/sample-tampered.csv"
ssh-keygen -Y verify -f "$RUN/keys/allowed_signers" -I sim-signer@codenforce.invalid \
    -n cnf-sim@codenforce.invalid -s "$RUN/out/sample.csv.sig" < "$RUN/out/sample-tampered.csv" ; echo "exit=$?"
ssh-keygen -Y verify -f "$RUN/keys/allowed_signers" -I sim-signer@codenforce.invalid \
    -n file -s "$RUN/out/sample.csv.sig" < "$RUN/out/sample.csv" ; echo "exit=$?"
ssh-keygen -Y verify -f "$RUN/keys/allowed_signers" -I someone-else@codenforce.invalid \
    -n cnf-sim@codenforce.invalid -s "$RUN/out/sample.csv.sig" < "$RUN/out/sample.csv" ; echo "exit=$?"
ssh-keygen -Y find-principals -s "$RUN/out/sample.csv.sig" -f "$RUN/keys/allowed_signers"
ssh-keygen -Y check-novalidate -n cnf-sim@codenforce.invalid -s "$RUN/out/sample.csv.sig" < "$RUN/out/sample.csv" ; echo "exit=$?"
```

- **Risk:** 🔵 READ (the one `cp` writes a scratch file).
- **Where it runs:** same as K1.
- **Why a human gate:** a signing scheme is only as good as its failures. Each line below must **fail** or the ritual is unsafe.
- **Touches:** `sample-tampered.csv` only.
- **Flags** ([ssh-keygen(1)][ssh-keygen-man]):
    - Tampered message, wrong namespace, wrong identity: each must give a **non-zero** exit.
    - `-Y find-principals`: "Find the principal(s) associated with the public key of a signature … in an authorized signers file"; prints the matches.
    - `-Y check-novalidate`: "Checks that a signature … has a valid structure. This does **not** validate if a signature comes from an authorized signer."
- **Watch out:** **never use `check-novalidate` as a trust decision.** It proves the file is a well-formed signature, nothing about who made it. In any real procedure, only `-Y verify` against an allowed-signers file counts.
- **Undo:** `rm "$RUN/out/sample-tampered.csv"`.
- **Verify:** the three failing cases exit non-zero; `find-principals` prints `sim-signer@codenforce.invalid`; `check-novalidate` exits 0 **and that proves nothing about trust**.
- **Docs:** [ssh-keygen(1)][ssh-keygen-man]

### K5. Validity windows, revocation, and what a signature does *not* say

```bash
echo "sim-signer@codenforce.invalid namespaces=\"cnf-sim@codenforce.invalid\",valid-after=\"20261101Z\",valid-before=\"20261231Z\" $(cut -d' ' -f1,2 "$RUN/keys/sim_signer.pub")" \
    > "$RUN/keys/allowed_signers_window"
for T in 20261031Z 20261115Z 20270101Z; do
  ssh-keygen -Y verify -f "$RUN/keys/allowed_signers_window" -I sim-signer@codenforce.invalid \
    -n cnf-sim@codenforce.invalid -s "$RUN/out/sample.csv.sig" -O verify-time=$T < "$RUN/out/sample.csv" ; echo "verify-time=$T exit=$?"
done
cp "$RUN/keys/sim_signer.pub" "$RUN/keys/revoked_keys"
ssh-keygen -Y verify -f "$RUN/keys/allowed_signers" -I sim-signer@codenforce.invalid \
    -n cnf-sim@codenforce.invalid -s "$RUN/out/sample.csv.sig" -r "$RUN/keys/revoked_keys" < "$RUN/out/sample.csv" ; echo "revoked exit=$?"
```

- **Risk:** 🟡 REVERSIBLE (writes two small files).
- **Where it runs:** same as K1.
- **Why a human gate:** these are the offboarding and expiry mechanics, the part of the trust lifecycle that costs the most if it is wrong.
- **Touches:** `allowed_signers_window`, `revoked_keys` in `$RUN/keys`.
- **Flags** ([ssh-keygen(1)][ssh-keygen-man]):
    - `valid-after="<ts>"`, `valid-before="<ts>"` in the allowed-signers options: the key is valid "at or after" / "at or before" the timestamp, `YYYYMMDD[Z]` or `YYYYMMDDHHMM[SS][Z]`; a `Z` suffix means UTC, otherwise the **system time zone**.
    - `-O verify-time=<ts>`: "a time to use when validating signatures instead of the current time", same formats.
    - `-r <revocation_file>`: "The revocation file may be a KRL or a one-per-line list of public keys." Here: a list with one public key.
    - Expected: `20261031Z` **fails** (before `valid-after`); `20261115Z` **succeeds**; `20270101Z` **fails**; the **revoked** run **fails** even though `allowed_signers` still lists the key.
- **Watch out (the important one):** **a signature carries no signing time.** The signature blob consists of the public key, the namespace, a reserved field, the hash algorithm and the signature, and nothing else ([PROTOCOL.sshsig §2](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig)). `verify-time` is a time **the verifier chooses**. Therefore "signed *before* the key was revoked or expired" cannot be proven by the signature alone; it needs an **external timestamp** (for example an [RFC 3161][rfc3161] time-stamp or an append-only transparency log) recorded at signing time. That is a design requirement for `PTC.0`, found here by rehearsal.
- **Undo:** `rm "$RUN/keys/allowed_signers_window" "$RUN/keys/revoked_keys"`.
- **Verify:** the four expectations above.
- **Docs:** [ssh-keygen(1)][ssh-keygen-man] · [PROTOCOL.sshsig](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig) · [RFC 3161][rfc3161]

---

## Deliberately not carded

- **`tshark -z credentials`** (extracts cleartext passwords from captures): never run on these files.
- **Decrypting TLS** (key-log files and similar): would expose prompts and tokens; classify the harness's traffic by destination and server name only.
- **A loopback canary and a LAN canary** (a throwaway listener on an unused port; a known-quiet private address): the only way to *test* N-S3 and N-S9 of the proposal. Not carded until you answer **Q-SIM-9**, because each needs its own listener lifecycle.
- **Hook contents** for `$RUN/hooks`: ECD writes them; what they record and whether any may enforce is **Q-SIM-2**-adjacent design, not a command.
- **Anything the agent runs inside the clone** (`reset --hard`, `rebase`, `gc`, `reflog expire`, `clean`): these are the point of the segment and are *allowed* there (proposal §AW.8.6); they would be 🔴 on the real repository, and have no cards because the real repository is not touched.
- **`sudo` anywhere except N3**, package installs, `docker`, starting listeners or daemons from the sim.
- **The database.** No card touches or probes it. The sandbox policy keeps local-network access **off** because the database listens on the local host, and that is verified by reading the policy, not by connecting.

## Items to settle in the rehearsal (proposal phase 8b)

These are the unverified claims the cards depend on; the proposal lists them as `VF-S1`..`VF-S10`. The ones that change what a card means:

- **VF-S1** whether and how the agent terminal gets the S5 environment (affects S5, N-group logging).
- **VF-S2** that a sim terminal cannot read or write `/tmp/cnf-sim/<other-run>` or the replay root (affects S6 and the placement of `sim-env.sh`).
- **VF-S4** what an empty `GIT_ALLOW_PROTOCOL` does (S5).
- **VF-S6, VF-S7** what network namespace the sandbox creates, and whether `strace` and `nsenter --net` work there (N6, N8).
- **The `/tmp` cleanup age and backing store** on this host (S1).

---

[g-C]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L61
[g-cfg]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L708
[g-nosys]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L718
[g-ceil]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L518
[g-ask]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L697
[g-prompt]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L704
[g-t2]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L852
[g-proto]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L924
[g-pager]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L642
[g-editor]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L652
[g-seq]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L658
[g-aname]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L561
[g-aemail]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L566
[g-adate]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L571
[g-cdate]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L585
[g-datefmt]: https://github.com/git/git/blob/v2.43.0/Documentation/date-formats.txt#L7
[clone-b]: https://github.com/git/git/blob/v2.43.0/Documentation/git-clone.txt#L209
[bundle-create]: https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L65
[bundle-verify]: https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L71
[bundle-heads]: https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L83
[bundle-empty]: https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L168
[bundle-self]: https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L198
[bundle-all]: https://github.com/git/git/blob/v2.43.0/Documentation/git-bundle.txt#L206
[remote-rm]: https://github.com/git/git/blob/v2.43.0/Documentation/git-remote.txt#L94
[cfg-proto]: https://github.com/git/git/blob/v2.43.0/Documentation/config/protocol.txt#L1
[cfg-proto-name]: https://github.com/git/git/blob/v2.43.0/Documentation/config/protocol.txt#L23
[cfg-init-tmpl]: https://github.com/git/git/blob/v2.43.0/Documentation/config/init.txt#L1
[cfg-hooks]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L499
[cfg-fsmon]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L64
[cfg-ssh]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L266
[cfg-editor]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L516
[cfg-pager]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L543
[revs-type]: https://github.com/git/git/blob/v2.43.0/Documentation/revisions.txt#L170
[gc-local]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L134
[gc-list]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L182
[gc-origin]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L242
[layout-logs]: https://github.com/git/git/blob/v2.43.0/Documentation/gitrepository-layout.txt#L240
[rp-verify]: https://github.com/git/git/blob/v2.43.0/Documentation/git-rev-parse.txt#L98
[man-mkdir]: https://man7.org/linux/man-pages/man1/mkdir.1.html
[man-stat]: https://man7.org/linux/man-pages/man1/stat.1.html
[man-tmpfiles8]: https://man7.org/linux/man-pages/man8/systemd-tmpfiles.8.html
[man-tmpfiles5]: https://man7.org/linux/man-pages/man5/tmpfiles.d.5.html
[man-inode]: https://man7.org/linux/man-pages/man7/inode.7.html
[man-sha256]: https://man7.org/linux/man-pages/man1/sha256sum.1.html
[man-cat]: https://man7.org/linux/man-pages/man1/cat.1.html
[man-du]: https://man7.org/linux/man-pages/man1/du.1.html
[man-find]: https://man7.org/linux/man-pages/man1/find.1.html
[man-cp]: https://man7.org/linux/man-pages/man1/cp.1.html
[man-rm]: https://man7.org/linux/man-pages/man1/rm.1.html
[man-diff]: https://man7.org/linux/man-pages/man1/diff.1.html
[bash-param]: https://www.gnu.org/software/bash/manual/bash.html#Shell-Parameter-Expansion
[bash-invoke]: https://www.gnu.org/software/bash/manual/bash.html#Invoking-Bash
[vsc-profile-cli]: https://code.visualstudio.com/docs/configure/profiles#_command-line
[dumpcap-man]: https://www.wireshark.org/docs/man-pages/dumpcap.html
[tshark-man]: https://www.wireshark.org/docs/man-pages/tshark.html
[capprivs]: https://wiki.wireshark.org/CaptureSetup/CapturePrivileges
[pcap-filter]: https://www.tcpdump.org/manpages/pcap-filter.7.html
[curl-man]: https://curl.se/docs/manpage.html
[strace-man]: https://man7.org/linux/man-pages/man1/strace.1.html
[ss-man]: https://man7.org/linux/man-pages/man8/ss.8.html
[nsenter-man]: https://man7.org/linux/man-pages/man1/nsenter.1.html
[ssh-keygen-man]: https://man.openbsd.org/ssh-keygen.1
[rfc5737]: https://www.rfc-editor.org/rfc/rfc5737
[rfc6761]: https://www.rfc-editor.org/rfc/rfc6761#section-6.4
[rfc8032]: https://www.rfc-editor.org/rfc/rfc8032
[rfc3161]: https://www.rfc-editor.org/rfc/rfc3161
