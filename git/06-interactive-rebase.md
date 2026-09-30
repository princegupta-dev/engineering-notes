---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-05
tags: [git, interactive-rebase, squash, history-cleanup]
---

# Interactive Rebase

> **Prev:** [Stash, cherry-pick & detached HEAD](05-stash-cherry-pick-detached-head.md) · **Next:** [Remotes](07-remotes-fetch-pull.md) · **Practice:** [Incident #3](09-incident-simulations.md)

## TL;DR

- `git rebase -i HEAD~N` lets you rewrite the last N commits of **your own, unshared** branch.
- **pick** keep · **reword** change message · **edit** pause to modify · **squash** combine + edit message · **fixup** combine + discard message · **drop** remove.

## Recall questions

<details><summary>squash vs fixup?</summary>

Both fold the commit into the previous one. `squash` lets you edit the combined message; `fixup` discards this commit's message.

</details>

<details><summary>Turn "Add dashboard, fix, debugging, fix again, final final" into one commit?</summary>

`git rebase -i HEAD~5`, keep `pick` on "Add dashboard", mark the rest `fixup` (or `squash`) — only if the branch isn't shared.

</details>

---

## Deep dive

### Interactive Rebase

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

### Interactive Rebase Actions

#### pick

Keep the commit.

```text
pick abc123 Add feature
```

#### reword

Keep the commit but change its message.

#### edit

Pause at the commit so you can modify it.

#### squash

Combine the commit with the previous commit and edit the combined message.

#### fixup

Combine with the previous commit and discard the current commit's message.

#### drop

Remove the commit from the rewritten history.

### Cleaning a Messy Feature Branch

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

