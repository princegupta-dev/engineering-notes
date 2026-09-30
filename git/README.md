# Git

> Understand Git through mental models and the commit graph — not by memorizing commands.

**Core idea:** Git is *a database of snapshots + pointers that let you navigate and manipulate history.*

## Learning path

| #  | Note | One-line hook |
| -- | ---- | ------------- |
| 01 | [Commits, branches & HEAD](01-commits-branches-head.md) | branch = movable pointer; HEAD = where I am |
| 02 | [Working tree, staging & repo](02-working-tree-staging-repo.md) | three rooms; `diff` vs `diff --staged` |
| 03 | [Merge, rebase & conflicts](03-merge-rebase-conflicts.md) | join vs replay; fast-forward vs diverged |
| 04 | [Undo: reset, revert, reflog](04-undo-reset-revert-reflog.md) | move pointer vs undo commit; reflog recovers |
| 05 | [Stash, cherry-pick, detached HEAD](05-stash-cherry-pick-detached-head.md) | drawer; copy one commit; HEAD on a commit |
| 06 | [Interactive rebase](06-interactive-rebase.md) | clean your own history |
| 07 | [Remotes: origin, fetch, pull](07-remotes-fetch-pull.md) | fetch = look; pull = fetch + integrate |
| 08 | [Safety: shared history & force push](08-safety-shared-history-force-push.md) | shared? → revert; `--force-with-lease` |
| 09 | [Incident simulations](09-incident-simulations.md) | practice the decision, then the command |
| —  | [Commands cheat sheet](cheatsheet.md) | quick lookup |

## The Golden Git Mental Model

If you remember only this, remember:

```text
                    COMMIT GRAPH
                         │
                         ↓
              ┌────────────────────┐
              │ Branch = pointer    │
              │ HEAD = where I am   │
              └────────────────────┘
                         │
                         ↓
              ┌────────────────────┐
              │ Working Tree       │
              └─────────┬──────────┘
                        │ git add
                        ↓
              ┌────────────────────┐
              │ Staging Area       │
              └─────────┬──────────┘
                        │ git commit
                        ↓
              ┌────────────────────┐
              │ Repository History │
              └────────────────────┘
```

Then:

```text
merge
→ join histories

rebase
→ replay commits

reset
→ move pointer

revert
→ create undo commit

reflog
→ recover previous reference positions

stash
→ temporarily store unfinished work

cherry-pick
→ apply one specific commit

interactive rebase
→ edit/clean your history
```

## Git Mastery Philosophy

Don't memorize:

```text
"reset does X"
"rebase does Y"
"stash does Z"
```

Instead ask:

> **What is Git's graph right now?**

Then:

> **Where is HEAD?**

Then:

> **Where does my branch point?**

Then:

> **What is staged?**

Then:

> **Is the history shared?**

Once you can answer those five questions, Git becomes much more predictable.

## Final Mental Test

Given:

```text
             D → E
            /
A → B → C → F → G
```

Ask yourself:

<details><summary>Want to combine both histories?</summary>

**merge**

</details>

<details><summary>Want feature commits replayed on top of G?</summary>

**rebase**

</details>

<details><summary>Want to undo E without deleting history?</summary>

**revert**

</details>

<details><summary>Want to move your branch pointer backwards?</summary>

**reset**

</details>

<details><summary>Accidentally moved the pointer backwards?</summary>

**reflog**

</details>

<details><summary>Need to temporarily hide unfinished work?</summary>

**stash**

</details>

<details><summary>Need only one commit from another branch?</summary>

**cherry-pick**

</details>

<details><summary>Need to clean up your own commits?</summary>

**interactive rebase**

</details>

## The Most Important Git Questions

You should eventually be able to answer these without looking anything up.

### Fundamentals

1. What is Git?
2. What is a commit?
3. What is a branch?
4. What is HEAD?
5. What is the staging area?
6. What is the working tree?
7. What happens during `git add`?
8. What happens during `git commit`?

### Differences

9. `git diff` vs `git diff --staged`
10. merge vs rebase
11. reset vs revert
12. stash apply vs stash pop
13. fetch vs pull
14. force vs force-with-lease
15. log vs reflog

### Advanced

16. What happens during a rebase?
17. Why do commit hashes change after rebase?
18. What causes a merge conflict?
19. How do you recover from `reset --hard`?
20. What is detached HEAD?
21. What is cherry-pick?
22. What does interactive rebase do?
23. What is a fast-forward merge?
24. What does it mean when branches diverge?

## Next Stage — Git Real-World Simulator

The next phase is not more theory.

We will simulate real engineering incidents:

1. **Accidental `reset --hard`**
2. **Production hotfix**
3. **PR with 15 ugly commits**
4. **Merge conflict**
5. **Changes made on the wrong branch**
6. **Missing/lost commit**
7. **Dangerous rebase**
8. **Diverged local/remote branches**
9. **Cherry-pick a production fix**
10. **Recover after a bad force push**
11. **Find which commit introduced a production bug using `git bisect`**
12. **Final multi-developer Git incident**

For each incident, the goal is not to remember a command.

The goal is:

```text
Understand the situation
        ↓
Draw the Git graph
        ↓
Identify HEAD
        ↓
Identify branch pointers
        ↓
Determine whether history is shared
        ↓
Choose the safest operation
        ↓
Execute
        ↓
Verify
        ↓
Explain WHY
```

That is the difference between **knowing Git commands** and **being able to use Git as a senior engineer**.

