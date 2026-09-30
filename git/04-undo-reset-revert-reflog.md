---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-05
tags: [git, reset, revert, reflog, undo, recovery]
---

# Undo: Reset, Revert & Reflog

> **Prev:** [Merge, rebase & conflicts](03-merge-rebase-conflicts.md) · **Next:** [Stash, cherry-pick & detached HEAD](05-stash-cherry-pick-detached-head.md) · **Practice:** [Incidents #1, #2, #6](09-incident-simulations.md)

## TL;DR

- **reset** moves the branch pointer (rewrites local history). **revert** adds a new commit that undoes one (safe for shared history).
- Modes: **soft → staged · mixed (default) → unstaged · hard → gone from working tree**.
- `reset --hard` doesn't delete the commit — it makes it **unreachable** from the branch. **reflog** finds it again.
- `git log` = "what is my history?" · `git reflog` = "where was I recently?"

| Command   | Branch | Staging              | Working tree  |
| --------- | ------ | -------------------- | ------------- |
| `--soft`  | Moves  | Keeps changes staged | Keeps changes |
| `--mixed` | Moves  | Unstages changes     | Keeps changes |
| `--hard`  | Moves  | Resets               | Resets        |

## Recall questions

<details><summary>Reset vs revert — interview answer?</summary>

"`git reset` changes where the branch points and can rewrite local history, while `git revert` creates a new commit that reverses an earlier commit and preserves the existing history."

</details>

<details><summary>You ran <code>git reset --hard HEAD~3</code> by accident. Recover?</summary>

`git reflog` → find the entry before the reset (e.g. `def222 HEAD@{1}`) → `git reset --hard HEAD@{1}` (or the hash) → verify with `git log --oneline --graph --decorate` and `git status`.

</details>

<details><summary>Is a hard-reset commit "deleted"?</summary>

No — the branch no longer points to it, so it's unreachable from that branch, but it's usually recoverable via reflog.

</details>

<details><summary>Which undo for a bug in shared <code>main</code>?</summary>

`git revert <hash>` — never rewrite shared history with reset.

</details>

---

## Deep dive

### `git reset`

Reset primarily moves the current branch pointer.

Suppose:

```text
A → B → C → D
            ↑
           main
```

Run:

```bash
git reset C
```

Now:

```text
A → B → C
        ↑
       main
```

The branch pointer moved backward.

### Reset Modes

There are three important reset modes:

```bash
git reset --soft
git reset --mixed
git reset --hard
```

#### Soft

```bash
git reset --soft HEAD~1
```

Moves the branch pointer but keeps the changes staged.

```text
Commit:
A → B → C

After reset:

A → B

C's changes → STAGED
```

Mental model:

> Remove the commit, keep the changes ready to commit again.

### Mixed Reset

```bash
git reset --mixed HEAD~1
```

or:

```bash
git reset HEAD~1
```

Moves the branch pointer and unstages the changes.

```text
Repository → previous commit
Staging → previous commit
Working Tree → changes remain
```

Mental model:

> Remove the commit, keep the code, but unstage it.

### Hard Reset

```bash
git reset --hard HEAD~1
```

Moves:

* Branch pointer
* Staging area
* Working tree

to the target commit.

Mental model:

> **Make everything look exactly like that commit.**

Important:

Don't say:

> "The commit is immediately deleted."

More accurate:

> **The branch no longer points to that commit, making it unreachable from that branch. It may still be recoverable using reflog.**

### Reset Summary

| Command   | Branch | Staging              | Working Tree  |
| --------- | ------ | -------------------- | ------------- |
| `--soft`  | Moves  | Keeps changes staged | Keeps changes |
| `--mixed` | Moves  | Unstages changes     | Keeps changes |
| `--hard`  | Moves  | Resets               | Resets        |

Memory trick:

```text
soft  → staged
mixed → unstaged
hard  → gone from working tree
```

### Revert

Revert is different from reset.

Suppose:

```text
A → B → C → D
```

You want to undo D.

Run:

```bash
git revert D
```

Git creates:

```text
A → B → C → D → E
```

`E` reverses the changes introduced by D.

D still exists.

This is why revert is safer for shared history.

### Reset vs Revert

#### Reset

```text
A → B → C → D

reset to C

A → B → C
```

Moves the branch pointer.

#### Revert

```text
A → B → C → D → E
```

Creates a new commit that undoes D.

Interview answer:

> "`git reset` changes where the branch points and can rewrite local history, while `git revert` creates a new commit that reverses an earlier commit and preserves the existing history."

### Reflog

`git reflog` is Git's local record of recent movements of references such as HEAD.

Run:

```bash
git reflog
```

Example:

```text
abc111 HEAD@{0}: reset: moving to HEAD~3
def222 HEAD@{1}: commit: Fix pagination
ghi333 HEAD@{2}: commit: Add API
```

Suppose you accidentally run:

```bash
git reset --hard HEAD~3
```

You can inspect:

```bash
git reflog
```

and recover the previous position.

Example:

```bash
git reset --hard HEAD@{1}
```

or:

```bash
git reset --hard <commit-hash>
```

### `git log` vs `git reflog`

#### `git log`

Shows the commit history reachable through your current references.

```bash
git log
```

#### `git reflog`

Shows recent movements of references in your local repository.

```bash
git reflog
```

Mental model:

```text
git log
→ "What is my history?"

git reflog
→ "Where was I recently?"
```

