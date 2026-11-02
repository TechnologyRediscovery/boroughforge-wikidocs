---
title: Agent Workflow and Git Worktrees: Developer Notes
description: Hub for running several coding agents at once on one repository with git worktrees, a sandbox, human per-hunk review, and per-worktree logging. Four draft pages (three adopted-practice pages plus one proposed-practice page), all unpublished until rehearsed.
published: false
date: 2026-10-29T00:00:00.000Z
tags: subsystem:agent-workflow, audience:dev, type:overview, status:draft, status:has-planned-ref
editor: markdown
dateCreated: 2026-10-29T00:00:00.000Z
---

# Agent Workflow and Git Worktrees

> **Status: DRAFT, UNTESTED.** Nothing on these pages has been executed. Every Git command is grounded in the official Git 2.43.0 documentation and every sandbox and approval setting in the VS Code and GitHub Copilot documentation as fetched on 2026-10-29; both are linked from the pages themselves. Rehearse in a scratch repository first.

**Scope:** a solo Java developer who wants several coding agents working *simultaneously* on the same repository, each isolated in its own git worktree, with every change reviewed hunk by hunk by the human before it is committed and merged. Registry entry: **X7 `agent-workflow`** in the [subsystem registry](/system/subsystem-registry).

**Standing policy these pages implement:** agents are read-only outside the repository and `/tmp`; everything else is blocked. Git, the database, deploys and server administration belong to the human.

## The three pages

1. **[Worktree orchestration primer](/dev/subsystems/agent-workflow/worktree-orchestration-primer)**: the step-by-step guide. Start here. Covers the model, the hazards (the shared stash, DB patch numbers, hot files), and Steps 0-12 from a rehearsal in a scratch repo to the weekly hygiene sweep.
2. **[Worktree and review command cards](/dev/subsystems/agent-workflow/worktree-command-cards)**: one card per Git command that triggers a human review or changes state: what it does to objects, refs, index and config; every flag with a doc link; risk profile; what it touches; undo. 30 cards.
3. **[Agent sandbox configuration checklist](/dev/subsystems/agent-workflow/agent-sandbox-checklist)**: the checkable list for sandbox settings, approvals, `.git` hardening, shell-user transparency, logging and recurring checks.

## A fourth page, for a proposed (not adopted) practice

4. **[Agent simulation segment command cards](/dev/subsystems/agent-workflow/sim-segment-command-cards)**: 21 cards for a *proposed* disposable `/tmp` segment where an agent may rehearse human-style git writes (S cards), for testing whether the sandbox really blocks the network with open-source tools such as Wireshark, `strace` and `ss` (N cards), and for rehearsing signing with throwaway keys (K cards). Nothing on it is adopted; the standing rules above are unchanged. Each card says whether it runs in a plain terminal or in the sandboxed agent terminal, because a probe in the wrong one tests nothing.

## What is planned, not built

> 📅 **Planned.** Agent authorization levels (L0 read-only, L1 worktree writer, optional L2) integrated with per-worktree Git logging are specified but undecided. The spec and its open questions live in the codenforce repository under `docs/subsystems/agent-workflow/`; this page does not describe them as available.

> 📅 **Planned.** A local agent simulation segment (AW.8) and a portable, signed, encrypted carry-pack design for the borough database (PTC.0) are proposals awaiting decisions. Neither is built; the segment explicitly has no database or server of its own.

## Related, older pages

- [Git mental model](/dev/reference/git/git-mental-model): objects, refs, index, worktrees in one picture.
- [Agent edit review with `git add -p`](/dev/reference/git/agent-edit-review-git-add-patch): the single-working-tree review flow this guide extends to many worktrees.
- [Copilot sandbox hardening, August 2026](/dev/reference/vscode-copilot-sandbox-hardening-aug2026): superseded in part by the checklist; see the checklist's stale-settings section.
