---
title: Git reference index
description: Landing page for the git/GitLab reference docs — mental model, conventions, stashing/branch-rescue, MR review, and conflict-resolution case studies
published: true
date: 2026-08-19T00:00:00.000Z
tags: git, gitlab, development, tooling, type:index
editor: markdown
dateCreated: 2026-08-19T00:00:00.000Z
---

# Git reference index

Reference docs for git mechanics and CNF's conventions on top of them. Start with the mental
model if you want the "how it actually works" grounding; jump straight to a scenario doc if you
already know the mechanics and just need the recipe.

## Foundations

- [git-mental-model.md](/dev/reference/git/git-mental-model) — objects, refs, HEAD, reachability,
  merge outcomes, revert strategies, linked worktrees.
- [git-three-trees-recovery-primer.md](/dev/reference/git/git-three-trees-recovery-primer) — the
  working-tree/index/HEAD model, `git diff` modes, `status --short` decoding, the stash workflow,
  and SHA-1 hashing theory.

## Conventions

- [git-branch-commit-conventions.md](/dev/reference/git/git-branch-commit-conventions) — branch
  naming grammar, `--no-ff` merge policy, itemID commit citation, milestone tags, and the
  branch/history interrogation command set.

## Scenario playbooks

- [git-stash-and-branch-rescue.md](/dev/reference/git/git-stash-and-branch-rescue) — moved work
  onto the wrong branch (stash it over), can't find which branch has a file, or already committed
  to the wrong branch (cherry-pick it over).
- [git-rename-rename-add-add-conflict-resolution.md](/dev/reference/git/git-rename-rename-add-add-conflict-resolution)
  — worked case study resolving a compound rename/rename + add/add merge conflict.

## GitLab workflow

- [gitlab-mr-cli-primer.md](/dev/reference/git/gitlab-mr-cli-primer) — reviewing and merging
  GitLab MRs from the command line without the web UI, `glab` usage, two-dot vs. three-dot diffs.

This is a living index — add a line here whenever a new git reference doc is written.
