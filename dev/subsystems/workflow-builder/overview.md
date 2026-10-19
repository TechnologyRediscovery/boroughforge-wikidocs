---
title: Workflow Builder — Developer Notes
description: Developer entry point for the Workflow Builder subsystem; currently indexes the owner-file (rental registry) facility briefing set
published: false
date: 2026-10-19T13:30:00.000Z
tags: subsystem:workflow-builder, audience:dev, type:overview
editor: markdown
dateCreated: 2026-08-07T00:00:00.000Z
---

# Workflow Builder — Developer Notes

See the [hub page](/system/subsystems/workflow-builder) for links to the other branches, and the
[subsystem registry](/system/subsystem-registry) entry #18 for scope notes.

🚧 **The workflow engine itself (definitions, instances, steps) is not yet documented here.** Only the
owner-file facility below is written up.

## Owner files (the rental registry grouping layer)

An **owner file** is a clerk's folder for one owner: a head person, every parcel the head owns or controls
through entities (one level), one mailing name and address, and an append-only audit log. Its membership is
**derived from the link graph on every read, never stored**. The facility lives in the `workflow` schema and
is driven from the **Rental registry manager** page.

Read these in order (they go from concepts to code):

1. [Orientation and reading guide](/dev/subsystems/workflow-builder/owner-files-orientation): the one idea,
   vocabulary, code map, lifecycle, and the rules that keep it safe to change.
2. [Postgres data model](/dev/subsystems/workflow-builder/owner-files-data-model): graph primer, the link
   tables the walk reads, the four `workflow` tables, seeds, constraints, indexes.
3. [Java class design primer](/dev/subsystems/workflow-builder/owner-files-java-class-design-primer): the Java
   mechanics behind the classes (nested classes, `static`, `final`, inheritance, lambdas, generics, enums,
   records, copying).
4. [OwnerFileDeriver vs a regular coordinator](/dev/subsystems/workflow-builder/owner-files-deriver-vs-coordinator):
   the two kinds of class in this codebase compared (`PropertyCoordinator` vs the deriver), state, threads and
   scope, and the deriver's internals as objects.
5. [Derivation theory](/dev/subsystems/workflow-builder/owner-files-derivation-theory): nodes, edges, sole
   controller, folding, one level; worked examples; `OwnerFileDeriver` dissected.
6. [Read path code](/dev/subsystems/workflow-builder/owner-files-read-path-code): seeds, derive entry
   points, and the SQL behind each bulk read.
7. [Write path code](/dev/subsystems/workflow-builder/owner-files-write-path-code): transactions, the log,
   optimistic concurrency, lock snapshots, review pipeline.
8. [Reverse lookup (badges) and scaling review](/dev/subsystems/workflow-builder/owner-files-membership-lookup):
   "is this parcel or person in a file?" and where it will and will not scale.
9. [Maintainer guide](/dev/subsystems/workflow-builder/owner-files-maintainer-guide): seed-role runbook
   (worked LOR 2203 example), troubleshooting, change recipes, practice exercises.

Staff-facing pages for the same feature are in the user branch:
[Owner Files](/users/subsystems/workflow-builder/owner-files).
