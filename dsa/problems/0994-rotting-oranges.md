---
status: learning
confidence: 2
last_reviewed: 2026-09-30
next_review: 2026-10-01
tags: [dsa, bfs, multi-source-bfs, grid, leetcode-medium]
---

# LeetCode 994 — Rotting Oranges

> **Pattern:** [Multi-source BFS, level = time](../graphs/03-bfs.md#multi-source-bfs--level--time) · **Difficulty:** Medium · **Link:** https://leetcode.com/problems/rotting-oranges/ · 🟡 In progress

`0` = empty · `1` = fresh 🍊 · `2` = rotten

Every minute, each rotten orange infects its 4-directional fresh neighbors. Return the minimum minutes until no fresh orange remains, or `-1` if impossible.

## Recognize it

"Minimum time for something to **spread** from **several starting points at once**" → multi-source BFS, one level per time unit.

## Key insight

1. **All** initially rotten oranges start spreading at the same time → put them **all** in the initial queue.
2. **One BFS level = one minute** → snapshot `size = queue.length` and process exactly that many.

## Approach (pseudocode)

```text
Count all fresh oranges
Put all initially rotten oranges in the queue
minutes = 0

While queue not empty AND fresh > 0:
    size = queue.length
    Repeat size times:
        Remove one rotten orange
        For each of its 4 neighbors:
            If fresh:
                make it rotten      (grid = 2)
                fresh--
                add it to the queue
    minutes++

Return fresh === 0 ? minutes : -1
```

## Trace

```text
2 1 1        Queue = [(0,0)]   minutes = 0   fresh = 6
1 1 0
0 1 1
```

Minute 1: `(0,0)` infects `(0,1)` and `(1,0)`:

```text
2 2 1        Queue = [(0,1), (1,0)]   ← spread during minute 2
2 1 0
0 1 1
```

## Pitfalls

- **Forgetting the `size` snapshot:** newly rotten oranges would spread in the same minute.
- **Decrement `fresh` immediately** when rotting — and change the grid at the same moment so the orange isn't enqueued twice:
  ```js
  grid[nr][nc] = 2;
  fresh--;
  queue.push([nr, nc]);
  ```
- **Loop condition includes `fresh > 0`**, otherwise you count an extra minute after the last orange rots.
- **Unreachable fresh orange** (`2 1 0 1` — the last `1` is blocked by `0`) → loop ends with `fresh > 0` → return `-1`.
- No fresh oranges at the start → return `0`.

## Complexity

- Time: O(R·C) · Space: O(R·C).

## Next step

Trace small grids by hand until you can predict each minute, then build the code piece by piece (count → enqueue sources → level loop → neighbors) instead of memorizing the full solution.

## My solution

```js
// write it from the pseudocode above, then paste the accepted version here
```
