---
status: solid
confidence: 4
last_reviewed: 2026-09-30
next_review: 2026-10-07
tags: [dsa, graphs, grid]
---

# Graph Basics & Grids as Graphs

> **Next:** [DFS](02-dfs.md) · [BFS](03-bfs.md)

## TL;DR

- Graph = **nodes** (vertices) + **edges** (connections).
- **Connected component** = group where every node can reach every other.
- A **grid is a graph**: each cell is a node, its 4 neighbors are edges. Always bounds-check before touching a neighbor.

## Recall questions

<details><summary>What is a connected component? How many in <code>110 / 100 / 001</code>?</summary>

A group of nodes all reachable from each other. **2** land components (4-directional).

</details>

<details><summary>Write the 4-direction array from memory.</summary>

`[[-1,0],[1,0],[0,-1],[0,1]]` — up, down, left, right.

</details>

---

## Deep dive

### What is a graph?

A graph consists of nodes (vertices) and edges (connections) between them.

- Social network: people and friendships.
- Computer network: computers and connections.
- Map: locations and roads.
- Grid: cells and connections to neighboring cells.

### Connected component

A group of nodes where every node is reachable from every other node in that group.

```text
1 1 0
1 0 0
0 0 1
```

2 connected components of land, assuming only horizontal and vertical connections count.

### A grid is a graph

Each cell is a node; its valid neighboring cells are connected to it. For cell `(r, c)`:

```text
          UP
           ↑
LEFT ←  (r,c)  → RIGHT
           ↓
         DOWN
```

```js
const directions = [
  [-1, 0], // up
  [1, 0],  // down
  [0, -1], // left
  [0, 1],  // right
];
```

Always check grid boundaries before accessing a neighboring cell.
