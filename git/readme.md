# Git Mastery — From Fundamentals to Production Troubleshooting

> A practical guide to understanding Git through mental models, commit graphs, hands-on commands, dangerous operations, and real-world production incidents.

---

# 1. The Core Mental Model

Git becomes much easier when you stop thinking of it as a collection of commands.

Think of Git as:

> **A database of snapshots + pointers that let you navigate and manipulate history.**

The three most important concepts are:

```text
Commit
Branch
HEAD
```

---

# 2. What Is a Commit?

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

---

# 3. Git Commit Hash

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

---

# 4. Branches

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

---

# 5. HEAD

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

---

# 6. Creating and Switching Branches

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

---

# 7. The Three Git Rooms

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

---

# 8. Working Directory

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

---

# 9. Staging Area

Run:

```bash
git add src/user.service.ts
```

Now Git has staged the current version of that file.

The staging area represents:

> **What I intend to put into my next commit.**

---

# 10. Repository

When you run:

```bash
git commit -m "Update user limit"
```

the staged snapshot becomes a commit.

Now it is part of Git history.

---

# 11. `git diff`

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

---

# 12. `git diff --staged`

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

---

# 13. `git status`

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

---

# 14. Visualizing Git

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

---

# 15. Merge

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

---

# 16. Fast-Forward Merge

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

---

# 17. Rebase

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

---

# 18. Merge vs Rebase

### Merge

```text
Keep both histories
        ↓
Join them
```

### Rebase

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

---

# 19. Merge Conflicts

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

---

# 20. Resolving a Merge Conflict

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

---

# 21. `git reset`

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

---

# 22. Reset Modes

There are three important reset modes:

```bash
git reset --soft
git reset --mixed
git reset --hard
```

## Soft

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

---

# 23. Mixed Reset

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

---

# 24. Hard Reset

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

---

# 25. Reset Summary

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

---

# 26. Revert

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

---

# 27. Reset vs Revert

### Reset

```text
A → B → C → D

reset to C

A → B → C
```

Moves the branch pointer.

### Revert

```text
A → B → C → D → E
```

Creates a new commit that undoes D.

Interview answer:

> "`git reset` changes where the branch points and can rewrite local history, while `git revert` creates a new commit that reverses an earlier commit and preserves the existing history."

---

# 28. Reflog

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

---

# 29. `git log` vs `git reflog`

### `git log`

Shows the commit history reachable through your current references.

```bash
git log
```

### `git reflog`

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

---

# 30. Git Stash

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

---

# 31. Stash Apply vs Pop

### Apply

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

### Pop

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

---

# 32. Cherry-Pick

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

---

# 33. Detached HEAD

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

---

# 34. Interactive Rebase

Interactive rebase allows you to manipulate your own commit history.

Example:

```text
A → B → C → D → E → F
```

Run:

```bash
git rebase -i HEAD~4
```

Git lets you choose actions such as:

```text
pick
reword
edit
squash
fixup
drop
```

---

# 35. Interactive Rebase Actions

### pick

Keep the commit.

```text
pick abc123 Add feature
```

### reword

Keep the commit but change its message.

### edit

Pause at the commit so you can modify it.

### squash

Combine the commit with the previous commit and edit the combined message.

### fixup

Combine with the previous commit and discard the current commit's message.

### drop

Remove the commit from the rewritten history.

---

# 36. Cleaning a Messy Feature Branch

Suppose:

```text
A → B → C → D → E → F → G
```

Messages:

```text
C = Add dashboard
D = fix
E = debugging
F = fix again
G = final final
```

You want:

```text
A → B → C'
```

Use:

```bash
git rebase -i HEAD~5
```

Then squash/fixup the unnecessary commits.

Important:

> Interactive rebase is primarily useful for cleaning up your own unpublished/shared-privately feature history.

---

# 37. Remote Repositories

A local repository and remote repository are separate.

Example:

```text
Local Git Repository

        ↕
      origin
        ↕
Bitbucket
```

Usually:

```text
origin
```

is the name of the remote repository.

---

# 38. `origin`

`origin` means:

> The remote repository configured under that name.

For example:

```text
origin/development
origin/main
origin/development-dashboard-feature
```

These are remote-tracking references.

Important distinction:

```text
origin
```

is the remote.

```text
origin/development-dashboard-feature
```

is a branch reference under that remote.

Therefore:

```bash
git merge origin
```

is not the same as:

```bash
git merge origin/development-dashboard-feature
```

The latter explicitly specifies the branch.

---

# 39. Fetch

```bash
git fetch origin
```

Downloads information/commits from the remote but doesn't automatically merge them into your current branch.

Mental model:

> **Fetch = "Show me what's on the server."**

---

# 40. Pull

Conceptually:

```text
git pull
=
git fetch
+
integration
```

Integration can involve merge or rebase depending on configuration/options.

For example:

```bash
git pull origin development
```

fetches the remote branch and then tries to integrate it into your current branch.

---

# 41. Fast-Forward vs Diverged Branches

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

---

# 42. Real-World Incident: Uncommitted Changes Prevent Pull

Example:

```text
src/modules/client-dashboard/repositories/client-scan-report.repository.ts
src/modules/client-dashboard/services/client-dashboard.service.ts
```

Git says:

```text
Please commit your changes or stash them before you merge.
Aborting
```

Meaning:

> You have modifications in your working tree that Git believes could be overwritten by the integration.

Possible solutions:

### Commit

```bash
git add .
git commit -m "..."
```

### Stash

```bash
git stash
```

Then pull/switch, and later:

```bash
git stash pop
```

---

# 43. Real-World Incident: Diverging Branches

Suppose you're on:

```text
development
```

and run:

```bash
git pull origin development-dashboard-feature
```

Git fetches:

```text
origin/development-dashboard-feature
```

but discovers:

```text
             dashboard commits
            /
A → B → C
            \
             development commits
```

The histories diverged.

Git may report:

```text
Diverging branches can't be fast-forwarded
```

This means:

> Git cannot solve the integration by simply moving your current branch pointer forward.

Possible integration strategies:

```bash
git merge origin/development-dashboard-feature
```

or:

```bash
git rebase origin/development-dashboard-feature
```

depending on what you actually intend.

Always inspect first:

```bash
git status
git branch -vv
git log --oneline --graph --decorate --all
```

---

# 44. Useful Investigation Commands

When you don't understand the state of a repository:

```bash
git status
```

Then:

```bash
git branch -vv
```

Then:

```bash
git log --oneline --graph --decorate --all
```

To see commits on remote branch but not current development:

```bash
git log --oneline development..origin/development-dashboard-feature
```

To see commits on development but not the remote branch:

```bash
git log --oneline origin/development-dashboard-feature..development
```

These commands help diagnose divergence.

---

# 45. Git Danger Zone — Mental Map

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

---

# 46. Production Rule: Shared vs Private History

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

---

# 47. Force Push

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

---

# 48. `--force-with-lease`

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

---

# 49. Incident Simulation #1 — Accidental Reset

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

---

# 50. Incident Simulation #2 — Production Hotfix

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

---

# 51. Incident Simulation #3 — PR With Ugly History

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

---

# 52. Incident Simulation #4 — Merge Conflict

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

---

# 53. Incident Simulation #5 — Wrong Branch

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

---

# 54. Incident Simulation #6 — Missing Commit

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

---

# 55. Incident Simulation #7 — Dangerous Rebase

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

---

# 56. The Senior Engineer Git Decision Tree

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

---

# 57. The Most Important Git Questions

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

---

# 58. The Golden Git Mental Model

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

---

# 59. Git Mastery Philosophy

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

---

# 60. Practical Commands Cheat Sheet

## Inspect

```bash
git status
git branch
git branch -vv
git log --oneline
git log --oneline --graph --all --decorate
git show <commit>
git reflog
```

## Branch

```bash
git branch <name>
git switch <name>
git switch -c <name>
git branch -d <name>
```

## Stage / Commit

```bash
git add <file>
git add .
git diff
git diff --staged
git commit -m "message"
```

## Merge

```bash
git merge <branch>
git merge --no-ff <branch>
```

## Rebase

```bash
git rebase <branch>
git rebase -i HEAD~N
```

## Undo

```bash
git reset --soft HEAD~1
git reset --mixed HEAD~1
git reset --hard HEAD~1
git revert <commit>
```

## Stash

```bash
git stash
git stash list
git stash apply
git stash pop
git stash drop
```

## Cherry-pick

```bash
git cherry-pick <commit>
```

## Remote

```bash
git remote -v
git fetch origin
git pull
git push
git push --force-with-lease
```

---

# 61. Final Mental Test

Given:

```text
             D → E
            /
A → B → C → F → G
```

Ask yourself:

### Want to combine both histories?

```text
merge
```

### Want feature commits replayed on top of G?

```text
rebase
```

### Want to undo E without deleting history?

```text
revert
```

### Want to move your branch pointer backwards?

```text
reset
```

### Accidentally moved the pointer backwards?

```text
reflog
```

### Need to temporarily hide unfinished work?

```text
stash
```

### Need only one commit from another branch?

```text
cherry-pick
```

### Need to clean up your own commits?

```text
interactive rebase
```

---

# 62. Next Stage — Git Real-World Simulator

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
