---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-05
tags: [git, incidents, practice]
---

# Git Incident Simulations

> **Prev:** [Safety rules](08-safety-shared-history-force-push.md) · **Index:** [Git](README.md)

## How to practice

For each incident: **cover the answer** → draw the graph → locate HEAD and branch pointers → decide whether history is shared → pick the safest operation → then check.

<details><summary>1. Accidental <code>git reset --hard HEAD~3</code> on your feature branch</summary>

`git reflog` → find the pre-reset entry → `git reset --hard <prev-hash>` → verify with graph + status.

</details>

<details><summary>2. Commit E introduced a production bug on a shared branch</summary>

`git revert <E-hash>` — never `reset --hard` shared history.

</details>

<details><summary>3. PR with ugly history (your own branch)</summary>

`git rebase -i HEAD~N` and use squash / fixup / reword / drop.

</details>

<details><summary>4. Merge conflict on <code>MAX_RETRY</code></summary>

Pick/combine the right value, remove markers, `git add config.ts`, `git commit`.

</details>

<details><summary>5. 20 uncommitted changes made on the wrong branch</summary>

Protect the work first: `git stash` → `git switch feature/payment` → `git stash pop`, or `git switch -c feature/payment` to carry the changes.

</details>

<details><summary>6. "My commit disappeared"</summary>

`git log --all --oneline` → `git reflog` → `git show <hash>` → `git branch recovery <hash>`.

</details>

<details><summary>7. You rebased commits a teammate already pulled</summary>

Don't casually do it. If truly required, coordinate with the team and use `git push --force-with-lease`, not `--force`.

</details>

---

## Deep dive

### Incident Simulation #1 — Accidental Reset

Situation:

```text
A → B → C → D → E → F
                    ↑
             feature/dashboard
```

You accidentally run:

```bash
git reset --hard HEAD~3
```

Now:

```text
A → B → C
        ↑
     feature
```

The missing commits are not necessarily destroyed.

First:

```bash
git reflog
```

Find the previous position.

Example:

```text
abc111 HEAD@{0}: reset: moving to HEAD~3
def222 HEAD@{1}: commit: Fix scan report pagination
ghi333 HEAD@{2}: commit: Add scan report API
```

Recover:

```bash
git reset --hard def222
```

Verify:

```bash
git log --oneline --graph --decorate
git status
```

### Incident Simulation #2 — Production Hotfix

Suppose:

```text
A → B → C → D → E → F
```

`E` introduced a production bug.

If the branch is shared:

```bash
git revert <E-hash>
```

Result:

```text
A → B → C → D → E → F → R
```

`R` reverses E.

Don't casually rewrite shared production history with:

```bash
git reset --hard
```

### Incident Simulation #3 — PR With Ugly History

History:

```text
A
│
B
│
C Add dashboard
│
D fix
│
E fix again
│
F debug
│
G temporary
│
H final
```

If the feature branch is your own/unshared history:

```bash
git rebase -i HEAD~6
```

Use:

```text
pick
squash
fixup
reword
drop
```

to create a cleaner history.

### Incident Simulation #4 — Merge Conflict

Two branches modify:

```typescript
const MAX_RETRY = ...
```

Main:

```typescript
const MAX_RETRY = 10;
```

Feature:

```typescript
const MAX_RETRY = 5;
```

Git can't automatically decide.

Conflict:

```text
<<<<<<< HEAD
const MAX_RETRY = 10;
=======
const MAX_RETRY = 5;
>>>>>>> feature
```

Resolve manually.

Then:

```bash
git add config.ts
git commit
```

### Incident Simulation #5 — Wrong Branch

You accidentally make 20 changes on:

```text
development
```

but they belong on:

```text
feature/payment
```

Nothing is committed.

One solution:

```bash
git stash
git switch feature/payment
git stash pop
```

Another approach, when appropriate, is to create a new branch directly from the current state:

```bash
git switch -c feature/payment
```

Then the current uncommitted changes remain with the working tree.

The important principle:

> **Protect the uncommitted work first. Then move it to the correct branch.**

### Incident Simulation #6 — Missing Commit

Developer says:

> "My commit disappeared."

First:

```bash
git log --all --oneline
```

If it isn't visible, investigate:

```bash
git reflog
```

Search for the commit or previous HEAD position.

Once found:

```bash
git show <hash>
```

You can inspect it.

Then recover it by:

```bash
git branch recovery <hash>
```

or move the appropriate branch pointer if that is actually what you intend.

### Incident Simulation #7 — Dangerous Rebase

Original:

```text
origin/feature
        ↓
A → B → C → D
```

Someone already pulled D.

You rebase:

```bash
git rebase main
```

Your commits become:

```text
A → B → X → Y
```

Why?

Because their parent/base changed.

Then:

```bash
git push --force
```

rewrites the remote branch.

Your teammate's local history still references the old commits.

This creates divergence/confusion.

Rule:

> **Don't casually rebase commits that other developers are already using.**

If rewriting shared history is genuinely required, coordinate with the team and use:

```bash
git push --force-with-lease
```

rather than blindly using:

```bash
git push --force
```

