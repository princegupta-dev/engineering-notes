# Graphs

| #  | Note | Hook |
| -- | ---- | ---- |
| 01 | [Graph basics & grids](01-graph-basics.md) | nodes + edges; a grid is a graph |
| 02 | [DFS](02-dfs.md) | go deep, backtrack; recursion / stack |
| 03 | [BFS](03-bfs.md) | level by level; queue; shortest path |

## DFS vs BFS

| Feature                            | DFS                             | BFS                                |
| ---------------------------------- | ------------------------------- | ---------------------------------- |
| Exploration                        | Deep first                      | Level by level                     |
| Mechanism                          | Recursion or stack              | Queue                              |
| Backtracking                       | Natural with recursion          | Not its main mechanism             |
| Connected components               | Yes                             | Yes                                |
| Shortest path (unweighted)         | Not guaranteed                  | **Yes**                            |
| Typical grid use                   | Flood fill, island area         | Minimum steps, spreading over time |

**Which one?** "Explore / count / measure a region" → DFS (or BFS). "Minimum steps / time / spread from sources" → **BFS**.

## Complexity cheat sheet

V = nodes, E = edges, R × C = grid size.

| Algorithm       | Time     | Extra space   |
| --------------- | -------- | ------------- |
| Graph DFS       | O(V + E) | O(V)          |
| Graph BFS       | O(V + E) | O(V)          |
| Grid DFS        | O(R·C)   | up to O(R·C)  |
| Grid BFS        | O(R·C)   | up to O(R·C)  |
| Rotting Oranges | O(R·C)   | O(R·C)        |

Each cell is processed a constant number of times. Recursive grid DFS can reach O(R·C) call-stack depth. In JS, `Array.shift()` is O(n); a head index avoids it.

## Interview self-check

Explain each out loud without reading:

1. What is a graph?
2. What is a connected component?
3. What is DFS?
4. Why use `visited`?
5. What is BFS?
6. Why does BFS find shortest paths in unweighted graphs?
7. Why mark visited on enqueue?
8. Why does Number of Islands increment outside DFS?
9. How does Max Area of Island differ?
10. Why is Rotting Oranges multi-source BFS?
11. Why use queue size in Rotting Oranges?
12. When does Rotting Oranges return `-1`?

Answers live in each note's **Recall questions** section.
