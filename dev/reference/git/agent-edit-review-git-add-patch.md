---
title: Home-Rolled Keep/Undo: Per-Hunk Review of Agent Edits with git add -p
description: How-to for reviewing LLM agent edits hunk by hunk from the command line, using the git index as the accepted state. Replaces VS Code's per-edit Keep/Undo, removed from non-Local agent harnesses.
published: true
date: 2026-10-16T00:00:00.000Z
tags: git, how-to, agent-workflow, code-review, vscode, copilot
editor: markdown
dateCreated: 2026-10-16T00:00:00.000Z
---

# Home-Rolled Keep/Undo: Per-Hunk Review of Agent Edits

> **Quadrant:** How-to (with a short explanation section at the end).
> **Goal:** No agent edit becomes accepted state without an explicit human decision, and every rejected edit stays recoverable.
> **Verified against:** Git 2.43.0 (Ubuntu 24.04 default), bash.

VS Code's per-edit **Keep / Undo** queue now exists only in the **Local** harness. The Copilot, Claude, and Codex harnesses write agent edits straight to disk with no pending state.[^1] This brief rebuilds the same review loop on git, so it no longer depends on any editor or vendor.

---

## 1. The model in one table

| Old Keep/Undo concept | Home-rolled equivalent | Inspect with |
|---|---|---|
| Accepted state | the **index** (staging area) | `git diff --cached` |
| Pending agent edits | **working tree minus index** | `git diff` |
| Keep a change | stage the hunk (`y` in `git add -p`) | |
| Undo a change | leave it unstaged, then park it in a stash | `agent-rejected` |
| Undo the Undo | pull hunks back out of the stash | `git checkout -p stash@{N}` |

The pending set also includes edits the agent made through terminal commands, scripts, or MCP tools. The old Keep/Undo queue never tracked those.[^2]

---

## 2. One-time setup

### 2.1 Single-keystroke answers

```bash
git config --global interactive.singleKey true
```

Each `y` / `n` / `s` takes effect immediately with no Enter, which gives you the keyboard-queue feel of the old review UI.

### 2.2 Shell functions

Add to `~/.bashrc`, then run `source ~/.bashrc`:

```bash
# --- Home-rolled Keep/Undo for agent edits ---------------------------------
# Index = accepted. Working tree minus index = pending agent edits.

# Before each agent prompt: mark everything currently present as accepted.
agent-base() {
  git add -A || return
  if git diff --cached --quiet; then
    echo "baseline: index matches HEAD"
  else
    echo "baseline staged: $(git diff --cached --shortstat)"
  fi
}

# After the agent finishes: decide new files, review hunks, park rejects.
agent-review() {
  local untracked
  untracked=$(git ls-files --others --exclude-standard)
  if [ -n "$untracked" ]; then
    printf 'New files from agent; decide each whole-file first:\n%s\n' "$untracked"
    printf '  keep:   git add <file>\n  reject: git clean -i\n'
    return 1
  fi
  git add -p
  if ! git diff --quiet; then
    git stash push --keep-index -m "agent-rejected $(date +%F_%H%M%S)"
    echo "Rejected hunks parked. View with: agent-rejected"
  else
    echo "All pending hunks kept."
  fi
}

# Show exactly the hunks rejected in the latest review (or in stash N).
agent-rejected() {
  local s="stash@{${1:-0}}"
  git diff "$s^2" "$s"
}
```

---

## 3. Procedure: one agent turn

1. **Set the baseline.** In the repo root, run `agent-base`. Everything currently in the working tree, including your own hand edits, now counts as accepted.
2. **Prompt the agent** in VS Code with any harness. Wait until the turn is completely finished.[^3]
3. **Look over the size of the change** (optional): `git diff --stat`.
4. **Review.** Run `agent-review`.
   - If it lists **new files**, decide each one as a whole file. Keep it with `git add <file>`, or reject it with `git clean -i`, which asks you file by file. Then run `agent-review` again.
   - Otherwise it opens `git add -p`. Go through the hunks: `y` keeps, `n` rejects, `s` splits, `e` edits line by line (see §4).
   - Any hunks left unstaged are moved into a stash labeled `agent-rejected <timestamp>`. Your working tree then matches what you kept.
5. **Check the result:** `git diff --cached` shows exactly what you accepted, and `git diff` should be empty.
6. **Commit** the accepted turn using conventional commits on the task branch, for example `git commit -m "fix(cecase): correct notice deadline arithmetic"`. One commit per accepted turn gives you whole-turn rollback through `git revert`, and the branch merges `--no-ff` as usual.

Fast loop once you're used to it: `agent-base` → prompt → `agent-review` → `git commit`.

---

## 4. `git add -p` key reference

`git add -p` (`--patch`) walks the differences between the working tree and the index one **hunk** at a time. A hunk is a contiguous block of changed lines plus three lines of context.

| Key | Action |
|---|---|
| `y` | **Keep**: stage this hunk |
| `n` | **Reject**: leave it unstaged; it gets parked at the end |
| `s` | Split into smaller hunks (only where unchanged lines separate the changes)[^4] |
| `e` | Open the hunk in `$EDITOR` and stage exactly the lines you keep (line-level granularity) |
| `a` | Keep this hunk and every remaining hunk in this file |
| `d` | Reject this hunk and every remaining hunk in this file |
| `j` / `k` | Skip forward / back without deciding |
| `g` | Jump to a hunk by number |
| `/` | Jump to the next hunk matching a regex |
| `q` | Quit. Every undecided hunk is treated as rejected and gets parked[^5] |
| `?` | Help |

**Granularity ladder:** a whole file (`a` / `d`), then a hunk (`y` / `n`), then a sub-hunk (`s`), then individual lines (`e`).

### Editing a hunk with `e`

In the editor that opens:

- To **reject** a `+` line, delete it.
- To **keep** a line the agent removed, change its leading `-` to a space.
- Leave context lines (those starting with a space) alone.
- Save and quit. Git stages whatever remains.

---

## 5. Recovering rejected hunks ("undo the undo")

```bash
git stash list                          # find the agent-rejected entries
agent-rejected                          # view rejected hunks from the latest review
agent-rejected 2                        # ... or from stash@{2}
git checkout -p 'stash@{0}' -- <file>   # pull hunks back one at a time
git stash drop 'stash@{0}'              # discard rejects for good
```

`git checkout -p <stash> -- <file>` offers each hunk that differs between the stash and your current tree. A hunk you take with `y` is written to **both the working tree and the index**, so it comes back already kept.[^6]

---

## 6. Operating rules

1. **One writer per working tree.** Don't run two agent sessions in the same checkout, and don't hand-edit files the agent is working on during a turn.
2. **Don't review while the agent is running.** A write in the middle of a review makes your decisions apply to stale hunks.
3. **Always run `agent-base` before prompting.** Without it, the agent's changes get mixed with earlier unreviewed work, and the index no longer means "accepted."
4. **Commit only after `git diff` is empty.** That proves every pending hunk was decided.
5. **When using the Local harness, settle its Keep/Undo first,** or ignore it entirely. In Local, staging in Source Control automatically counts as Keep.[^7] Two review systems running on the same edits is a recipe for confusion.

---

## 7. In-editor alternatives using the same model

If you want to review inside an editor rather than a terminal, these keep the **index as accepted state**, so they work alongside the functions above:

- **VS Code Source Control:** the gutter change peek offers per-change stage and revert, and the commands *Git: Stage Selected Ranges* and *Git: Revert Selected Ranges* work on a selection. Bind them, plus *Go to Next Change*, in Keyboard Shortcuts (`Ctrl+K Ctrl+S`).[^8]
- **tig:** in the status view, `u` stages a hunk or line and `!` reverts it.
- **lazygit:** `space` stages a hunk or line and `d` discards it.

---

## 8. Explanation: why this exists

On **2 Oct 2026**, the VS Code team opened meta issue #339363. It states that they removed Keep and Undo for individual changes as part of a shift toward reviewing the overall result of an agent task, aimed at simplifying review in long, multi-file workflows. The issue acknowledges that this took away checkpoints for incremental, file-by-file review. The intended replacement review scopes are **per turn, per session, and per branch**.[^9] Bug reports asking for the old behavior are being closed as duplicates of that issue.[^10] VS Code 1.142 (14 Oct 2026) began rolling out the Copilot harness as the default for new sessions.[^11]

Choosing **Local** in the chat's Session Target dropdown, before sending the first message, still brings back the per-edit queue. But Microsoft's own docs recommend the Copilot harness for everyday work, and the only opt-out from the new default is an enterprise managed setting, so Local should be treated as having a limited lifespan.

The requirement was never really the Keep/Undo widget itself. It was the rule stated at the top of this page. The git index meets that rule more completely than the old widget did: it records terminal-made edits, rejections can be reversed, and it works the same in any harness, editor, or vendor.

---

## Sources

- VS Code docs, *Review and revert agent changes*: <https://code.visualstudio.com/docs/agents/run/review-code-edits>
- VS Code docs, *Choose an agent harness*: <https://code.visualstudio.com/docs/agents/run/agent-harnesses>
- VS Code 1.142 release notes: <https://code.visualstudio.com/updates/v1_142>
- microsoft/vscode #339363, *[Meta] Feedback on granular control over Copilot changes*: <https://github.com/microsoft/vscode/issues/339363>
- microsoft/vscode #330972, *Missing keep/undo UI when using Copilot*: <https://github.com/microsoft/vscode/issues/330972>
- Git documentation: `git-add(1)` (interactive mode), `git-stash(1)`, `git-checkout(1)` (`--patch`)

---

[^1]: Per the VS Code *Review and revert agent changes* page: in Copilot, Claude, and Codex harness sessions, edits are saved directly to the session folder or worktree with no pending review state. Local harness sessions, and pre-existing extension-host sessions, still mark edits as pending for Keep/Undo.

[^2]: The VS Code docs say explicitly that agents can change files through editing tools, terminal commands, scripts, and MCP tools. A `git diff` against the baseline captures all of these no matter how they were made.

[^3]: The Copilot harness can keep running in the background after the window closes. Confirm the session is idle before running `agent-review`.

[^4]: Edits close together share context lines and are merged into one hunk. In testing, changes 7 lines apart came out as a single hunk. If `s` can't split one, use `e`.

[^5]: This is why `agent-review` stashes instead of running `git restore .`: quitting early must not destroy hunks you never looked at. If you'd rather discard explicitly, run `git restore -p` after `git add -p` and confirm each discard; that path can't be undone.

[^6]: `agent-rejected` reads the stash's index parent (`^2`), so it shows only what was rejected, not what was kept. It assumes the stash at that position is an `agent-rejected` entry, so check `git stash list` if you also use stash for other things. A later `git stash pop` of a whole agent-rejected stash also works, but it can conflict if the kept hunks have been committed or edited since; `checkout -p` avoids that.

[^7]: In Local, staging a change in Source Control automatically marks any pending edits as kept, and discarding a change discards the pending edits. The two systems are linked, so when in doubt let git be the authority.

[^8]: Command names were taken from the VS Code command palette vocabulary; default keybindings were not verified for this brief and may have changed. Check the Keyboard Shortcuts editor.

[^9]: The same issue says the "changes" pill above the chat input opens a diff editor where individual lines or edits can be reverted. That is a partial, revert-only replacement, and nothing in it tracks which hunks you have already decided.

[^10]: For example, #330972 was closed as a duplicate of #339363 on 11 Oct 2026.

[^11]: The rollout is gradual and controlled server-side, which is why the change can appear on one machine without any settings change or announcement.
