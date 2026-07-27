# Resolving a Compound Merge Conflict: rename/rename + add/add + content conflicts

**Context:** Merging `lsa7-workflowimpl` into a local branch during CodeNforce/BoroughForge development. What looked like a single rename/rename conflict was actually four separate, partly-entangled conflicts across the same patch-file directory, compounded by an earlier mistake of applying stale patch content onto the wrong branch.

---

## What actually happened (in order)

1. Was accidentally on a feature branch carrying an old, stale copy of workflow-related SQL patches.
2. Attempted to apply those stale changes, forgetting the current, authoritative workflow content actually lived on the incoming branch (`lsa7-workflowimpl`).
3. In the process, pasted the entire stale workflow draft's content into `dbpatch_beta86.sql`, overwriting what had been a small, unrelated, already-correct file.
4. Ran `git merge lsa7-workflowimpl` and got four conflicts at once:
   - `dbpatch_beta85.sql` — plain content conflict (cosmetic differences, comment markers from local patch application).
   - `dbpatch_beta86.sql` — **add/add**: two branches independently created a file at the same path with no common ancestor, because the accidental paste destroyed the lineage relationship that would otherwise have made this a simple modify.
   - `dbpatch_betaX_workflowDraft.sql` — **rename/rename**: this file existed at the merge base, and was moved to *two different destinations* on the two branches (`dbpatch_beta86.sql` on HEAD, `xarchive/dbpatch_betaX_workflowDraft.sql` on theirs).
   - `src/main/webapp/resources/css/style.css` — plain content conflict, unrelated to the SQL mess.
5. Discovered mid-resolution that the *actual* current workflow content lived under filenames not yet accounted for: `dbpatch_beta86_workflow.sql` (already present, uncontested, in the working tree) and `dbpatch_beta88_workflowtweaks.sql` (present only on the incoming branch, auto-merged in cleanly with no conflict because nothing on the local side contested it).

**Root cause of the confusion:** git's rename detection is a *content similarity heuristic* (default threshold ~50%), not an intent-reader. Pasting the stale draft's content into `beta86.sql` inflated its similarity to the original draft file past that threshold, so git concluded `beta86.sql` was a continuation of the draft's lineage on the HEAD side. That's what produced the rename/rename report — it was a heuristic artifact caused by the accidental paste, not a genuine disagreement between two people's intent about the same file.

---

## Core commands used, and what each one actually does

### Diagnosis

```bash
git status
```
Human-readable summary of conflict state, categorized by type (content / add-add / rename-rename). First stop, every time.

```bash
git ls-files -u
```
Lists every unresolved path with one line per **stage**: stage 1 = common ancestor, stage 2 = HEAD (ours), stage 3 = incoming branch (theirs). A resolved path has zero lines here. This was the tool that made the add/add conflict legible — `beta86.sql` had no stage-1 line, meaning no common ancestor existed, meaning the two versions were unrelated blobs colliding on a filename, not a modified rename.

```bash
git diff --cached --stat
```
Review of exactly what's staged and about to be committed. Run before every commit, not just at the end.

### Reading branch content without touching the working tree

```bash
git show <branch-or-sha>:<path>
```
Prints a file's content exactly as it exists at that ref, read-only, without checking anything out. Used repeatedly to inspect what each branch actually contained before deciding what to keep — e.g. confirming `lsa7-workflowimpl`'s `beta86.sql` was small, clean, and unrelated to the workflow draft:
```bash
git show lsa7-workflowimpl:codeconnect/database/patches/dbpatch_beta86.sql
```

### Applying the decision

Two different mechanisms were used, deliberately:

**1. Redirect to a scratch file, inspect, then move into place** (used when composing content that needed a read-back check first):
```bash
git show lsa7-workflowimpl:codeconnect/database/patches/xarchive/dbpatch_betaX_workflowDraft.sql > /tmp/check.sql
cat /tmp/check.sql          # read before trusting it
mv /tmp/check.sql codeconnect/database/patches/xarchive/dbpatch_betaX_workflowDraft.sql
git add codeconnect/database/patches/xarchive/dbpatch_betaX_workflowDraft.sql
```
`>` is a **shell** redirect, not a git operation — git has no awareness it's happening. It overwrites the destination silently and completely; there is no confirmation prompt and no diff shown. Writing to a scratch path first and inspecting before `mv`-ing into the real location turns a blind overwrite into a checked one.

**2. `git checkout --theirs <path>`** (used for "take theirs wholesale, no inspection needed" cases, e.g. `beta85.sql`):
```bash
git checkout --theirs codeconnect/database/patches/dbpatch_beta85.sql
git add codeconnect/database/patches/dbpatch_beta85.sql
```
This is the more idiomatic tool for the specific case of "one side wins outright" — it pulls the file from the correct stage directly into the working tree in one step. Caveat: it **unconditionally discards** any manual edits already made to that file's markers. Check `git diff <path>` first if there's any chance hand-editing has already started.

### Removing a stale path that shouldn't survive

```bash
git rm --cached codeconnect/database/patches/dbpatch_betaX_workflowDraft.sql
```
`--cached` removes the path from the index only, not the working tree (irrelevant here since the file wasn't present in the working tree anyway — it had been renamed away on both branches). This tells git "the disappearance of this path is intentional," clearing the leftover stage-1-only entry that would otherwise block the commit.

### Marking a manually-resolved file as resolved

```bash
git add <path>
```
**Critical distinction:** editing a file's text to remove `<<<<<<<`/`=======`/`>>>>>>>` markers and *resolving the conflict in git's eyes* are two separate operations. The working tree and the index are different data structures; git does not diff your edits to detect that you're done. `git add`, during a merge, is the explicit signal that collapses the multiple index stages for a path down to one resolved entry. An editor (VSCode included) showing a lingering `!` on a file is reading the same index state as `git ls-files -u` — not scanning file content for marker text.

**Important safety gap:** `git add` does **not** check for leftover conflict markers. It has no concept of that syntax at all — a file consisting entirely of unresolved marker soup and a properly resolved file are indistinguishable to it. Neither does `git commit`, once a file has been `add`ed (its only check is *structural* — are there unmerged stages left — not a scan of file content). The only real protection against committing literal marker text is manual, or an opt-in tool:
```bash
grep -n "<<<<<<<\|=======\|>>>>>>>\||||||||" <file>
```
(`|||||||` is the common-ancestor marker, present only under `diff3` conflict style — worth checking for too, since it's easy to miss visually.)

### Final verification before commit

```bash
git ls-files -u     # expect zero output — no unmerged stages remain anywhere
git status           # confirm no unmerged paths, review staged list
git diff --cached --stat
git commit
```

---

## Best practices going forward

1. **Never mix "am I looking at content" with "am I fixing the merge" in the same mental step.** They're genuinely different operations against different data structures (working tree vs. index). Edit content, verify with `grep` for markers, *then* `git add` as a distinct, deliberate act of telling git "resolved."

2. **`git ls-files -u` before and after every resolution action.** It's the ground truth for what's still unresolved — cheaper and more precise than trusting an editor's UI state or memory of what's been touched.

3. **Treat `>` (shell redirect) as unconditionally destructive.** No warning, no diff, no confirmation. Default to redirecting into a scratch file (`/tmp/...`), reading it, and only then `mv`-ing it into place — unless the situation is a clean "take this side wholesale" case, in which case `git checkout --ours` / `--theirs` is the more direct and equally safe tool.

4. **Don't commit a known-broken intermediate state with the intent to "clean up after."** Nothing forces a commit before conflicts are actually resolved — the index stays mutable until `git commit` runs. A commit containing content nobody actually intended is just noise in history and a hazard for anyone using `git bisect` or `git blame` later, doubly so if the branch is shared before the fixup lands.

5. **When git reports a rename/rename or add/add conflict, verify the mechanical cause before trusting the label.** Rename detection is a similarity heuristic (default ~50% threshold), not a record of actual intent — accidental content changes (like a bad paste) can manufacture a false rename relationship. `git ls-files -u` showing a missing stage-1 entry (no common ancestor) is the tell for a genuine add/add vs. a rename gone sideways.

6. **For filename-keyed migration/patch tooling specifically:** if a patch-application ledger tracks "applied" state by filename rather than content hash, silently overwriting a filename that's already been recorded as applied creates a correctness problem with no git-side warning at all. Worth checking whenever content under an existing patch filename gets replaced during a merge.

7. **When unsure what a branch actually contains, ask git directly before deciding anything:**
   ```bash
   git show <branch>:<path>
   ```
   read-only, no risk, and repeatedly the fastest way to cut through confusion about which file has which content — this is what resolved the back-and-forth over which file ("beta86", "beta88_workflowtweaks", "beta86_workflow") actually held the authoritative workflow content.

8. **Numbering/naming cleanup is a separate task from conflict resolution — don't do both at once.** Get the merge into a correct, committed state first with whatever names exist; renumber afterward as its own deliberate change, using `git log --oneline -- <dir>` to reconstruct file history if needed.
