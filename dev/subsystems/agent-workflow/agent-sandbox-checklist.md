---
title: Agent Sandbox Configuration Checklist (Transparency, Logging, Proactive Management)
description: Checklist for locking down and observing coding agents that run in git worktrees on one repository. Covers sandbox settings, approvals, .git hardening, per-worktree attribution and logging, and ongoing sweeps. Every setting and command is linked to the official documentation and carries a risk profile.
published: false
date: 2026-10-29T00:00:00.000Z
tags: subsystem:agent-workflow, audience:dev, type:checklist, status:draft
editor: markdown
dateCreated: 2026-10-29T00:00:00.000Z
---

# Agent Sandbox Configuration Checklist

> **Status: DRAFT, UNTESTED.** Written from the VS Code agent documentation as fetched on **2026-10-29** and the Git 2.43.0 documentation. VS Code's sandbox and approval features are **Preview** and have already changed since the [August 2026 hardening note](/dev/reference/vscode-copilot-sandbox-hardening-aug2026). Nothing here has been executed. Where a fact is not in the cited documentation it is marked **(not in the docs: verify)**.
> **Audience:** ECD, the only human who changes settings, runs git, and approves anything.
> **Companion pages:** [worktree primer](/dev/subsystems/agent-workflow/worktree-orchestration-primer) (the workflow) · [command cards](/dev/subsystems/agent-workflow/worktree-command-cards) (every git command, with flags and risk).

## 0. How to use this page

This is a one-time setup checklist plus a recurring one (§11). Each item has the same shape:

- **What to do**, with the setting or command.
- **Why**: what the control actually does, and what it does *not* do.
- **Verify**: how to confirm it took effect. A control you have not verified is a hope, not a control.
- **Risk** (for commands only), using the same legend as the [command cards](/dev/subsystems/agent-workflow/worktree-command-cards#how-to-read-a-card): 🔵 READ, 🟡 REVERSIBLE, 🔴 DESTRUCTIVE.
- **Docs**: the page the claim comes from.

**What this page is, honestly.** All agent commands run as your Unix user. VS Code states that the sandbox "is not a virtual machine or user-account boundary" ([sandbox boundary][vsc-sandbox-boundary]). So the goal is **enforced limits for a well-meaning agent, plus transparency good enough to detect an accident or a surprise**. It is *not* a defence against a deliberately hostile agent or a compromised toolchain. Hooks and instructions "are not substitutes for enforced permissions, sandboxing, or enterprise controls" ([hooks security][vsc-hooks-sec]).

**Rule of the house:** agents are read-only outside the repository and `/tmp/`; everything else is blocked. The next section turns that sentence into paths.

---

## 1. Policy: the three tiers (PL)

- [ ] **PL-1. Adopt these tiers.** They are the target every later item enforces.

| Tier | What | Enforced by |
|---|---|---|
| **Read-write** | The agent's own worktree (its working folder) and `/tmp` | The sandbox grants read-write to the *current working directory* automatically ([file system access][vsc-sandbox-fs]). `/tmp` write access: **(not in the docs: verify in `/sandbox policy`; add it to `readwritePaths` if absent)** |
| **Read-only** | Toolchain (JDK, Maven), `~/.m2/repository`, the main checkout, wikidocs | `userConfiguredPaths.readonlyPaths` ([file system access][vsc-sandbox-fs]) |
| **Blocked** | Network, ssh, sudo, secrets, git writes, database, deploys | `network.allowNetwork: false`, `deniedPaths`, `allowUnsandboxedCommands: false`, approvals, `.git` placement (§7) |

- **Why a worktree helps here (an inference, not a documented guarantee).** For a *linked* worktree, Git's real directory lives in the main repository (`<main>/.git/worktrees/<id>/`, objects and refs in `<main>/.git/`), which is **outside** the worktree folder ([git-worktree DETAILS][g-wt-details]). If the sandbox grants write only to the worktree folder, a `git add` or `git commit` run by the agent has nowhere writable to put its results and should **fail**. In today's single checkout, `.git/` is *inside* the working directory, so the sandbox cannot make that distinction. **(not in the docs: verify in rehearsal, VF-4)**
- **Open question Q-AW-1 (policy tension).** Your standing rule says shell reads stay inside `/tmp` and the mapped workspace folders. A JDK and `~/.m2` sit outside both. Either (a) widen "read" to a short read-only toolchain list as above, or (b) copy the toolchain into `/tmp` per session. The spec lists this as a decision; this page assumes (a).
- **Verify:** none yet; PL-1 is a decision. Record the decision in the spec.

---

## 2. Host prerequisites on Linux (HP)

The sandbox on Linux needs more than the August note listed ([platform availability][vsc-sandbox-platform]).

- [ ] **HP-1. Confirm the platform is supported.** glibc-based Linux or WSL2 (not WSL 1, not Alpine or other musl distributions) ([platform availability][vsc-sandbox-platform]). Remote, WSL, or Dev Container sessions need the packages **on the machine where the agent runs**, not where you view it ([install dependencies][vsc-sandbox-install]).
- [ ] **HP-2. Install the packages (ECD, with `sudo`).** Card below.
- [ ] **HP-3. Confirm kernel facilities.** Per the documentation Linux also needs "unprivileged user and network namespaces and read/write access to `/dev/net/tun`", and `unshare` must support `--map-current-user` and `--keep-caps`. If the packages are present and these are blocked, "ask your administrator or container owner to fix the environment" ([install dependencies][vsc-sandbox-install]). **How to test is not given in the docs;** the test is HP-4.
- [ ] **HP-4. Prove the sandbox actually starts.** Start a *new* Copilot-harness session and run `/sandbox policy` (see VF-1). "If an operating system dependency is unavailable, the command does not silently run without the sandbox" ([turn on sandboxing][vsc-sandbox-on]), so a missing dependency shows up as a notification, not as silent exposure.

#### Card HP-2. `sudo apt-get update` then `sudo apt-get install bubblewrap slirp4netns util-linux iptables`

```bash
sudo apt-get update
sudo apt-get -s install bubblewrap slirp4netns util-linux iptables     # simulate first
sudo apt-get install bubblewrap slirp4netns util-linux iptables
```

- **Risk:** 🟡 REVERSIBLE (`apt-get remove`), but it runs as root and installs system packages. Read the simulated list before the real run.
- **Why a human gate:** root-level change to the host. An agent must never run it, and the sandbox blocks `sudo` anyway.
- **Command:** this is the exact Ubuntu/Debian recipe from VS Code's troubleshooting section ([install dependencies][vsc-sandbox-install]). Packages: `bubblewrap` (`bwrap` ≥ 0.5.0), `slirp4netns`, `util-linux` ≥ 2.35 (`unshare`, `nsenter`), `iptables` (must supply `iptables`, `ip6tables`, `iptables-restore`, `ip6tables-restore` with a compatible backend).
- **Flags:**
    - `update`: refreshes the package index from the configured mirrors (network access by *you*, not the agent). The documentation says to run it first and wait for it to succeed.
    - `-s` (`--simulate`, `--just-print`, `--dry-run`, `--recon`, `--no-act`): "No action; perform a simulation of events that would occur ... but do not actually change the system." Locking is disabled in a simulation, and a non-root simulation may be distorted by missing configuration access ([apt-get -s][apt-get-s]).
    - **No `-y`.** `-y` ("assume yes") would skip the confirmation prompt that shows you the install list ([apt-get -y][apt-get-y]).
- **Watch out:** the docs do not say what these packages change beyond installing them. Read the simulated `Inst`/`Conf` lines for anything you did not expect (for example a package replacing your current firewall tooling).
- **Undo:** `sudo apt-get remove <pkg>` per package (not in the VS Code page; see [apt-get][apt-get-s]).
- **Verify:** `bwrap --version`, `slirp4netns --version`, `unshare --help` (reports whether `--map-current-user` exists), `iptables --version`; then HP-4.
- **Docs:** [VS Code: install missing sandbox dependencies][vsc-sandbox-install] · [apt-get(8)][apt-get-s]

---

## 3. Sandbox settings (SB)

Put these in **User settings** on the machine where agents run. Do **not** put them in a worktree's `.vscode/settings.json`: the agent can write files inside its worktree (see ST-3).

```jsonc
{
  "chat.agent.sandbox.enabled": "on",

  "chat.agent.sandbox.network.allowNetwork": false,
  "chat.agent.sandbox.network.allowLocalNetwork": false,

  "chat.agent.sandbox.fileSystem.allowDevToolAccess": false,
  "chat.agent.sandbox.fileSystem.userConfiguredPaths": {
    "readwritePaths": ["/tmp"],
    "readonlyPaths": [
      "<JDK_HOME>",
      "<MAVEN_HOME>",
      "<HOME>/.m2/repository",
      "/home/echocdelta/pierre15Home22DEC/cnf/codenforce",
      "/home/echocdelta/pierre15Home22DEC/cnf/boroughforge-wikidocs"
    ],
    "deniedPaths": [
      "<HOME>/.ssh",
      "<HOME>/.gnupg",
      "<HOME>/.aws",
      "<HOME>/.config/gh",
      "<HOME>/.m2/settings.xml"
    ]
  },

  "chat.agent.sandbox.credentials.authenticategit": false,
  "chat.agent.sandbox.credentials.authenticategh": false,
  "chat.agent.sandbox.allowUnsandboxedCommands": false,
  "chat.agent.sandbox.mcpServers": true,
  "chat.agent.sandbox.lspServers": true
}
```

Replace `<JDK_HOME>`, `<MAVEN_HOME>`, `<HOME>` with absolute paths. **Use absolute paths; whether `~` is expanded is not stated in the documentation.** Defaults and meanings below are from the [settings table][vsc-sandbox-settings].

- [ ] **SB-1. `chat.agent.sandbox.enabled: "on"`.** Default is `off`. Applies to terminal commands and their child processes, and (SB-8) to MCP and language servers. **Does not** cover built-in tools that do not start an OS process (file-edit tools): those "use their own permission checks" ([sandbox boundary][vsc-sandbox-boundary]), so see AP-4.
- [ ] **SB-2. `network.allowNetwork: false`.** **The default is `true`, and "turning on sandboxing does not block outbound network access by default"** ([sandbox boundary][vsc-sandbox-boundary]). With `false`, outbound access is blocked, "including for the integrated browser" ([network][vsc-sandbox-net]). Consequence: Maven must run offline (MV-1); `web_fetch`-style tools may still work because they are not terminal processes **(not in the docs: verify; see AP-5)**. Leave `allowLocalNetwork: false` unless a task needs a local service. **Whether loopback (for example a local database port) counts as "local network" is not stated.** Do **not** test this by connecting to the database; read the network section of the `/sandbox policy` report instead (VF-1). The standing rule is zero database access for agents.
- [ ] **SB-3. `fileSystem.allowDevToolAccess: false`.** Default `true` grants read of tool directories on `PATH`, toolchain directories, "developer-tool configuration and caches, **including registry tokens**, and read and write access to shared build caches" ([file system access][vsc-sandbox-fs]). For a Maven project that means `~/.m2` is writable by the agent and tokens in tool config are readable. Turning it off means you must list the JDK and Maven directories yourself (next item) and Maven may need extra paths (MV-2).
- [ ] **SB-4. `userConfiguredPaths`.** Precedence: `deniedPaths` beats `readonlyPaths` beats `readwritePaths`; arrays default to empty ([file system access][vsc-sandbox-fs]).
    - Put **no worktree** in `readwritePaths`: the working directory is granted automatically (PL-1), and listing a worktree there would let *every* session write to it.
    - **Never list the main checkout, the main `.git`, or another worktree in `readwritePaths`.** That is the whole isolation story.
    - `deniedPaths` lists secrets by location. It protects only what you remember to list; the safer property is that nothing outside the tiers is readable at all, which VF-1 must confirm.
- [ ] **SB-5. `credentials.authenticategit: false` and `credentials.authenticategh: false`.** Default `true` "provides Git authentication to sandboxed processes" and GitHub CLI authentication ([managed servers and credentials][vsc-sandbox-creds]). Agents have no reason to push or call GitHub ([policy](#1-policy-the-three-tiers-pl)).
- [ ] **SB-6. `allowUnsandboxedCommands: false`. DECISION for ECD (Q-AW-10).** The default `true` lets the agent ask to run a command outside the sandbox; approving "the current session" means "subsequent terminal commands in that session also run without those restrictions until you turn sandboxing back on" ([approval and fallback][vsc-sandbox-fallback]). With `false`, "**Allow Outside Sandbox** is not offered, and requests to run outside the sandbox fail instead of prompting." The August note recommended `true`; this page recommends `false` because a one-click session-wide bypass defeats every other item. The cost: a command that cannot run in the sandbox simply fails, and you run it yourself.
- [ ] **SB-7. Per-session toggle.** In the **Permissions** picker, "**Sandboxing for terminal**" turns sandboxing on or off *for the current session only*, without touching settings ([session control][vsc-sandbox-session]). Treat a session with sandboxing off as **unsandboxed**; check it as part of the pre-flight (OP-2). An organization-managed policy can lock it; you are not in that situation.
- [ ] **SB-8. `mcpServers: true`, `lspServers: true`.** Default `true`: sandbox MCP and language servers "started or managed for the session" ([managed servers][vsc-sandbox-creds]). This *replaces* the August note's claim that MCP is not sandboxed. Keep both on. The Java language server must still work; if it does not (VF-5), fix by adding read-only paths, not by turning this off.
- [ ] **Verify SB-1 to SB-8:** VF-1 to VF-5.

---

## 4. Stale settings from the August note (ST)

The August note used key names that VS Code has since renamed or deprecated. The current documentation says:

- `chat.agent.sandbox.allowNetwork` "migrates to `chat.agent.sandbox.network.allowNetwork`".
- `chat.agent.sandbox.retryWithAllowNetworkRequests` is deprecated and applies only to the Local harness terminal tool.
- `chat.agent.sandbox.fileSystem.mac` / `.linux` are deprecated, and "**the Copilot harness's default tools ignore them**" ([Local harness and custom terminal tools][vsc-sandbox-local]).

The third point is the dangerous one: if your `settings.json` still has `fileSystem.linux.allowWrite` / `denyRead` from the August note, **a Copilot-harness session ignores them**, and you would believe a read-deny exists that does not.

- [ ] **ST-1. Find the old keys.** Open **Preferences: Open User Settings (JSON)** from the Command Palette and search for `sandbox`, `networkFilter`, `allowedNetworkDomains`. Remove or migrate old keys to SB's names. **Risk:** 🔵 READ (you are only searching).
- [ ] **ST-2. Or from a shell** (ECD only). The settings file location is not given in the docs; use the path the Command Palette command above opens, shown as `<user-settings.json>`:

    ```bash
    grep -n -E 'chat\.agent\.(sandbox\.(allowNetwork|retryWithAllowNetworkRequests|fileSystem\.(linux|mac))|networkFilter|allowedNetworkDomains|deniedNetworkDomains)' <user-settings.json>
    ```

    - **Risk:** 🔵 READ. **Flags:** `-n` prefixes line numbers; `-E` extended regex ([grep][grep-man]). No match means no old key.
    - **Note:** `chat.agent.networkFilter`, `allowedNetworkDomains`, `deniedNetworkDomains` are still documented, for the **integrated browser** ("restart VS Code after you change" them) ([approvals: sandbox agent commands][vsc-approvals-sandbox]). They are separate from the terminal sandbox: do not delete them blindly.
- [ ] **ST-3. Workspace settings must not be able to weaken the sandbox. (not in the docs: verify in rehearsal).** The documentation says settings "are resolved on that machine" ([turn on sandboxing][vsc-sandbox-on]) but does not say whether a workspace `.vscode/settings.json` can override them. The agent can write inside its worktree, including `.vscode/`. Test in a scratch folder under `/tmp`: set `"chat.agent.sandbox.enabled": "off"` in that folder's `.vscode/settings.json`, open it, start a new session, and read the `/sandbox policy` report. If the report says sandboxing is off, **a worktree agent can switch off its own sandbox by editing its workspace settings**; then keep the sandbox settings in a place agents cannot write and make AP-4 mandatory.
- [ ] **ST-4. Settings Sync, profiles, and remote hosts.** A synced or profile-specific value can differ from what you edited. Confirm with VF-1, which reads the effective policy for the session, not the file.

---

## 5. Prove it: verification (VF)

- [ ] **VF-1. `/sandbox policy`.** In a Copilot-harness session type `/sandbox policy`. It opens a Markdown report of "the effective permissions, including runtime defaults and organization-managed restrictions" and works "to verify whether sandboxing is active or investigate why a process is blocked." **It is not available in Local harness sessions.** Run it again after any change, and start a *new* session to see defaults for new sessions ([inspect policy][vsc-sandbox-policy]). **Risk:** 🔵 READ. Read it for: sandbox on, network off, the exact read-only and read-write lists, whether `/tmp` is writable, and whether anything under your home directory is readable that is not on your read-only list.
- [ ] **VF-2. Negative tests, from a throwaway session in a scratch worktree** (ECD-initiated; the agent is asked to *try* each and report). Every one should **fail**:
    - write a file in the main checkout;
    - write a file in a different worktree;
    - read `<HOME>/.ssh`;
    - reach any network host (`curl` is the agent's choice; do not test the database);
    - `git add -N somefile` inside its worktree (PL-1's inference);
    - `sudo true`.
  A control that has never been seen to block anything has not been tested. **Risk:** 🟡 low, scratch worktree only; ask the agent to attempt each and stop on the first success, and treat a success as a finding.
- [ ] **VF-3. Positive tests.** The agent can: read and edit files in its worktree; run `git status`, `git diff` there; write to `/tmp`. If `git status` complains about a lock or permission on `.git/worktrees/<id>/`, use `git --no-optional-locks status` ([git `--no-optional-locks` L201][g-no-opt]; [card O2](/dev/subsystems/agent-workflow/worktree-command-cards#o2-git-status-and-optional-locks)). **(not in the docs: whether read-only git commands work when the git directory is not writable; verify.)**
- [ ] **VF-4. The "git writes fail" inference.** See VF-2. If `git add -N` **succeeds** from the agent's shell, the sandbox is not keeping `.git` read-only and PL-1's inference is wrong for your setup; go to GX-1.
- [ ] **VF-5. Java works inside the sandbox.** From the agent shell in a scratch worktree, `mvn -o clean package -DskipTests` must succeed (MV-1), and the Java language server in that window must start. If not, add the missing **read-only** path to `readonlyPaths`, then re-run VF-1. Do not widen to read-write.

---

## 6. Permissions and approvals (AP)

Sandboxing and approvals are separate layers ([sandbox boundary][vsc-sandbox-boundary]); "the sandbox keeps restricting even under **Allow all**" ([permission levels][vsc-approvals-levels]). Approvals decide whether something *asks*; they never replace the sandbox.

- [ ] **AP-1. Permission level: Manual permissions.** It is the default and "uses your tool, URL, and terminal approval settings." **Assisted permissions** is an LLM judge ("can make mistakes", folder isolation only); **Allow all** runs everything unprompted ([permission levels][vsc-approvals-levels]). Verify in the Permissions picker at the start of every session.
- [ ] **AP-2. `chat.tools.global.autoApprove` stays off.** It "auto-approve[s] tools across all workspaces" ([allow all globally][vsc-approvals-global]).
- [ ] **AP-3. Know the session-level bypass commands.** `/yolo` and `/autoApprove` bypass approvals for the current session; `/disableYolo` and `/disableAutoApprove` restore the default ([allow all globally][vsc-approvals-global]). You type them; an agent session should not. Autopilot is an agent mode in the Copilot harness that "auto-approves all tools, like Allow all" ([how Autopilot works][vsc-approvals-levels]). Do not use Autopilot for these sessions.
- [ ] **AP-4. Require approval for sensitive edits.** The sandbox does not cover the built-in edit tools ([sandbox boundary][vsc-sandbox-boundary]), so use `chat.tools.edits.autoApprove` with globs: `false` requires a diff and your approval before the edit is saved ([sensitive edits][vsc-edits]). Proposed (UNTESTED):

    ```jsonc
    "chat.tools.edits.autoApprove": {
      "**/*": true,
      "**/.git": false,
      "**/.gitignore": false,
      "**/.gitattributes": false,
      "**/.vscode/**": false,
      "**/.github/hooks/**": false,
      "**/.github/copilot/**": false,
      "**/.claude/**": false,
      "**/.env": false
    }
    ```

    - **Why each:** a worktree's `.git` is a *file* pointing at the real git directory; repointing it makes your next git command in that folder operate on a different repository (GX-2). `.gitignore` can hide new files from `git status` and from [R1](/dev/subsystems/agent-workflow/worktree-command-cards#r1-what-did-the-agent-create-that-git-diff-cannot-show), defeating review. `.gitattributes` changes merge and diff behavior ([C6](/dev/subsystems/agent-workflow/worktree-command-cards#c6-keep-the-worklog-mergeable-across-worktrees-decision-needed)). `.vscode`, `.github/hooks`, `.github/copilot` and `.claude` can carry settings, tasks or hooks that execute (see GX-3). Glob semantics beyond the documented example are **(not in the docs: verify with a scratch edit)**.
    - **Limit:** Worktree sessions started from the Agents window use **Allow all** ([permission levels][vsc-approvals-levels]); there, these prompts do not appear and only the Step 9 diff review catches such edits (WS-1).
- [ ] **AP-5. Terminal auto-approve: allow only fixed read-only git commands.** Terminal auto-approval "is a best-effort convenience, not a security boundary"; detection can miss subcommands and obfuscated commands ([terminal approval][vsc-approvals-term]). A `false` rule "requires approval. It does not block the command." By default "common read-only commands run automatically" **(not in the docs I read: which commands are on that default list; check yours)**, which may include `git diff <any path>`. That matters because of Git's own documented behavior: `git diff` run in a working tree with at least one path **outside** the tree compares two filesystem paths *without needing `--no-index`* ([git-diff `--no-index` L34-L41][g-diff-noindex]). So an auto-approved `git diff /some/outside/file ...` is a read outside the repository. Proposed (UNTESTED):

    ```jsonc
    "chat.tools.terminal.autoApprove": {
      "/^git (--no-optional-locks )?status( -sb| --short| --porcelain)?$/": true,
      "/^git (--no-optional-locks )?diff( --stat| --cached| --cached --stat| --name-only| --name-status)?$/": true,
      "/^git log( --oneline)?( -n ?[0-9]{1,3})?$/": true,
      "/^git worktree list( --porcelain)?$/": true,
      "/^git branch -vv$/": true,
      "/^git stash list$/": true
    }
    ```

    - **Design:** each rule is anchored and accepts **no path arguments**; anything with a path or an unlisted flag asks you. The list is deliberately short.
    - **Why not allow-list plus a deny-list of dangerous flags:** the flags that make "read-only" commands do more are documented (`-c <name>=<value>` overrides configuration, [git L76][g-c]; `--exec-path`, [L110][g-exec-path]; `--git-dir`, [L139][g-git-dir]; `--work-tree`, [L158][g-work-tree]; `--output=<file>` writes a file, [diff-options L130][g-output]; `--ext-diff` and `--textconv` run external programs, [L825][g-extdiff], [L833][g-textconv]) but a deny-list for them is easy to get wrong under the documented parsing limits. An exact allow-list fails safe: unknown means "ask".
    - **`chat.tools.terminal.ignoreDefaultAutoApproveRules` (experimental)** makes VS Code "ignore the built-in rules and use only your rules", but it also drops the built-in deny rules designed against dangerous commands ([terminal approval][vsc-approvals-term]). **Decision for ECD (Q-AW-11).** Default recommendation: leave it off and rely on the sandbox for anything the built-in rules approve.
    - **Rule of thumb:** the allow-list only matters for sessions that *ask* (Manual permissions). Under Allow all, Autopilot or a worktree session nothing asks, and the sandbox is the only control.
    - **Also:** commands that run inside the sandbox are approved automatically in the Local harness ("Commands that run inside the sandbox are approved automatically, unless a command needs confirmation to run outside the sandbox") ([Local harness][vsc-sandbox-local]). In that harness the sandbox, not the prompt, is the control. **(not in the docs: whether the Copilot harness behaves the same; verify.)**
- [ ] **AP-6. `chat.tools.terminal.blockDetectedFileWrites`.** Experimental; default `outsideWorkspace` requires approval for detected writes outside the workspace, `/tmp` is exempt when session-level approval is active ([terminal approval][vsc-approvals-term]). Leave at the default; it is detection, not enforcement.
- [ ] **AP-7. Review tool approvals.** Run **Chat: Manage Tool Approval** from the Command Palette. Remove any "approve for all future invocations" you do not remember granting. Set a tool to `false` in `chat.tools.eligibleForAutoApproval` to force approval ([prevent auto-approval][vsc-approvals-prevent]). **Risk:** 🔵 READ while reviewing.
- [ ] **AP-8. URLs.** Keep `chat.tools.urls.autoApprove` empty or `false` for anything that sends data out; request approval protects against sending data to an untrusted site, response approval against prompt injection ([URL approval][vsc-approvals-urls]).

---

## 7. `.git` and the code-execution paths (GX)

**Why this section matters most.** Several Git settings name a *program* (`core.hooksPath`, `core.fsmonitor`, `core.pager`, `core.sshCommand`, `core.editor`; [config core][g-hookspath]) and hooks are programs. Anything that can write `.git/config`, `.git/hooks/`, or a worktree's `.git` file can make **your own next git command, run by you outside the sandbox, execute attacker-chosen code as you.** This is the single most valuable thing to prevent. See [card C5](/dev/subsystems/agent-workflow/worktree-command-cards#c5-hooks-for-all-worktrees-and-who-may-write-them).

- [ ] **GX-1. The main `.git/` is not writable by any agent.** It is under the main checkout, which is on the read-only list (SB-4). The August note's `allowWrite` listed whole repository roots, which put `.git/` inside the writable area; confirm yours no longer does (VF-1).
- [ ] **GX-2. Verify a worktree's `.git` file before running git there.** The agent *can* write that file (it sits in its working directory). Before **you** run any git command in the worktree (including `git status`, which can run `core.fsmonitor`), check it:

    ```bash
    cat <wt>/.git
    # expected, exactly: gitdir: <main-checkout>/.git/worktrees/<id>
    ```

    - **Risk:** 🔵 READ. **Why:** the worktree's `.git` is a regular file whose content `gitdir: <path>` tells Git where the real directory is ([git-worktree DETAILS][g-wt-details], [gitrepository-layout][g-layout]). If it points anywhere else, Git there would use a different repository and different config. The Appendix A helper `wt-verify` in the [primer](/dev/subsystems/agent-workflow/worktree-orchestration-primer) automates this. **Run it before every review session and before every merge.**
- [ ] **GX-3. Inspect other execution surfaces in the diff and the ignored files.** In every worktree you review, look for new or changed `.vscode/` (tasks, settings), `.github/hooks/*.json`, `.github/copilot/settings*.json`, `.claude/settings*.json`, `.gitattributes`, `.gitignore`. Repository-level hook files are read from `.github/hooks/*.json` and the inline `hooks` block of `.github/copilot/settings.json` and `.claude/settings.json`, and "applicable hooks from multiple sources run together" ([hook sources][vsc-hooks-src], [GitHub hooks locations][gh-hooks-loc]). **Hook configuration and scripts are executable code** ([hooks security][vsc-hooks-sec]). Because several of these can be *ignored* by `.gitignore`, `git diff` will not show them: use [R1](/dev/subsystems/agent-workflow/worktree-command-cards#r1-what-did-the-agent-create-that-git-diff-cannot-show) and look at the folders directly.
- [ ] **GX-4. Hooks directory outside the repo.** Per [card C5](/dev/subsystems/agent-workflow/worktree-command-cards#c5-hooks-for-all-worktrees-and-who-may-write-them): set `core.hooksPath` to a directory **no agent can write** (it is not on any `readwritePaths`, and not in the main checkout the agent reads), and ensure hook files are executable (non-executable hooks are ignored, [githooks][g-hooks-exec]).
- [ ] **GX-5. Baseline and compare the config.** Save a baseline once, compare weekly (OP-3):

    ```bash
    git config --show-origin --list > <audit-dir>/git-config.baseline
    sha256sum .git/hooks/* >> <audit-dir>/git-config.baseline
    ```

    - **Risk:** 🔵 READ (writes only the baseline file you name). **Flags:** `--list` prints all variables; `--show-origin` prefixes each with the file it came from ([git-config `--list` L182][g-cfg-list], [`--show-origin` L242][g-cfg-origin]). `sha256sum` prints a SHA-256 digest per file ([GNU coreutils][coreutils-sha2]).
    - `<audit-dir>` must be somewhere agents cannot write and that survives reboots. **Do not use `/tmp`**. A suggestion for the spec: `$HOME/agent-audit/`.
- [ ] **GX-6. `git worktree` operations stay with ECD.** `git worktree add/remove/move/prune/lock/repair` write the main `.git/worktrees/` directory; they are carded W1 to W6 and are in the "decline" row of the primer's approval table.

---

## 8. Worktree sessions started by VS Code (WS)

Applies only if you adopt the Agents-window **New Worktree** route (Q-AW-9). The primer's default is the manual route with **Folder** isolation.

- [ ] **WS-1. Know what changes.** "**Worktree sessions use Allow all**" and offer no manual approval prompts ([permission levels][vsc-approvals-levels]); the documentation also states a worktree "does not restrict commands, network access, or access to files outside the worktree" ([isolation][vsc-isolation]). Therefore **every control in §3 is mandatory** for that route and AP-4 and AP-5 give no protection there.
- [ ] **WS-2. The two one-click git actions.** **Commit Changes** commits all current changes to the session branch; **Merge Changes** commits any uncommitted worktree changes and merges into the session's configured base branch, and "requires the parent repository to be on the session's configured base branch" ([Delegate two tasks][vsc-delegate]). Neither is a hunk review. Do Step 9 of the primer first.
- [ ] **WS-3. Do not use `git.worktreeSymlinkFolders`.** A symlinked folder shares the original: "changes made through the symlink, including installing or removing dependencies, affect the folder in the current checkout and any other worktrees linked to it" ([symlink ignored folders][vsc-wt-symlink]). Likewise `git.worktreeIncludeFiles` copies ignored files in; "for agent worktrees, only include files that the agent can safely access" ([include files][vsc-wt-include]). Leave both unset (both are Experimental).
- [ ] **WS-4. Deleting a worktree deletes ignored files.** "Removing a worktree also removes ignored files in its folder, even when Git reports no changes" ([remove a worktree][vsc-wt-remove]). For this project that means `target/` and any local-only file. Preserve first (OP-5). This also supports the expectation in [card W5](/dev/subsystems/agent-workflow/worktree-command-cards#w5-remove-a-finished-worktree) for the plain `git worktree remove` **(not stated for the Git command itself: verify in rehearsal)**.
- [ ] **WS-5. Default isolation toggle.** Insiders' `sessions.useWorktree` is the default isolation toggle in the Agents window ([Agents window][vsc-isolation]); **(not in the docs I read: confirm the exact setting name and its stable-channel status)**. Set it deliberately so a new session does not default to the Allow-all route by accident.
- [ ] **WS-6. Dev Container sessions.** They do not support New Worktree ([Agents window][vsc-isolation]). If you ever run agents in a container, you are on the Folder route.

---

## 9. Java, Maven, and the build (MV)

- [ ] **MV-1. Offline, `package`, never `install`.** The agent's build is `mvn -o package -DskipTests`, unpiped as the project rules require. `install` would write the built artifact into the shared `~/.m2` repository where **your** builds (and deploys) would later resolve it. `-o` (`--offline`, "Work offline") is Maven's documented flag ([Maven CLI][mvn-cli]) and is required with the network off (SB-2).
- [ ] **MV-2. `~/.m2` and the sandbox.** With `allowDevToolAccess: false`, `~/.m2/repository` is read-only (SB-4). An offline build normally only reads it, but Maven can write small bookkeeping files. **(not in the docs: verify in VF-5.)** Options if it fails: (a) put `~/.m2/repository` in `readwritePaths`: **supply-chain risk**, an agent that can write a jar there poisons what *your* build later runs and deploys; (b) a per-session copy under `/tmp` with Maven's `maven.repo.local` property **(not grounded here: fetch the Maven settings reference first)**. Default: do not grant (a).
- [ ] **MV-3. Per-worktree `target/`.** Each worktree builds its own `target/` (cold). Budget the disk and the time (the primer's concurrency limit is about three writers). Not a security item; included so VF-5 is not mistaken for a sandbox fault.
- [ ] **MV-4. No tests that touch the database.** The standing rule is no database access for agents. `-DskipTests` already skips them. Keep it explicit in every dispatch prompt.

---

## 10. Shell-user transparency and logging (LG)

**The problem.** Every agent command runs as `echocdelta`. The operating system cannot say *which agent in which worktree* did something, so identity has to be **stamped** at several layers. Each layer below is independent; none is tamper-proof against a hostile agent (see LG-8).

- [ ] **LG-1. Stamp identity in the environment.** `AGENT_ID` (for example `agentA`), `AGENT_LEVEL` (the authorization level from the spec, today always `L1`), `WORKTREE_ID` (the worktree basename). **Pitfall:** exporting variables in a shell and then running `code <folder>` does **not** reach an *already running* VS Code instance, which keeps its own environment. **(not in the docs: whether and how the agent's terminal inherits a custom environment; verify.)** The test is one command in an agent session: `echo "$AGENT_ID $WORKTREE_ID"`. If it is empty, use LG-2 and LG-3, which do not depend on the environment.
- [ ] **LG-2. Attribute by working directory and session id.** Hook payloads carry `sessionId`, `timestamp`, and `cwd` for each tool call (`preToolUse` has `toolName` and `toolArgs` too) ([GitHub hooks reference, `preToolUse`][gh-hooks-ref]). Because each agent's `cwd` *is* its worktree, **`cwd` is a more reliable identity than an environment variable.** Use it as the primary key in the logs.
- [ ] **LG-3. A per-tool-call audit hook.** VS Code's own first-hook example logs only the tool name, "not its arguments or result", via a `preToolUse` command hook ([create your first hook][vsc-hooks-first]). Extend that idea to record `timestamp`, `sessionId`, `cwd`, `toolName`, and **not** `toolArgs`: arguments may hold secrets, and the documentation warns against logging "complete prompts, arguments, results, or environment variables" ([troubleshoot hooks][vsc-hooks-trouble]). Facts that shape the design:
    - **Failure semantics.** A command `preToolUse` hook is **fail-closed** on a crash or non-zero exit (it denies the tool call), but a **timeout is fail-open** ("lets the tool call proceed through the normal permission flow"), including for policy hooks ([GitHub hooks reference][gh-hooks-ref]). So a hook can *deny* but a slow or hung hook silently allows. Keep it fast; log to a local file; never call the network.
    - **Where it runs.** In the Copilot CLI, repo, user, and plugin command hooks "run inside [the sandbox], with the same access as the agent's shell commands" ([sandboxed sessions][gh-hooks-sandbox]). A hook that logs into a place the *sandbox* can write is a log the *agent* can also edit. The administrator **policy hooks** (`/etc/github-copilot/policy.d/*.json`; "On POSIX systems, policy files must be owned by root and must not be group- or world-writable") run "on the host, outside the sandbox", cannot be disabled by `disableAllHooks` ([policy hooks][gh-hooks-policy]). **(Documented for Copilot CLI only: whether the VS Code Copilot harness honors `policy.d` is not stated; verify.)** This is the strongest log location available without a second Unix user, and a design question (Q-AW-3) in the spec.
    - **Verify the hook fires.** "A file shown in the editor is not proof that its script executed": start a disposable session and confirm a line appears ([troubleshoot hooks][vsc-hooks-trouble]).
    - The same `preToolUse` hook can **deny** by returning `{"permissionDecision":"deny","permissionDecisionReason":"..."}` ([decisions and failures][vsc-hooks-dec]). A deny rule for `bash` commands matching `git (add|commit|stash|checkout|switch|merge|rebase|reset|push|worktree)` is a candidate **third layer** behind the sandbox and the approvals; it is a best-effort pattern match, not a boundary.
- [ ] **LG-4. Git's own activity log (trace2).** Per-worktree log of every Git invocation, stamped with the identity variables: [card C4](/dev/subsystems/agent-workflow/worktree-command-cards#c4-per-worktree-git-activity-log-trace2). Trace2 settings come from the *system and global* config only and the environment, so the log target must be set in the agent's environment (LG-1). Where LG-1 fails, trace2's `def_repo` field still records the worktree path in each trace.
- [ ] **LG-5. VS Code's Agent Debug Logs.** Enable **before** the work, since "capture is not retroactive": `chat.agentHost.agentDebugLog.enabled` (experimental) for Agent Host / Copilot-harness sessions; `github.copilot.chat.agentDebugLog.fileLogging.enabled` for Local-harness sessions (then reload the window) ([before you start][vsc-debug-start]). The panel (**Developer: Open Agent Debug Logs**) lists each event "with their timestamp, type, and summary", including tool-call input and output; persisted logs are stored locally; a session can be exported to an OpenTelemetry JSON file ([debug logs panel][vsc-debug-panel], [export][vsc-debug-export]). **These logs contain prompts, source code, file paths and tool I/O**, so treat the export as sensitive.
- [ ] **LG-6. Git's reference logs.** For *what moved a branch, when, and as whom*: [card A2](/dev/subsystems/agent-workflow/worktree-command-cards#a2-every-ref-move-with-time-and-identity) and [card C1](/dev/subsystems/agent-workflow/worktree-command-cards#c1-enable-per-worktree-config)/[C2](/dev/subsystems/agent-workflow/worktree-command-cards#c2-per-worktree-identity) for per-worktree identity. Remember `logs/HEAD` is per-worktree while branch and stash logs are shared.
- [ ] **LG-7. Archive before you delete.** Before tearing a worktree down ([W5](/dev/subsystems/agent-workflow/worktree-command-cards#w5-remove-a-finished-worktree)), copy its trace2 file, its hook-log lines (filter by `cwd`), and the debug-log export for that session into `<audit-dir>/<itemID>/`. `/tmp` is volatile; nothing durable should live only there.
- [ ] **LG-8. State the limit.** All of LG-1 to LG-6 are **transparency** for a cooperative agent. A process running as you can unset a variable and edit a file you let it write. The documented stronger options are: policy hooks (LG-3), and (not covered by these sources, so not grounded here) a **separate Unix user for agents** plus a kernel audit trail. That is Q-AW-3 in the spec; do not adopt it from this page.

---

## 11. Proactive management: the recurring checklist (OP)

- [ ] **OP-1. Weekly sweep, and whenever more than three worktrees exist.** Step 12 of the [primer](/dev/subsystems/agent-workflow/worktree-orchestration-primer#step-12-hygiene-sweep-weekly-or-whenever-more-than-three-worktrees-exist) and the `wt-sweep` helper: stale, locked, unreviewed, orphaned worktrees; worktrees whose branch is merged; stash entries by worktree tag.
- [ ] **OP-2. Pre-flight before every dispatch (one minute).**
    1. Worktree's `.git` file verified (GX-2).
    2. New session; permission level shows **Manual permissions** (AP-1); sandbox toggle on (SB-7).
    3. `/sandbox policy` shows network off, only the expected paths (VF-1). Keep the report with the scope card.
    4. Dispatch prompt includes the fence (paths allowed), "do not commit, merge, push, deploy, or modify external services", and the no-database rule. VS Code's own delegation guide uses the same instruction for parallel sessions ([Delegate two tasks][vsc-delegate]).
- [ ] **OP-3. Weekly integrity check.** Repeat GX-5 and diff against the baseline; `git worktree list` ([W2](/dev/subsystems/agent-workflow/worktree-command-cards#w2-list-worktrees)) against your expectations; list `.git/hooks/` and confirm `core.hooksPath` is the directory you set. **Any unexplained difference is an incident**: stop dispatching until explained.
- [ ] **OP-4. Signs of a bypass to look for** (each is a read of something that already exists):
    - the session history shows a prompt to run "outside the sandbox", or a session where sandboxing was toggled off (SB-6, SB-7);
    - `/yolo`, `/autoApprove`, Allow all, or Autopilot was used (AP-1, AP-3);
    - the agent debug log shows a tool call outside the fence in the scope card;
    - trace2 shows a Git subcommand in the *write* set ([R8](/dev/subsystems/agent-workflow/worktree-command-cards#r8-scope-check-did-the-agent-stay-inside-its-fence), [A2](/dev/subsystems/agent-workflow/worktree-command-cards#a2-every-ref-move-with-time-and-identity)) for an agent whose level is L1;
    - the main checkout's `git status` shows changes you did not make;
    - the config or hook baseline differs (OP-3).
- [ ] **OP-5. Preserve before removal.** Before `git worktree remove` or VS Code's Delete Worktree: review (Step 9), integrate or park, archive the logs (LG-7), and check `git status --ignored` for local-only files worth keeping. Never use `-f` ([W5](/dev/subsystems/agent-workflow/worktree-command-cards#w5-remove-a-finished-worktree)).
- [ ] **OP-6. If you suspect a worktree was tampered with:** stop the session; **do not run git in that folder** until GX-2 passes and GX-3 is clean; review its changes by reading files with an editor rather than running git there; take the worktree's code only via the reviewed-diff route.
- [ ] **OP-7. Re-verify this page.** The sandbox and approval features are Preview and have renamed settings before. Re-run VF-1 to VF-5 and re-read the [sandbox page][vsc-sandbox], [approvals page][vsc-approvals] and [hooks page][vsc-hooks] after any VS Code update that touches the Agents window, after enabling a new harness (Claude, Codex), and at least quarterly. Record the date and result in the codenforce worklog.

---

## 12. Open decisions this page depends on

Each is tracked as a headed question in the codenforce spec (`docs/subsystems/agent-workflow/agent-authz-worktree-logging-spec.md`), not here. Summary: Q-AW-1 (what "read-only outside" includes), Q-AW-3 (dedicated user and audit trail; policy hooks), Q-AW-9 (VS Code worktrees or manual), Q-AW-10 (`allowUnsandboxedCommands`), Q-AW-11 (`ignoreDefaultAutoApproveRules`).

---

## Sources

All fetched 2026-10-29 unless noted.

[vsc-sandbox]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing
[vsc-sandbox-boundary]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_understand-the-sandbox-boundary
[vsc-sandbox-platform]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_check-platform-availability
[vsc-sandbox-on]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_turn-on-sandboxing-where-commands-run
[vsc-sandbox-session]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_control-sandboxing-for-the-current-session
[vsc-sandbox-settings]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_sandbox-settings
[vsc-sandbox-policy]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_inspect-the-effective-sandbox-policy
[vsc-sandbox-fs]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_configure-file-system-access
[vsc-sandbox-creds]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_configure-managed-servers-and-credentials
[vsc-sandbox-net]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_configure-network-access
[vsc-sandbox-fallback]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_control-approval-and-fallback-behavior
[vsc-sandbox-install]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_install-missing-sandbox-dependencies
[vsc-sandbox-local]: https://code.visualstudio.com/docs/agents/run/agent-sandboxing#_local-harness-sessions-and-custom-terminal-tools
[vsc-approvals]: https://code.visualstudio.com/docs/agents/run/approvals
[vsc-approvals-levels]: https://code.visualstudio.com/docs/agents/run/approvals#_permission-levels
[vsc-approvals-global]: https://code.visualstudio.com/docs/agents/run/approvals#_allow-all-tools-globally
[vsc-approvals-prevent]: https://code.visualstudio.com/docs/agents/run/approvals#_prevent-tools-from-being-auto-approved
[vsc-approvals-urls]: https://code.visualstudio.com/docs/agents/run/approvals#_url-approval
[vsc-approvals-term]: https://code.visualstudio.com/docs/agents/run/approvals#_automatically-approve-terminal-commands
[vsc-approvals-sandbox]: https://code.visualstudio.com/docs/agents/run/approvals#_sandbox-agent-commands
[vsc-edits]: https://code.visualstudio.com/docs/agents/run/review-code-edits#_require-approval-before-sensitive-edits
[vsc-isolation]: https://code.visualstudio.com/docs/agents/run/agents-window#_choose-where-an-agent-makes-changes
[vsc-delegate]: https://code.visualstudio.com/docs/agents/guides/delegate-two-tasks
[vsc-wt-include]: https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees#_include-files-when-creating-a-worktree
[vsc-wt-symlink]: https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees#_symlink-ignored-folders-when-creating-a-worktree
[vsc-wt-remove]: https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees#_remove-a-worktree
[vsc-hooks]: https://code.visualstudio.com/docs/agent-customization/hooks
[vsc-hooks-src]: https://code.visualstudio.com/docs/agent-customization/hooks#_choose-a-hook-source
[vsc-hooks-first]: https://code.visualstudio.com/docs/agent-customization/hooks#_create-your-first-copilot-hook
[vsc-hooks-dec]: https://code.visualstudio.com/docs/agent-customization/hooks#_decisions-and-failures
[vsc-hooks-trouble]: https://code.visualstudio.com/docs/agent-customization/hooks#_troubleshoot-hooks
[vsc-hooks-sec]: https://code.visualstudio.com/docs/agent-customization/hooks#_security-considerations
[vsc-debug-start]: https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view#_before-you-start
[vsc-debug-panel]: https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view#_agent-debug-logs-panel
[vsc-debug-export]: https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view#_export-and-import-sessions
[gh-hooks-ref]: https://docs.github.com/en/copilot/reference/hooks-reference
[gh-hooks-loc]: https://docs.github.com/en/copilot/reference/hooks-reference#hooks-locations
[gh-hooks-policy]: https://docs.github.com/en/copilot/reference/hooks-reference#policy-hooks
[gh-hooks-sandbox]: https://docs.github.com/en/copilot/reference/hooks-reference#sandboxed-sessions
[apt-get-s]: https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html
[apt-get-y]: https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html
[grep-man]: https://www.gnu.org/software/grep/manual/grep.html
[coreutils-sha2]: https://www.gnu.org/software/coreutils/manual/html_node/sha2-utilities.html
[mvn-cli]: https://maven.apache.org/ref/current/maven-embedder/cli.html
[g-no-opt]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L201
[g-c]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L76
[g-exec-path]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L110
[g-git-dir]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L139
[g-work-tree]: https://github.com/git/git/blob/v2.43.0/Documentation/git.txt#L158
[g-output]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L130
[g-extdiff]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L825
[g-textconv]: https://github.com/git/git/blob/v2.43.0/Documentation/diff-options.txt#L833
[g-diff-noindex]: https://github.com/git/git/blob/v2.43.0/Documentation/git-diff.txt#L34
[g-hookspath]: https://github.com/git/git/blob/v2.43.0/Documentation/config/core.txt#L499
[g-cfg-list]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L182
[g-cfg-origin]: https://github.com/git/git/blob/v2.43.0/Documentation/git-config.txt#L242
[g-wt-details]: https://github.com/git/git/blob/v2.43.0/Documentation/git-worktree.txt#L343
[g-layout]: https://github.com/git/git/blob/v2.43.0/Documentation/gitrepository-layout.txt#L165
[g-hooks-exec]: https://github.com/git/git/blob/v2.43.0/Documentation/githooks.txt#L18
