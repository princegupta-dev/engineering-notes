---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [dsa, graphs, dfs, recursion, grid]
---

# DFS — Depth-First Search

> **Prev:** [Graph basics](01-graph-basics.md) · **Next:** [BFS](03-bfs.md) · **Problems:** [733 Flood Fill](../problems/0733-flood-fill.md), [695 Max Area](../problems/0695-max-area-of-island.md), [200 Islands](../problems/0200-number-of-islands.md) · **Related:** [the call stack in Node.js](../../backend/nodejs/01-runtime-and-call-stack.md)

## TL;DR

- Go **deep** → dead end → **backtrack** → try another path. Recursion or an explicit stack.
- Recursion's **call stack** is what gives you backtracking for free.
- **`visited`** prevents infinite loops on cycles; mark **before** exploring neighbors.
- Grid DFS template: **out of bounds / blocked / visited → return; mark; recurse 4 ways.**
- **In-place marking** (e.g. set land `1` → `0`) replaces a `visited` set.

## Recall questions

<details><summary>Write recursive graph DFS from memory.</summary>

```js
function dfs(graph, node, visited) {
  visited.add(node);
  for (const neighbor of graph[node]) {
    if (!visited.has(neighbor)) dfs(graph, neighbor, visited);
  }
}
```

</details>

<details><summary>Write the grid DFS template from memory.</summary>

```js
function dfs(r, c) {
  if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] === 0) return;
  grid[r][c] = 0; // mark visited
  dfs(r - 1, c); dfs(r + 1, c); dfs(r, c - 1); dfs(r, c + 1);
}
```

</details>

<details><summary>Why do we need <code>visited</code>?</summary>

Graphs can contain cycles; without it traversal revisits nodes forever or does redundant work.

</details>

<details><summary>How does recursion "backtrack"?</summary>

Each call sits on the call stack; when it returns, execution resumes in the caller's loop at the next neighbor.

</details>

<details><summary>DFS can either ___ a component or ___ it.</summary>

**Explore** (mark it — Number of Islands) or **explore and compute** something about it (return its area — Max Area of Island).

</details>

## Gotchas

- Some problems use **strings** `"1"`/`"0"`, not numbers — `grid[r][c] === 0` silently fails on `"0"`.
- Recursive grid DFS can reach **O(R·C)** stack depth → possible stack overflow on huge grids.
- Traversal order depends on neighbor order; don't assume a single "correct" DFS order.

---

## Deep dive

### Definition

DFS explores as deeply as possible along one path before backtracking to explore another path.

```text
      A
     / \
    B   C
   / \
  D   E
```

One possible order: `A → B → D → E → C` (depends on neighbor order).

### How it works

1. Start at a node.
2. Mark it visited.
3. Explore an unvisited neighbor.
4. Continue deeper.
5. When no unvisited neighbors remain, backtrack.
6. Continue until the reachable component has been explored.

### Implementation

```js
function dfs(graph, node, visited) {
  visited.add(node);

  for (const neighbor of graph[node]) {
    if (!visited.has(neighbor)) {
      dfs(graph, neighbor, visited);
    }
  }
}

const graph = {
  A: ["B", "C"],
  B: ["D", "E"],
  C: [],
  D: [],
  E: [],
};

dfs(graph, "A", new Set());
```

### Recursion

A function calling itself. The **base case** stops it:

```js
function countdown(n) {
  if (n === 0) return; // base case

  console.log(n);
  countdown(n - 1);
}
```

### The call stack

Remembers active calls and where to resume:

```text
dfs(A)
  └── dfs(B)
        └── dfs(D)
              └── return
        └── continue with next neighbor
  └── continue with next neighbor
```

This is how recursive DFS naturally backtracks.

### Why `visited`?

Graphs can contain cycles. Without tracking, traversal can revisit nodes indefinitely.

```js
if (!visited.has(neighbor)) {
  visited.add(neighbor);
  dfs(graph, neighbor, visited);
}
```

For recursive DFS, mark a node visited before exploring its neighbors.

### DFS on a grid

1. Out of bounds? → return.
2. Water, blocked, or already visited? → return.
3. Mark the cell visited.
4. Explore its four neighbors.

```js
function dfs(r, c) {
  if (
    r < 0 || r >= rows ||
    c < 0 || c >= cols ||
    grid[r][c] === 0
  ) {
    return;
  }

  grid[r][c] = 0; // Mark visited

  dfs(r - 1, c);
  dfs(r + 1, c);
  dfs(r, c - 1);
  dfs(r, c + 1);
}
```

Assumes land = numeric `1`, water = numeric `0`.

### In-place marking

Changing a land cell `1 → 0` marks it visited; future calls skip it. No separate `visited` set needed (but it mutates the input).

### Complexity

- Graph: O(V + E) time, O(V) space.
- Grid: O(R·C) time, up to O(R·C) call-stack space.
