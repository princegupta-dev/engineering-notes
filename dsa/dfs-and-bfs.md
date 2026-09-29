# 📘 DSA Notes: Graphs, DFS & BFS

Interview preparation · Concepts learned so far

These notes cover everything you've learned, from graph fundamentals to multi-source BFS and LeetCode 994 — Rotting Oranges. They're organized so you can copy them into your notes and revise before interviews.

# 1. Graph Fundamentals

## What is a graph?

A graph consists of nodes (vertices) and edges (connections) between them.

Examples:

- Social network: people and friendships.

- Computer network: computers and connections.

- Map: locations and roads.

- Grid: cells and connections to neighboring cells.

## What is a connected component?

A connected component is a group of nodes where every node is reachable from every other node in that group.

Example:

```
1 1 0
1 0 0
0 0 1
```

There are 2 connected components of land, assuming only horizontal and vertical connections count.

## How is a grid a graph?

Each cell is a node. Its valid neighboring cells are connected to it.

For cell `(r, c)`, the four directions are:

```
          UP
           ↑
LEFT ←  (r,c)  → RIGHT
           ↓
         DOWN
```

JavaScript

```
const directions = [
    [-1, 0], // up
    [1, 0],  // down
    [0, -1], // left
    [0, 1]   // right
];
```

Always check grid boundaries before accessing a neighboring cell.

# 2. DFS — Depth-First Search

## Definition

DFS explores as deeply as possible along one path before backtracking to explore another path.

Think: go deep → hit a dead end → return → try another path.

## Example

```
      A
     / \
    B   C
   / \
  D   E
```

One possible DFS order:

```
A → B → D → E → C
```

The exact order depends on the order in which neighbors are processed.

## How DFS works

1. Start at a node.

2. Mark it as visited.

3. Explore an unvisited neighbor.

4. Continue deeper.

5. When no unvisited neighbors remain, backtrack.

6. Continue until the reachable component has been explored.

## DFS implementation in JavaScript

JavaScript

```
function dfs(graph, node, visited) {
    visited.add(node);

    for (const neighbor of graph[node]) {
        if (!visited.has(neighbor)) {
            dfs(graph, neighbor, visited);
        }
    }
}
```

Example usage:

JavaScript

```
const graph = {
    A: ["B", "C"],
    B: ["D", "E"],
    C: [],
    D: [],
    E: []
};

const visited = new Set();

dfs(graph, "A", visited);
```

## What is recursion?

Recursion occurs when a function calls itself.

JavaScript

```
function countdown(n) {
    if (n === 0) return;

    console.log(n);
    countdown(n - 1);
}
```

The condition `n === 0` is the base case. It stops the recursive calls.

## What is the call stack?

The call stack remembers active function calls and where execution should resume.

For DFS:

```
dfs(A)
  └── dfs(B)
        └── dfs(D)
              └── return
        └── continue with next neighbor
  └── continue with next neighbor
```

This is how recursive DFS naturally performs backtracking.

## Why do we need `visited`?

Graphs can contain cycles. Without tracking visited nodes, traversal can revisit nodes indefinitely or do redundant work.

JavaScript

```
if (!visited.has(neighbor)) {
    visited.add(neighbor);
    dfs(graph, neighbor, visited);
}
```

For recursive DFS, mark a node visited before exploring its neighbors.

# 3. DFS on a Grid

For grid problems, DFS often explores every cell in a connected region.

The general process:

1. Check whether the cell is out of bounds.

2. Check whether it is water, blocked, or already visited.

3. Mark the cell as visited.

4. Explore its four neighbors.

Example pattern:

JavaScript

```
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

This example assumes land is represented by numeric `1` and water by numeric `0`.

Important: Some problems use strings, such as `"1"` and `"0"`, rather than numbers.

## Using the grid itself to mark visited

Sometimes you don't need a separate `visited` set.

For example, changing a land cell from `1` to `0` marks it as visited. Future calls will skip it.

This technique is called in-place marking.

# 4. Three DFS Problems You Solved

## LeetCode 733 — Flood Fill

Solved

Goal: Change the starting pixel and all connected pixels of its original color to a new color.

Approach:

1. Store the original color.

2. If the original color equals the new color, return immediately.

3. Run DFS from the starting pixel.

4. Change each matching pixel before exploring its neighbors.

Key insight: Changing the color marks a pixel as visited.

## LeetCode 695 — Max Area of Island

Solved

Goal: Find the size of the largest connected island.

Approach:

1. Scan every cell.

2. When you find land, run DFS.

3. DFS returns the total area of that connected island.

4. Update the maximum area.

Key formula:

area=1+area from each valid neighbor\text{area}=1+\text{area from each valid neighbor}area=1+area from each valid neighbor

Water, out-of-bounds cells, and visited cells contribute `0`.

## LeetCode 200 — Number of Islands

Solved

Goal: Count the number of connected land components.

Approach:

1. Scan every cell.

2. When an unvisited land cell is found, increment the island count.

3. Run DFS to visit the entire island.

4. Continue scanning.

Key insight: Increment the count once per newly discovered island, not once per cell inside DFS.

## Difference between the two island problems

|
Problem

|

What DFS does

|
| --- | --- |
|

Number of Islands

|

Explores and marks an entire island

|
|

Max Area of Island

|

Explores an island and returns its area

|

This is an important pattern: DFS can either explore a component or explore a component and calculate information about it.

# 5. BFS — Breadth-First Search

## Definition

BFS explores a graph level by level, processing nodes at the current distance before nodes at a greater distance.

Think: spread outward like a wave.

## Example

```
        A
       / \
      B   C
     / \
    D   E
```

BFS levels:

```
Level 0: A
Level 1: B, C
Level 2: D, E
```

Traversal order:

```
A → B → C → D → E
```

## Why does BFS use a queue?

A queue follows FIFO — First In, First Out.

The node discovered first is processed first. This naturally maintains the level-by-level order.

Basic queue operations:

JavaScript

```
const queue = [];

queue.push("A"); // Add to back
const node = queue.shift(); // Remove from front
```

## BFS implementation in JavaScript

This is the generic graph BFS you wrote correctly:

JavaScript

```
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

## Why mark visited when adding to the queue?

Mark nodes visited when they are enqueued, not when they are dequeued.

JavaScript

```
visited.add(neighbor);
queue.push(neighbor);
```

This prevents two different nodes from adding the same neighbor to the queue before it gets processed.

# 6. DFS vs BFS

|
Feature

|

DFS

|

BFS

|
| --- | --- | --- |
|

Exploration

|

Deep first

|

Level by level

|
|

Common mechanism

|

Recursion or stack

|

Queue

|
|

Backtracking

|

Natural with recursion

|

Not its main mechanism

|
|

Connected components

|

Yes

|

Yes

|
|

Shortest path in unweighted graphs

|

Not guaranteed by ordinary DFS

|

Yes

|
|

Typical grid use

|

Flood fill, island area

|

Minimum steps, spreading over time

|

Interview explanation:

> DFS explores deeply along one path before backtracking. BFS explores level by level using a queue. BFS finds shortest paths in unweighted graphs because it processes nodes in increasing order of distance from the source.

# 7. Why BFS Finds the Shortest Path

BFS processes nodes in increasing order of their distance from the starting node.

```
Distance 0: A
Distance 1: B, C
Distance 2: D, E, F
```

If `F` is first reached through `A → C → F`, its distance is `2` edges.

BFS has already explored all nodes at distances `0` and `1`. Therefore, no shorter path to `F` exists.

Important qualification: This guarantee applies to unweighted graphs, or graphs where every edge has equal cost.

# 8. Grid BFS and Distance

Consider a grid:

```
S . .
. . .
. . E
```

Assuming every cell is walkable and movement is allowed only horizontally and vertically, the shortest distance is `4` moves.

One shortest path is:

```
S → right → right → down → down → E
```

Correction to the arrow notation: from the top-left to bottom-right, the path visits five cells and makes 4 moves.

BFS can find this shortest distance because each move costs one step.

# 9. Rotting Oranges — LeetCode 994

![Single orange fruit isolated on white background](https://images.openai.com/static-rsc-4/MB4N3kw_R9853sZtP2p-WPY7mabF8L3_R7tr10F2DDMzBswQcH6B9AA2WgUrly9TNR22D16FkMqSu-wPKVsz7dysbn7OKTnU3g6Ab5SV-_9TJtvBc9g0BGCHukpmGtrwjNHN56-CoJSZKEeVPvyDezI_rE1agnxXGFMmizvO90f63iHVRLtQCqvGxssy3mIe?purpose=inline)

Fresh orange

Represented by `1`

![Rotten orange fruit Stock Photos, Royalty Free Rotten orange fruit Images | DepositPhotos](https://images.openai.com/static-rsc-4/YrUCk-QhbouDIc4G7EeSwrmslADfT9K9N5x8EBAMK2g2f_Qw1FFEX_NmplZ5Rwwb75ZijpBmm4CJGj04ezlL65mMVWW4cHUyHOESV8NBqlNntax7rv9xx9C5HxGf6nW35L-5WXShCWbbNtsnl1oKXfs7yFy8seTG77lU8CXz8fw?purpose=inline)

Rotten orange

Represented by `2`

Empty cell

Represented by `0`

## Problem statement

Every minute, a rotten orange infects its fresh neighbors in the four directions.

Return the minimum number of minutes required to rot every reachable fresh orange. If some fresh orange can never rot, return `-1`.

## The central idea: Multi-source BFS

Multi-source BFS means starting BFS from multiple source nodes simultaneously.

Why is it needed here?

All initially rotten oranges begin spreading at the same time. Therefore, we place every initially rotten orange in the initial queue.

For example:

```
2 1 1
1 1 0
0 1 1
```

Initially:

```
Queue = [(0,0)]
Minutes = 0
Fresh oranges = 6
```

The rotten orange at `(0,0)` infects `(0,1)` and `(1,0)` during minute 1.

```
2 2 1
2 1 0
0 1 1
```

The newly rotten oranges are added to the queue to spread during the next minute.

## The most important concept: one BFS level = one minute

Suppose the current queue contains:

```
[(1,0), (0,1)]
```

These are the oranges spreading during the current minute.

We capture the current queue size:

JavaScript

```
const size = queue.length;
```

Then process exactly that many oranges.

```
Process the current level
        ↓
New oranges become rotten
        ↓
Add them to the queue
        ↓
Process them in the next level
```

The new oranges must wait for the next minute. This is why `size` matters: newly added queue entries must not be processed as part of the same minute.

## Rotting Oranges algorithm — pseudocode

```
Count all fresh oranges
Put all initially rotten oranges in the queue

minutes = 0

While the queue is not empty AND fresh oranges remain:

    size = current queue length

    Repeat size times:
        Remove one rotten orange
        Check its four neighbors

        If a neighbor is fresh:
            Make it rotten
            Decrease fresh count
            Add it to the queue

    Increase minutes by 1

If fresh count is 0:
    Return minutes
Otherwise:
    Return -1
```

## Why decrement `fresh` immediately?

When an orange changes from `1` to `2`, it is no longer fresh.

We update the count at that moment:

JavaScript

```
grid[nr][nc] = 2;
fresh--;
queue.push([nr, nc]);
```

Changing the grid immediately also prevents the same orange from being added to the queue twice.

## What if some oranges cannot rot?

For example:

```
2 1 0 1
```

The last `1` is separated from the rotten orange by an empty cell. It cannot be reached.

The algorithm ends with fresh oranges remaining and returns `-1`.

# 10. Complexity Cheat Sheet

Let VVV be the number of graph nodes and EEE the number of edges. For a grid with RRR rows and CCC columns:

|
Algorithm

|

Time

|

Extra space

|
| --- | --- | --- |
|

Graph DFS

|

O(V+E)O(V+E)O(V+E)

|

O(V)O(V)O(V)

|
|

Graph BFS

|

O(V+E)O(V+E)O(V+E)

|

O(V)O(V)O(V)

|
|

Grid DFS

|

O(RC)O(RC)O(RC)

|

Up to O(RC)O(RC)O(RC)

|
|

Grid BFS

|

O(RC)O(RC)O(RC)

|

Up to O(RC)O(RC)O(RC)

|
|

Rotting Oranges

|

O(RC)O(RC)O(RC)

|

O(RC)O(RC)O(RC)

|

Each grid cell is processed at most a constant number of times. For the recursive grid DFS you learned, the call stack can grow to O(RC)O(RC)O(RC) in the worst case.

JavaScript note: `Array.shift()` can require shifting remaining elements. It is fine for learning, but a queue with a head index can avoid that repeated work.

# 11. Interview Revision: Questions You Should Be Able to Explain

Use this as your self-checklist. Try explaining each answer aloud without reading the notes.

1. What is a graph?

A collection of nodes and edges representing relationships.

2. What is a connected component?

3. What is DFS?

Deep exploration followed by backtracking; commonly implemented with recursion or a stack.

4. Why use visited?

5. What is BFS?

6. Why does BFS find shortest paths in unweighted graphs?

7. Why mark visited on enqueue?

8. Why does Number of Islands increment outside DFS?

9. How does Max Area of Island differ?

10. Why is Rotting Oranges multi-source BFS?

11. Why use queue size for Rotting Oranges?

12. When does Rotting Oranges return -1?

## Your current learning status

DFS foundations

Graph concepts, recursion, visited tracking, and connected components.

Solved

DFS grid problems

Flood Fill, Max Area of Island, and Number of Islands.

Solved

BFS foundations

Queue, traversal, visited tracking, levels, and shortest-path intuition.

Learned

Rotting Oranges

You understand neighbor infection and minute-by-minute spreading. The full implementation and level tracking still need practice.

In progress

Recommended next step: Continue with Rotting Oranges using small grids until you can independently trace each minute. Then build the code one piece at a time instead of memorizing the full solution.
