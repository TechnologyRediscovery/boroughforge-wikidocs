# VS Code Copilot Chat — Tool-Approval & Repo-Only Sandbox Hardening

**Scope:** What Copilot Chat's approval dialogs actually protect against (and don't), the real on-disk config files that control it on this machine, and a concrete "repo-only" hardened setting suite for the 4-folder workspace (`codenforce`, `boroughforge-wikidocs`, `csepp_resurrection`, `mapnforce-LSAGRANTUPDATE`).

**Verified on this machine 2026-08-19:** Ubuntu 24.04.4 LTS, VS Code with `bubblewrap 0.9.0` and `socat 1.8.0.0` already installed (`/usr/bin/bwrap`, `/usr/bin/socat`) — the two OS packages the Linux sandbox needs. No extra install step required to turn sandboxing on here.

---

## 0. Answering the actual question: yes, that reading is correct

Out of the box, Copilot's terminal tool runs commands as **your Linux user, in your real shell, with your real filesystem and network** — there is no isolation. The approval dialog is an *application-layer* gate implemented by parsing the command string with a tree-sitter grammar and checking it against an allow/deny list. That gate:

- can be turned off entirely (auto-approve everything),
- can be widened per-command via `chat.tools.terminal.autoApprove`,
- can be bypassed for an entire session by picking **Bypass Approvals** or **Autopilot** in the permissions dropdown, which **overrides your allow/deny list and approves everything**,
- and even when active, is documented by Microsoft as having known bypasses (shell quote-concatenation, aliases, grammars that don't recognize zsh/fish sub-commands).

So the dialog is real (it does stop naive cases, and it's the only thing enabled by default), but it is a **courtesy/convenience layer, not a containment boundary**. The only thing VS Code ships today that is an actual OS-enforced boundary is the **agent sandbox** (preview): Seatbelt on macOS, bubblewrap + socat namespace isolation on Linux. Everything in §3 below is built around that distinction — the auto-approve list reduces click-fatigue for genuinely safe read-only commands, and the **sandbox** is what actually makes "repo-only" true.

---

## 1. Real config-file access pathways on this machine

| What | Path / Command |
|---|---|
| **User settings.json** (global, applies to every window/workspace) | `~/.config/Code/User/settings.json` — confirmed to already contain `chat.tools.terminal.autoApprove`, `chat.tools.urls.autoApprove`, `chat.agent.maxRequests` entries (see §2). Open via Command Palette → `Preferences: Open User Settings (JSON)`. |
| **Workspace-scoped settings** | None currently exist. There is no `.vscode/settings.json` in any of the 4 folders, and this multi-root session is **not** backed by a saved `.code-workspace` file (the only one found, `~/.config/Code/User/agent-sessions.code-workspace`, has an empty `folders` array — it's unused). To scope settings to *only* this 4-folder combo rather than globally, use **File → Save Workspace As…** to create a `.code-workspace` file with a `"settings"` block — see §3 note. |
| **Per-folder override** | `<folder>/.vscode/settings.json` inside any one of the 4 repos — takes precedence over user settings when that folder is focused, but does **not** cover the other 3 folders. Not recommended here since the goal spans all 4. |
| **Tool-level approval picker** | Command Palette → `Chat: Manage Tool Approval` — Quick Pick listing every tool (built-in, MCP, extension) with its current pre-approval/post-approval state. This is where you'd find the exact key for `chat.tools.eligibleForAutoApproval` if you want to hard-lock a specific tool to "always ask." |
| **Clear session-granted approvals** | Command Palette → `Chat: Reset Tool Confirmations`. |
| **Session permission level** | Dropdown in the chat input box itself (not a file) — must stay on **Default Approvals**. `Bypass Approvals`/`Autopilot`/`Assisted permissions` all short-circuit the file-based rules below. `chat.permissions.default` sets what new sessions start on. |
| **Agent debug log** (already on here) | `github.copilot.chat.agentDebugLog.enabled` / `...fileLogging.enabled` — both already `true` in this settings.json; useful for auditing what actually ran, via `/troubleshoot` or the Chat Debug view. |

---

## 2. Confirmed current state (before hardening)

Actual relevant contents of `~/.config/Code/User/settings.json` today:

```jsonc
"chat.tools.terminal.autoApprove": {
    "mvn compile": true
},
"chat.tools.urls.autoApprove": {
    "https://code.visualstudio.com": true,
    "https://github.com/microsoft/vscode/wiki/*": true,
    "https://resend.com": true,
    "https://jakarta.ee": true,
    "https://en.wikipedia.org": true,
    "https://*.wikipedia.org": true,
    "https://central.sonatype.com": { "approveRequest": true, "approveResponse": false }
    // (a few more jakarta.ee/wikipedia sub-paths, trimmed for brevity)
},
"chat.agent.maxRequests": 190
```

No sandbox settings exist yet — `chat.agent.sandbox.enabled` is unset, which defaults to `"off"`. This is the "full user-permission access" state described in §0.

---

## 3. Proposed repo-only hardened setting suite

Merge this into `~/.config/Code/User/settings.json` (keep the existing `mvn compile` and URL entries — just add keys/merge objects, don't replace the file). If you'd rather scope this to *only* this 4-folder workspace instead of globally, save the current window as a `.code-workspace` file first (**File → Save Workspace As…**) and put the same keys under its top-level `"settings"` object instead — the sandbox `allowWrite` paths below are absolute, so they work identically either way.

```jsonc
{
  // ---- 1. Permission level: never silently bypass the rules below ----
  // Only ever raise this to Bypass Approvals/Autopilot manually, per-session,
  // when you consciously want that.
  "chat.permissions.default": "default",

  // ---- 2. OS-enforced sandbox: this is what actually makes it "repo-only" ----
  "chat.agent.sandbox.enabled": "on",
  "chat.agent.sandbox.allowNetwork": false,
  // Keep true: still requires an explicit confirmation dialog to escape the
  // sandbox (an extra approval gate), rather than commands silently failing.
  "chat.agent.sandbox.allowUnsandboxedCommands": true,
  // Don't silently retry inside the sandbox with network re-enabled either —
  // force it through the same manual elevation prompt above.
  "chat.agent.sandbox.retryWithAllowNetworkRequests": false,

  "chat.agent.sandbox.fileSystem.linux": {
    "allowWrite": [
      "/home/echocdelta/pierre15Home22DEC/cnf/codenforce",
      "/home/echocdelta/pierre15Home22DEC/cnf/boroughforge-wikidocs",
      "/home/echocdelta/pierre15Home22DEC/nasxfer/scepp/csepp_resurrection",
      "/home/echocdelta/pierre15Home22DEC/cnf/mapping/wwalk_map_final/mapnforce-LSAGRANTUPDATE"
    ],
    "denyRead": [
      // Redundant with the sandbox's own $HOME-deny default, but explicit —
      // these are the paths that actually matter if that default ever changes.
      "/home/echocdelta/.ssh",
      "/home/echocdelta/.gnupg",
      "/home/echocdelta/.aws",
      "/home/echocdelta/.config/gh"
    ]
  },

  // ---- 3. Network: fully closed. Add domains here only if a real build needs them ----
  "chat.agent.networkFilter": true,
  "chat.agent.allowedNetworkDomains": [],
  "chat.agent.deniedNetworkDomains": [],

  // ---- 4. Terminal auto-approve: read-only convenience allow-list + explicit denies ----
  "chat.tools.terminal.enableAutoApprove": true,
  "chat.tools.terminal.ignoreDefaultAutoApproveRules": false,
  "chat.tools.terminal.blockDetectedFileWrites": "outsideWorkspace",
  "chat.tools.terminal.autoApprove": {
    "mvn compile": true,

    // --- git: read-only (see full table in §4) ---
    "/^git status\\b/": true,
    "/^git log\\b/": true,
    "/^git diff\\b/": true,
    "/^git show\\b/": true,
    "/^git branch$/": true,
    "/^git remote( -v)?$/": true,
    "/^git blame\\b/": true,
    "/^git rev-parse\\b/": true,
    "/^git describe\\b/": true,
    "/^git ls-files\\b/": true,
    "/^git stash list\\b/": true,
    "/^git tag$/": true,
    "/^git config --get\\b/": true,
    "/^git config -l\\b/": true,

    // --- git: anything that writes to disk, index, or a remote — always ask ---
    "/^git (push|pull|fetch|clone)\\b/": false,
    "/^git (add|commit|merge|rebase|cherry-pick|revert)\\b/": false,
    "/^git (reset|clean|checkout|restore)\\b/": false,
    "/^git (branch|tag) .*(-d|-D|--delete)\\b/": false,
    "/^git stash (push|pop|apply|drop|clear)\\b/": false,
    "/^git config --(global|local|unset)\\b/": false,
    "/^git (apply|am|submodule|worktree|gc)\\b/": false,

    // --- basic read-only shell listing (see §5) ---
    "ls": true,
    "pwd": true,
    "/^wc -l\\b/": true,
    "/^stat\\b/": true,
    "/^du -sh?\\b/": true,
    "/^grep\\b/": true,
    "/^find \\S+ -maxdepth\\b/": true,

    // --- never auto-approve, no matter what ---
    "/^ssh\\b/": false,
    "/^scp\\b/": false,
    "/^sftp\\b/": false,
    "/^rsync\\b.*(:|@)/": false,
    "/^curl\\b/": false,
    "/^wget\\b/": false,
    "/^sudo\\b/": false,
    "/^rm\\b/": false,
    "del": false
  },

  "chat.tools.urls.autoApprove": {
    "https://code.visualstudio.com": true,
    "https://github.com/microsoft/vscode/wiki/*": true,
    "https://resend.com": true,
    "https://jakarta.ee": true,
    "https://en.wikipedia.org": true,
    "https://*.wikipedia.org": true,
    "https://central.sonatype.com": { "approveRequest": true, "approveResponse": false }
  },

  "chat.agent.maxRequests": 190
}
```

**Important caveat on the terminal list above:** the `ls`/`grep`/`find` entries only skip the *approval dialog* — they do not by themselves restrict *where* those commands can look. A bare `"ls": true` still matches `ls /etc` or `ls ~/.ssh`. **The repo-only guarantee comes entirely from §3.2 (the sandbox `fileSystem.linux` block and its automatic `$HOME`-deny default), not from the auto-approve list.** With the sandbox off, treat every entry in the terminal allow-list as "no popup, not "safe" in an absolute sense.

---

## 4. Git command classification (used above)

| Category | Commands | Rule |
|---|---|---|
| Read-only (no working-tree/index/remote mutation) | `status`, `log`, `diff`, `show`, `branch` (list), `remote -v`, `blame`, `rev-parse`, `describe`, `ls-files`, `stash list`, `tag` (list), `config --get`/`-l` | auto-approve |
| Writes local working tree or index | `add`, `commit`, `reset`, `clean`, `checkout`, `restore`, `merge`, `rebase`, `cherry-pick`, `revert`, `stash push/pop/apply/drop`, `apply`, `am` | always ask |
| Deletes refs | `branch -d/-D`, `tag -d/--delete` | always ask |
| Touches a remote / network | `push`, `pull`, `fetch`, `clone` | always ask |
| Global config mutation | `config --global`, `config --local`, `config --unset` | always ask |
| Repo structure mutation | `submodule`, `worktree`, `gc` | always ask |

---

## 5. Basic shell listing commands (repo-scoped by the sandbox, not by regex)

| Command | Why it's in the allow-list | Containment mechanism |
|---|---|---|
| `ls`, `pwd` | Directory enumeration only | Sandbox limits *reads* to workspace folders + sandbox temp dir + per-command auto paths; `$HOME` denied by default |
| `find <path> -maxdepth N` | Bounded recursive listing | Same as above — path argument doesn't escape sandbox read rules |
| `grep`, `wc -l` | Text search / line counts on files already in scope | Same |
| `stat`, `du -sh` | Metadata / size only, no content exfil | Same |

None of these are given `allowRead` outside the 4 repo paths in §3, so — **with the sandbox on** — they physically cannot see `/etc`, `/root`, `~/.ssh`, or any path outside the workspace + OS temp dir, regardless of what argument the model passes. **With the sandbox off**, these entries are pure convenience and provide no boundary at all — this is the same point made in §3's caveat.

---

## 6. What this does **not** cover

- **File edit tools** (`editFiles`, `createFile`, `createDirectory`) go through VS Code's own permission system, not the terminal sandbox — they're bounded by workspace-trust/approval dialogs only, never by `chat.agent.sandbox.fileSystem.linux`.
- **Bypass Approvals / Autopilot** override every rule above for the session it's selected in. There is currently no setting that prevents a user from picking those modes — only self-discipline (or an org-level managed policy, not applicable to a personal machine).
- Sandbox is **preview** and Microsoft's own docs list known parsing bypasses (quote concatenation, unsupported shell grammars) for the *auto-approve* layer — the sandbox's OS-level enforcement (bubblewrap namespaces) is the actual backstop for those, since it doesn't rely on parsing the command at all.
- This only isolates the **terminal tool**. It does not sandbox MCP servers or extension-provided tools, which run with whatever permissions the extension host has.

---

## 7. Verification checklist (run once after applying §3)

Ask Copilot, in a throwaway chat, to attempt each of these and confirm the expected outcome:

1. `git status` → runs with **no prompt**.
2. `git push` → **prompts for approval** every time (never silently runs).
3. `ssh -T git@github.com` → **prompts**, and if approved, sandbox blocks the network unless you've explicitly retried with network access.
4. `ls /etc` or `cat ~/.ssh/config` → **fails/blocked** by the sandbox (or, if run outside the sandbox by mistake, at minimum still prompts).
5. `ls` inside one of the 4 workspace folders → succeeds with no prompt, and lists only that folder's contents.

If any of these behave differently, re-check the permission-level dropdown first (§1) — it silently overrides everything else.
