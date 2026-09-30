---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-05
tags: [git, force-push, shared-history, production]
---

# Safety: Shared History, Force Push & the Decision Tree

> **Prev:** [Remotes](07-remotes-fetch-pull.md) · **Next:** [Incident simulations](09-incident-simulations.md)

## TL;DR

- Before rewriting history ask: **"Has someone else already based work on these commits?"**
  - No → reset / rebase / interactive rebase are fine.
  - Yes → prefer **revert** / merge.
- After rewriting, a normal push is rejected (non-fast-forward). If you must force: **`--force-with-lease`**, never blind `--force`.
- When something goes wrong: `git status` → branch? → graph? → is work committed? (no → stash) → is history shared?

## Recall questions

<details><summary>force vs force-with-lease?</summary>

`--force` overwrites the remote unconditionally. `--force-with-lease` only overwrites if the remote is still where you last saw it, protecting a teammate's newer pushes.

</details>

<details><summary>Walk the decision tree for "something went wrong".</summary>

`git status` → which branch → what does the graph show → is my work committed? No → stash/protect it. Yes → inspect log/reflog → is history shared? No → reset/rebase OK. Yes → revert/merge.

</details>

---

## Deep dive

### Git Danger Zone — Mental Map

```text
                         Git Danger Zone
                               │
              ┌────────────────┼────────────────┐
              ↓                ↓                ↓
            reset            revert           rebase
              │                │                │
       move branch pointer   new commit    rewrite history
              │
        ┌─────┼─────┐
        ↓     ↓     ↓
      soft  mixed  hard
                       │
                       ↓
                    reflog
                       │
                    recovery
```

Other powerful operations:

```text
stash
  ↓
temporarily hide work

cherry-pick
  ↓
take one specific commit

interactive rebase
  ↓
rewrite/clean your own history

detached HEAD
  ↓
work directly from a commit
```

### Production Rule: Shared vs Private History

This is one of the most important rules.

Before rewriting history ask:

> **"Has someone else already based work on these commits?"**

If NO:

```text
rebase
reset
interactive rebase
```

can often be appropriate.

If YES:

Be extremely careful.

Prefer:

```text
revert
```

when you need to undo shared history.

### Force Push

After rewriting history, Git may reject a normal push.

You might see:

```text
non-fast-forward
```

A force push can overwrite the remote branch:

```bash
git push --force
```

This is dangerous.

### `--force-with-lease`

Prefer:

```bash
git push --force-with-lease
```

when a force push is actually necessary.

The idea is:

> "Force my rewritten history, but only if the remote hasn't changed unexpectedly since I last checked."

This protects against overwriting someone else's newer remote work more effectively than a blind:

```bash
git push --force
```

Still use it carefully.

### The Senior Engineer Git Decision Tree

When something goes wrong:

```text
             Something went wrong
                      │
                      ↓
                git status
                      │
                      ↓
              What branch am I on?
                      │
                      ↓
             What does the graph show?
                      │
                      ↓
              Is my work committed?
                 /           \
               No             Yes
               │               │
             stash         inspect history
               │               │
               ↓               ↓
          protect work     log / reflog
                               │
                               ↓
                      Is history shared?
                         /          \
                       No            Yes
                       │              │
                reset/rebase      revert/merge
```

