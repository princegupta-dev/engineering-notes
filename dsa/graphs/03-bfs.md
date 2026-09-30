---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-01
tags: [dsa, graphs, bfs, queue, shortest-path, multi-source]
---

# BFS — Breadth-First Search

> **Prev:** [DFS](02-dfs.md) · **Problems:** [994 Rotting Oranges](../problems/0994-rotting-oranges.md) · **Compare:** [DFS vs BFS](README.md#dfs-vs-bfs)

## TL;DR

- Explore **level by level** (like a wave) using a **FIFO queue**.
- Mark visited **when enqueuing**, not when dequeuing.
- Finds **shortest paths in unweighted graphs** — nodes come out in increasing distance.
- **Multi-source BFS:** put *all* sources in the queue at the start.
- **Level-by-level:** snapshot `size = queue.length`, process exactly `size` items = one level (one step / one minute).

## Recall questions

<details><summary>Write graph BFS from memory.</summary>

```js
function bfs(graph, start) {
  const queue = [start];
  const visited = new Set([start]);
  while (queue.length > 0) {
    const node = queue.shift();
    for (const neighbor of graph[node]) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);
        queue.push(neighbor);
      }
    }
  }
}
```

</details>

<details><summary>Why a queue?</summary>

FIFO: the first-discovered node is processed first, which preserves level order.

</details>

<details><summary>Why mark visited on enqueue?</summary>

Otherwise two different nodes can both enqueue the same neighbor before it's processed → duplicates and wasted work.

</details>

<details><summary>Why does BFS find the shortest path — and when doesn't it?</summary>

It processes nodes in increasing distance, so when a node is first reached, every shorter distance has already been explored. Only for **unweighted** (equal-cost) edges.

</details>

<details><summary>What is multi-source BFS and when do you need it?</summary>

Start BFS from several nodes at once by enqueuing all of them initially — when all sources spread simultaneously (e.g. all rotten oranges).

</details>

<details><summary>Why capture <code>size = queue.length</code> before the inner loop?</summary>

Items added during this level belong to the *next* level (next minute); without the snapshot you'd process them in the same step.

</details>

## Gotchas

- `Array.shift()` is O(n) in JS — fine for learning; use a head index (`queue[head++]`) for large inputs.
- Grid distance counts **moves**, not cells: top-left → bottom-right of a 3×3 is **4 moves** (5 cells).

---

## Deep dive

### Definition

BFS explores a graph level by level, processing all nodes at the current distance before nodes further away.

```text
        A
       / \
      B   C
     / \
    D   E
```

```text
Level 0: A
Level 1: B, C
Level 2: D, E
Order:   A → B → C → D → E
```

### Why a queue?

FIFO — first in, first out. The node discovered first is processed first, which maintains level order.

```js
const queue = [];

queue.push("A");            // add to back
const node = queue.shift(); // remove from front
```

### Implementation

```js
function BFS(graph, start) {
  const queue = [];
  queue.push(start);

  const visited = new Set();
  visited.add(start);

  while (queue.length > 0) {
    const node = queue.shift();

    console.log(node);

    for (const neighbor of graph[node]) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);
        queue.push(neighbor);
      }
    }
  }
}
```

### Mark visited on enqueue

```js
visited.add(neighbor);
queue.push(neighbor);
```

Prevents two nodes from adding the same neighbor before it's processed.

### Why BFS finds the shortest path

```text
Distance 0: A
Distance 1: B, C
Distance 2: D, E, F
```

If `F` is first reached via `A → C → F` (distance 2), BFS has already explored everything at distances 0 and 1, so no shorter path exists. **Only for unweighted graphs** (or equal edge costs).

### Grid BFS and distance

```text
S . .
. . .
. . E
```

All cells walkable, 4-directional: shortest distance = **4 moves** (`right, right, down, down`) — the path visits 5 cells. BFS works because every move costs one step.

### Multi-source BFS & level = time

When several sources spread simultaneously, enqueue all of them first. Then process level by level:

```js
while (queue.length > 0) {
  const size = queue.length; // this level only
  for (let i = 0; i < size; i++) {
    const [r, c] = queue.shift();
    // visit neighbors, push new ones (they belong to the next level)
  }
  steps++;
}
```

```text
Process the current level
        ↓
New cells discovered
        ↓
Add them to the queue
        ↓
Process them in the next level
```

Full worked example: [994 Rotting Oranges](../problems/0994-rotting-oranges.md).

### Complexity

- Graph: O(V + E) time, O(V) space.
- Grid: O(R·C) time, up to O(R·C) queue space.

### Interview-ready answer

> DFS explores deeply along one path before backtracking. BFS explores level by level using a queue. BFS finds shortest paths in unweighted graphs because it processes nodes in increasing order of distance from the source.
