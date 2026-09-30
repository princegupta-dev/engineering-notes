---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [git, stash, cherry-pick, detached-head]
---

# Stash, Cherry-Pick & Detached HEAD

> **Prev:** [Undo](04-undo-reset-revert-reflog.md) · **Next:** [Interactive rebase](06-interactive-rebase.md)

## TL;DR

- **Stash** = temporary drawer for unfinished work. `apply` keeps the entry; `pop` removes it if applied cleanly.
- **Cherry-pick** = copy one commit's changes onto the current branch as a **new** commit (`E'`).
- **Detached HEAD** = HEAD points at a commit, not a branch. Fine for inspecting; to keep work: `git switch -c rescue-branch`.

## Recall questions

<details><summary>stash apply vs stash pop?</summary>

Both apply the stash to the working tree. `apply` keeps the stash entry; `pop` removes it if it applied successfully.

</details>

<details><summary>You need only commit E from a feature branch on main. How?</summary>

`git switch main` → `git cherry-pick <E-hash>` → creates `E'`, a new commit with E's changes.

</details>

<details><summary>What is detached HEAD and how do you keep work made there?</summary>

HEAD points directly at a commit (e.g. after `git checkout <hash>`). Save work with `git switch -c rescue-branch`.

</details>

---

## Deep dive

### Git Stash

Suppose you have unfinished work:

```text
20 modified files
```

but you need to switch branches.

Instead of committing unfinished work:

```bash
git stash
```

Your working tree becomes clean.

Later:

```bash
git stash pop
```

Your changes return.

Mental model:

> **Stash = temporary backpack/drawer for unfinished work.**

### Stash Apply vs Pop

#### Apply

```bash
git stash apply
```

Applies the stash but keeps the stash entry.

```text
stash
  ↓
working tree

stash remains
```

#### Pop

```bash
git stash pop
```

Applies the stash and attempts to remove the stash entry.

```text
stash
  ↓
working tree

stash removed if successfully applied
```

### Cherry-Pick

Cherry-pick means:

> **Take the changes from one specific commit and apply them to your current branch.**

Suppose:

```text
main:
A → B → C

feature:
A → B → D → E → F
```

You only want E.

Switch to main:

```bash
git switch main
```

Then:

```bash
git cherry-pick <E-hash>
```

Result:

```text
             D → E → F
            /
A → B → C → E'
```

`E'` is a new commit containing E's changes.

### Detached HEAD

Normally:

```text
HEAD → main → D
```

But if you checkout a specific commit:

```bash
git checkout <commit-hash>
```

you may get:

```text
HEAD → C

main → D
```

HEAD is now directly attached to a commit instead of a branch.

This is:

> **Detached HEAD**

Useful for:

* Inspecting old code
* Testing historical versions
* Debugging

If you make work there and want to keep it:

```bash
git switch -c rescue-branch
```

