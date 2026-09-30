---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [dsa, dfs, grid, leetcode-easy]
---

# LeetCode 733 — Flood Fill

> **Pattern:** [Grid DFS](../graphs/02-dfs.md#dfs-on-a-grid) · **Difficulty:** Easy · **Link:** https://leetcode.com/problems/flood-fill/ · ✅ Solved

## Recognize it

"Change a starting cell and every connected cell of the same color" → explore one connected component.

## Key insight

Changing the color **is** the visited mark.

## Approach

1. Store the original color.
2. If original color === new color, **return immediately** (otherwise infinite recursion — nothing changes, so nothing is ever "visited").
3. DFS from the starting pixel.
4. Recolor each matching pixel **before** exploring its neighbors.

## Pitfalls

- Forgetting step 2.

## Complexity

- Time: O(R·C) · Space: O(R·C) call stack worst case.

## My solution

```js
// paste your accepted solution here
```
