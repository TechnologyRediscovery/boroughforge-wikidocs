---
title: Git Tagging Quick Reference — Lightweight vs Annotated
description: Basic syntax for version tags, the mechanical difference between the two tag types, and why annotated is the correct default for release/milestone markers
published: true
date: 2026-08-31
tags: git, tagging, releases, workflow
editor: markdown
dateCreated: 2026-08-31
---

# Two Varieties

**Lightweight tag** — just a pointer to a commit, no extra metadata:
```bash
git tag v1.2.0
```

**Annotated tag** — a full object in the git database with tagger name, email, date, and message. Use this for anything release-facing:
```bash
git tag -a v1.2.0 -m "Release 1.2.0: mapping module MVP"
```

# Targeting a Specific Commit

Both forms default to tagging `HEAD`. To tag a past commit instead, append its hash:
```bash
git tag -a v1.2.0 <commit-hash> -m "message"
```

# Pushing Tags

Tags are not included in a plain `git push` — they have to be pushed explicitly:
```bash
git push origin v1.2.0        # a single tag
git push origin --tags        # all tags at once
```

# Useful Companions

```bash
git tag                       # list all tags
git tag -l "v1.*"              # filter by pattern
git show v1.2.0                # for annotated tags: tagger/date/message, then the commit
git tag -d v1.2.0              # delete locally
git push origin --delete v1.2.0   # delete on remote
```

# Why the Distinction Matters

An annotated tag is its own object (type `tag`) that points to a commit — it carries a checksum and metadata, which is why `git verify-tag` and GPG signing (`-s` in place of `-a`) only work against annotated tags. A lightweight tag is nothing more than a ref file holding a commit SHA: no object, no message, nothing to sign or verify independently.

For grant-milestone markers or release points — anywhere a durable, attributable record of *who tagged what and why* matters — annotated is the correct default. Lightweight tags are best reserved for quick, disposable local bookmarks you don't intend to push or reference later.
