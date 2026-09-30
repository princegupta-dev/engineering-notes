---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-05
tags: [git, remote, origin, fetch, pull, divergence]
---

# Remotes: origin, Fetch & Pull

> **Prev:** [Interactive rebase](06-interactive-rebase.md) · **Next:** [Safety: shared history & force push](08-safety-shared-history-force-push.md) · **Related:** [Fast-forward vs diverged](03-merge-rebase-conflicts.md)

## TL;DR

- `origin` = the remote's **name**. `origin/main` = a **remote-tracking branch** under it.
- **fetch** = "show me what's on the server" (no integration). **pull** = fetch + integrate (merge or rebase, per config).
- "Please commit your changes or stash them" → protect local work first (commit or stash).
- "Diverging branches can't be fast-forwarded" → both sides have unique commits; choose merge or rebase **after inspecting**.
- Diagnose: `git status` → `git branch -vv` → `git log --oneline --graph --decorate --all` → `git log A..B`.

## Recall questions

<details><summary>fetch vs pull?</summary>

`fetch` downloads remote commits/refs without touching your branch. `pull` = fetch + merge/rebase into your current branch.

</details>

<details><summary><code>git merge origin</code> vs <code>git merge origin/feature</code>?</summary>

`origin` is the remote itself; `origin/feature` is a specific remote-tracking branch. Be explicit about the branch.

</details>

<details><summary>Which commits are on origin/feature but not on development?</summary>

`git log --oneline development..origin/feature` (reverse the range for the opposite).

</details>

<details><summary>Pull says "Diverging branches can't be fast-forwarded". What now?</summary>

Inspect (`status`, `branch -vv`, graph), then deliberately `git merge origin/<branch>` or `git rebase origin/<branch>` depending on the history you want.

</details>

---

## Deep dive

### Remote Repositories

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

### `origin`

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

### Fetch

```bash
git fetch origin
```

Downloads information/commits from the remote but doesn't automatically merge them into your current branch.

Mental model:

> **Fetch = "Show me what's on the server."**

### Pull

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

### Real-World Incident: Uncommitted Changes Prevent Pull

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

#### Commit

```bash
git add .
git commit -m "..."
```

#### Stash

```bash
git stash
```

Then pull/switch, and later:

```bash
git stash pop
```

### Real-World Incident: Diverging Branches

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

### Useful Investigation Commands

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

