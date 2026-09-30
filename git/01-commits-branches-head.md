---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [git, commit, branch, head]
---

# Commits, Branches & HEAD

> **Next:** [Working tree, staging & repo](02-working-tree-staging-repo.md) · **Index:** [Git](README.md)

## TL;DR

- Git = **a database of snapshots + pointers** to navigate and manipulate history.
- **Commit** = snapshot + parent + author + message + timestamp, identified by a **hash**.
- **Branch** = a **movable pointer** to a commit — *not* a copy of the project.
- **HEAD** = where I am: normally `HEAD → branch → commit`.

## Recall questions

<details><summary>What is a branch, really?</summary>

A movable pointer to a commit. Creating one copies nothing; committing on it moves only that pointer.

</details>

<details><summary>What does a commit contain?</summary>

Project snapshot, parent commit(s), author, message, timestamp, and its hash. Parents link commits into history.

</details>

<details><summary>What is HEAD?</summary>

The pointer to where you're working. It normally points to your current branch, which points to the current commit.

</details>

<details><summary>Create + switch to a branch (new and old syntax)?</summary>

`git switch -c feature` · older: `git checkout -b feature`

</details>

---

## Deep dive

### The Core Mental Model

Git becomes much easier when you stop thinking of it as a collection of commands.

Think of Git as:

> **A database of snapshots + pointers that let you navigate and manipulate history.**

The three most important concepts are:

```text
Commit
Branch
HEAD
```

### What Is a Commit?

A commit is a snapshot of your project at a particular point in time.

Suppose we have:

```text
A → B → C → D
```

Each commit represents a state of the project.

A commit also contains information such as:

* Project snapshot
* Parent commit
* Author
* Commit message
* Timestamp
* Commit hash

For example:

```text
A → B → C
        ↑
      HEAD
```

Commit `C` points back to `B`, which points back to `A`.

This creates the Git history.

### Git Commit Hash

Every commit has an identifier.

Example:

```text
6e876498
```

The hash identifies a particular commit.

You can see commits using:

```bash
git log --oneline
```

Example:

```text
6e876498 push
abc12345 add dashboard API
def45678 add dashboard service
```

### Branches

A branch is NOT a copy of the project.

A branch is essentially a **movable pointer to a commit**.

Suppose:

```text
A → B → C
        ↑
       main
```

`main` points to `C`.

Create a feature branch:

```bash
git branch feature
```

Now:

```text
A → B → C
        ↑
       main
       ↑
     feature
```

Both branches point to the same commit.

But if you switch to feature and commit:

```text
A → B → C → D
        ↑     ↑
       main  feature
```

The feature branch moved to `D`.

`main` remains at `C`.

### HEAD

HEAD tells Git where you are currently working.

Normally:

```text
HEAD → main → C
```

If you switch:

```bash
git switch feature
```

then:

```text
HEAD → feature → D
```

Important:

> **HEAD normally points to your current branch, and the branch points to the current commit.**

### Creating and Switching Branches

Create:

```bash
git branch feature
```

Switch:

```bash
git switch feature
```

Create + switch:

```bash
git switch -c feature
```

Older equivalent:

```bash
git checkout -b feature
```

