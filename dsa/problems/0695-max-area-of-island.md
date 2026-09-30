---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [dsa, dfs, grid, connected-components, leetcode-medium]
---

# LeetCode 695 — Max Area of Island

> **Pattern:** [Grid DFS](../graphs/02-dfs.md#dfs-on-a-grid) — *explore and compute* · **Difficulty:** Medium · **Link:** https://leetcode.com/problems/max-area-of-island/ · ✅ Solved · **Sibling:** [200 Number of Islands](0200-number-of-islands.md)

## Recognize it

"Largest / size of a connected region" → DFS that **returns** a value about the component.

## Key insight

```text
area(cell) = 1 + area(up) + area(down) + area(left) + area(right)
```

Water, out-of-bounds, and visited cells contribute `0`.

## Approach

1. Scan every cell.
2. On land, run DFS.
3. DFS returns the total area of that island.
4. Update the maximum.

## Pitfalls

- Mark the cell visited **before** recursing, or it gets counted twice.

## Complexity

- Time: O(R·C) · Space: O(R·C) call stack worst case.

## My solution

```js
// paste your accepted solution here
```
