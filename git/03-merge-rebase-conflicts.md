---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [git, merge, rebase, fast-forward, conflicts]
---

# Merge, Rebase & Conflicts

> **Prev:** [Working tree & staging](02-working-tree-staging-repo.md) · **Next:** [Undo: reset, revert, reflog](04-undo-reset-revert-reflog.md) · **Related:** [Interactive rebase](06-interactive-rebase.md), [Safety rules](08-safety-shared-history-force-push.md)

## TL;DR

- **Merge** = join two histories (merge commit `M`). **Rebase** = replay my commits on a new base (new hashes `D'`, `E'`).
- **Merge preserves** branching history; **rebase rewrites** it → don't rebase commits others use.
- **Fast-forward**: no divergence → just move the pointer, no merge commit.
- **Diverged**: both sides have unique commits → needs merge or rebase.
- Conflict = Git can't decide. `<<<<<<< HEAD` (current) `=======` `>>>>>>> feature` (incoming) → edit → `git add` → `git commit`.

## Recall questions

<details><summary>Why do commit hashes change after a rebase?</summary>

A commit's hash covers its parent. Rebasing gives the commits a new parent/base, so they become new commits.

</details>

<details><summary>When is a merge a fast-forward?</summary>

When the target branch has no commits the other lacks — Git just moves the pointer forward; no merge commit.

</details>

<details><summary>In conflict markers, which side is HEAD?</summary>

The top (`<<<<<<< HEAD` … `=======`) is your current branch; the bottom (… `>>>>>>> feature`) is the incoming branch.

</details>

<details><summary>Steps to resolve a merge conflict?</summary>

Open file → understand both versions → choose/combine → remove markers → `git add <file>` → `git commit`.

</details>

---

## Deep dive

### Merge

Merge means:

> **Join two histories together.**

Suppose:

```text
             D → E
            /
A → B → C
            \
             F → G
```

Merge feature into main:

```bash
git switch main
git merge feature
```

Result:

```text
             D → E
            /     \
A → B → C         M
            \     /
             F → G
```

`M` is a merge commit.

### Fast-Forward Merge

If the histories haven't diverged:

```text
A → B → C
        ↑
       main

A → B → C → D → E
              ↑
            feature
```

Then:

```bash
git merge feature
```

can simply move the `main` pointer:

```text
A → B → C → D → E
                ↑
               main
```

No merge commit is required.

This is called:

> **Fast-forward**

### Rebase

Rebase means:

> **Take my commits and replay them on top of another base.**

Before:

```text
             D → E
            /
A → B → C → F → G
```

Run:

```bash
git switch feature
git rebase main
```

After:

```text
A → B → C → F → G → D' → E'
```

`D` and `E` become new commits because their parent/base changed.

### Merge vs Rebase

#### Merge

```text
Keep both histories
        ↓
Join them
```

#### Rebase

```text
Take my commits
        ↓
Replay them
        ↓
Create new commits
```

Simple rule:

> **Merge preserves branching history. Rebase rewrites history.**

Rebase is commonly useful for cleaning up your own feature branch before integrating it.

Be careful rebasing commits that have already been shared with other developers.

### Merge Conflicts

A conflict happens when Git cannot automatically determine which version should win.

Example:

Original:

```text
PRICE=100
```

Feature:

```text
PRICE=90
```

Main:

```text
PRICE=80
```

Merge:

```bash
git merge feature
```

Git may produce:

```text
<<<<<<< HEAD
PRICE=80
=======
PRICE=90
>>>>>>> feature
```

Meaning:

```text
HEAD
 ↓
Current branch version

=======
separator

feature
 ↓
Incoming branch version
```

### Resolving a Merge Conflict

Process:

```text
1. git merge
2. Conflict occurs
3. Open conflicted file
4. Understand both versions
5. Choose or combine the correct code
6. Remove conflict markers
7. git add <file>
8. git commit
```

Example final file:

```text
PRICE=90
```

Then:

```bash
git add config.txt
git commit -m "Resolve merge conflict"
```

### Fast-Forward vs Diverged Branches

Fast-forward:

```text
A → B → C → D → E
                ↑
               main
```

Your branch can simply move forward.

Diverged:

```text
        D → E
       /
A → B → C
       \
        F → G
```

Both sides have unique commits.

Git cannot simply move one pointer forward.

It needs:

```text
merge
```

or:

```text
rebase
```

depending on the desired history.

