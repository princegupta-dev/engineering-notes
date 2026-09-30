---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [dsa, dfs, grid, connected-components, leetcode-medium]
---

# LeetCode 200 — Number of Islands

> **Pattern:** [Grid DFS](../graphs/02-dfs.md#dfs-on-a-grid) — *explore & mark* · **Difficulty:** Medium · **Link:** https://leetcode.com/problems/number-of-islands/ · ✅ Solved · **Sibling:** [695 Max Area](0695-max-area-of-island.md)

## Recognize it

"Count the connected regions" → count connected components.

## Key insight

Increment the count **once per newly discovered island** (in the outer scan), **not** once per cell inside DFS.

## Approach

1. Scan every cell.
2. Unvisited land found → `count++`.
3. DFS to sink/mark the entire island.
4. Continue scanning.

## Pitfalls

- The grid uses **strings** `"1"` / `"0"` on LeetCode — compare with `"0"`, not `0`.

## vs Max Area of Island

| Problem            | What DFS does                             |
| ------------------ | ----------------------------------------- |
| Number of Islands  | Explores and marks an entire island       |
| Max Area of Island | Explores an island **and returns its area** |

## Complexity

- Time: O(R·C) · Space: O(R·C) call stack worst case.

## My solution

```js
// paste your accepted solution here
```
