# BoroughForge / codeNforce Wiki Documentation Workflow

## Purpose

This workflow governs how documentation moves from code-aware drafting into the published Wiki.js documentation site.

The documentation system uses three connected components:

1. The GitLab codeNforce source repository
2. The GitHub `boroughforge-wikidocs` repository
3. The Wiki.js documentation site backed by PostgreSQL and Git sync

## Core Principle

The GitHub `boroughforge-wikidocs` repository is the canonical source for published documentation.

Wiki.js renders documentation from the GitHub repository. The Wiki.js browser editor should not be used for normal editing of published pages.

## System Roles

### GitLab Source Repository

The GitLab repository is used for code-aware drafting. LLM tools working inside the source repository may generate documentation skeletons using knowledge of the actual codebase.

GitLab CI mirrors generated draft documentation into the GitHub documentation repository.

GitLab CI owns only the generated draft area.

Recommended GitLab-owned path:

```text
drafts/gitlab-generated/
```

### GitHub Documentation Repository

The GitHub `boroughforge-wikidocs` repository is the canonical human-edited documentation repository.

Humans edit documentation by cloning this repository locally, editing in an IDE or text editor, committing, and pushing.

Published documentation should live in folders such as:

```text
dev/
sysadmin/
users/
properties/
permitting/
inspections/
cecases/
assets/
```

### Wiki.js Site

Wiki.js is the rendered documentation site.

Wiki.js imports changes from the GitHub documentation repository through Git sync.

The Wiki.js browser editor is reserved for emergency edits only. Any emergency browser edit must be pulled back into the local GitHub documentation workflow immediately.

## Standard Documentation Lifecycle

1. A code-aware LLM drafts a skeleton page in the GitLab source repository.

2. The file is placed under:

```text
drafts/gitlab-generated/
```

3. GitLab CI mirrors the generated draft into the GitHub documentation repository.

4. A human editor reviews the generated draft in a local clone of the GitHub documentation repository.

5. The human editor promotes useful content into the appropriate published documentation folder.

6. The human editor commits and pushes changes to the GitHub documentation repository.

7. Wiki.js imports the changes during its periodic Git sync.

## Editing Rules

### Generated Drafts

Files under `drafts/gitlab-generated/` may be overwritten by GitLab CI.

Do not treat generated draft files as durable human-edited documentation.

### Published Documentation

Published documentation is edited in the GitHub documentation repository.

Do not edit published pages in the Wiki.js browser UI during normal work.

### Emergency Wiki.js Edits

Emergency Wiki.js browser edits are allowed only when necessary.

After making an emergency edit in Wiki.js, immediately pull the GitHub documentation repository locally:

```bash
git pull --rebase origin main
```

The emergency edit should then become part of the normal Git documentation history.

## Conflict Avoidance Rules

GitLab CI must not mirror or overwrite the entire GitHub documentation repository.

GitLab CI may only write to explicitly owned generated-draft paths.

The CI mirror job must not use broad commands such as:

```bash
git add .
rsync --delete ./ wiki-target/
```

The CI mirror job should only add and commit known generated paths.

Recommended CI-owned path:

```text
drafts/gitlab-generated/
```

## Preferred Human Editing Flow

```bash
git clone git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
cd boroughforge-wikidocs
git pull --rebase origin main

# edit documentation

git status
git add <changed-files>
git commit -m "Update documentation"
git pull --rebase origin main
git push origin main
```

## Summary

GitLab is the code-aware drafting system.

GitHub is the canonical documentation editing repository.

Wiki.js is the rendered documentation site.

Published documentation should have one active source of truth: the GitHub documentation repository.
