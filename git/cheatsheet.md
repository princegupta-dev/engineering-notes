# Git Commands Cheat Sheet

> Commands only. For *why*, follow the links in [Git](README.md).


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

