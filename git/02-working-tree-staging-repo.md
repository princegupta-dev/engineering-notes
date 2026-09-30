---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [git, staging, diff, status, log]
---

# Working Tree, Staging Area & Repository

> **Prev:** [Commits, branches & HEAD](01-commits-branches-head.md) · **Next:** [Merge, rebase & conflicts](03-merge-rebase-conflicts.md)

## TL;DR

- Three rooms: **Working tree** —`git add`→ **Staging** —`git commit`→ **Repository**.
- `git diff` = working ↔ staging · `git diff --staged` = staging ↔ last commit.
- Confused? `git status`, then `git log --oneline --graph --all --decorate`.

## Recall questions

<details><summary>What does the staging area represent?</summary>

What I intend to put into my next commit.

</details>

<details><summary><code>git diff</code> vs <code>git diff --staged</code>?</summary>

`git diff`: working tree vs staging ("what changed since I last staged?"). `--staged`: staging vs last commit ("what exactly am I about to commit?").

</details>

<details><summary>What does <code>git status</code> tell you?</summary>

Current branch, modified / staged / untracked files, merge conflicts, rebase status.

</details>

<details><summary>The one visualization command?</summary>

`git log --oneline --graph --all --decorate` — commits, branches, HEAD, divergence, merge commits.

</details>

---

## Deep dive

### The Three Git Rooms

One of the most important Git concepts is understanding the three states.

```text
┌─────────────────────┐
│   Working Tree      │
│   Your actual files │
└──────────┬──────────┘
           │
        git add
           ↓
┌─────────────────────┐
│   Staging Area       │
│   Changes selected   │
└──────────┬──────────┘
           │
       git commit
           ↓
┌─────────────────────┐
│   Repository         │
│   Committed history  │
└─────────────────────┘
```

### Working Directory

This is where you actually edit files.

Example:

```text
src/user.service.ts
```

You change:

```typescript
const limit = 10;
```

to:

```typescript
const limit = 20;
```

The change currently exists only in your working tree.

### Staging Area

Run:

```bash
git add src/user.service.ts
```

Now Git has staged the current version of that file.

The staging area represents:

> **What I intend to put into my next commit.**

### Repository

When you run:

```bash
git commit -m "Update user limit"
```

the staged snapshot becomes a commit.

Now it is part of Git history.

### `git diff`

`git diff` compares:

```text
Working Tree ↔ Staging Area
```

It answers:

> "What have I changed since the last time I staged this?"

Example:

```bash
git diff
```

### `git diff --staged`

This compares:

```text
Staging Area ↔ Last Commit
```

It answers:

> "What exactly am I about to commit?"

Command:

```bash
git diff --staged
```

Mental model:

```text
Working
   ↓ git add
Staging
   ↓ git commit
Repository
```

Therefore:

```text
git diff
        = Working ↔ Staging

git diff --staged
        = Staging ↔ Repository
```

### `git status`

One of the most useful commands:

```bash
git status
```

It tells you:

* Current branch
* Modified files
* Staged files
* Untracked files
* Merge conflicts
* Rebase status

When confused, run:

```bash
git status
```

### Visualizing Git

The most important visualization command from this course:

```bash
git log --oneline --graph --all --decorate
```

Use this constantly.

It shows:

* Commits
* Branches
* HEAD
* Branch relationships
* Divergence
* Merge commits

Example:

```text
* G (feature)
* F
| * E (main)
| * D
|/
* C
* B
* A
```

