---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, v8, libuv, call-stack, async-io]
---

# Node.js Runtime, Call Stack & Async I/O

> **Next:** [Event loop & microtasks](02-event-loop-and-microtasks.md) · **Related:** [Worker Threads vs BullMQ](06-worker-threads-vs-queues.md), [DFS recursion uses the call stack](../../dsa/graphs/02-dfs.md)

## TL;DR

- Node.js = **V8** (runs JS) + **libuv** (event loop, async I/O, thread pool) + **Node APIs** (`fs`, `http`, `crypto`…).
- One JS thread, **run-to-completion**: a callback can never interrupt synchronous code already running.
- **Async I/O ≠ parallel JavaScript.** The *I/O* progresses elsewhere; the *callback* still waits for the main thread.
- CPU-heavy work: **optimize → Worker Thread → durable queue** (in that order of consideration).

## Recall questions

<details><summary>How can one Node process serve 10,000 requests without one JS thread per request?</summary>

Waiting on I/O (DB, Redis, network, files) is delegated to the OS / libuv. The single JS thread only runs short callbacks when results are ready, so it is rarely idle-waiting.

</details>

<details><summary>What do V8, libuv and the Node APIs each do?</summary>

- **V8:** parses, optimizes and executes JavaScript; manages the JS heap.
- **libuv:** event loop, async I/O support, thread pool.
- **Node APIs:** expose `fs`, `http`, `crypto`, `process`… to JS and delegate to native machinery.

</details>

<details><summary>Output order: log A, fs.readFile(cb→B), log C, 5-billion-iteration loop, log D?</summary>

`A C D B`. Even if the file read finishes during the loop, its callback cannot run until the synchronous code finishes (run-to-completion).

</details>

<details><summary>Who actually executes the readFile callback?</summary>

OS/libuv complete the I/O → Node.js handles the completed request and invokes the callback at the right point in the event loop → **V8 executes it on the main JS thread**. libuv does *not* push JS onto the call stack directly.

</details>

<details><summary>Does marking a function <code>async</code> move its CPU work to another thread?</summary>

No. `async` only changes how the result is delivered (a promise). Its synchronous CPU work still blocks the main thread.

</details>

<details><summary>Three ways to deal with CPU-heavy work, and when to use each?</summary>

1. **Optimize the algorithm** — cheapest if it is doing unnecessary work.
2. **Worker Thread / worker pool** — CPU-intensive JS that must run while the main thread keeps serving.
3. **BullMQ / durable queue** — work that can happen after the response and needs retries/tracking. (A queue alone does not make CPU-heavy JS non-blocking.)
4. Bonus: **streaming** if the task processes large data incrementally.

</details>

## Gotchas

- "Async" describes *waiting*, not *computing*. Async I/O improves concurrency; Worker Threads address CPU. Different problems.
- The call stack is LIFO: `first()` → `second()` pushes; `second` pops first → output `Second, First, Third`.

---

## Deep dive

### 1. Node.js is not just JavaScript

Node.js is a runtime that allows JavaScript to execute outside a browser. Three pieces to distinguish:

- **V8:** Google's JavaScript engine. It parses and executes JavaScript, optimizes frequently executed code, and manages JavaScript memory.
- **libuv:** A C library used by Node.js for its event loop, asynchronous I/O support, and thread pool.
- **Node.js APIs:** The layer that exposes capabilities such as `fs`, `http`, `crypto`, and `process` to JavaScript.

When you write `fs.readFile()`, JavaScript doesn't directly perform all the underlying file-system work. Node.js delegates the operation through its native runtime machinery.

### 2. The call stack

```js
function first() {
  second();
  console.log("First");
}

function second() {
  console.log("Second");
}

first();
console.log("Third");
```

Output:

```text
Second
First
Third
```

Step by step:

1. `first()` begins → **push**
2. `second()` begins above `first()` → **push**
3. `second()` logs and returns → **pop**
4. `first()` resumes and logs → **pop**

The call stack tracks the functions currently executing. On a single Node.js thread, only one piece of JavaScript runs at a time.

> **Senior-level insight:** a function being `async` does not automatically make its CPU-intensive work run on another thread.

### 3. Async file I/O vs. JavaScript execution

```js
const fs = require("node:fs");

console.log("A");

fs.readFile("large-file.txt", () => {
  console.log("B");
});

console.log("C");

for (let i = 0; i < 5_000_000_000; i++) {
  // Simulate expensive CPU work
}

console.log("D");
```

Expected output (assuming the loop completes and the read succeeds):

```text
A
C
D
B
```

- `A` prints synchronously.
- `fs.readFile()` initiates asynchronous filesystem work.
- `C` prints without waiting for the file.
- The synchronous loop blocks the main JavaScript thread.
- `D` prints after the loop.
- `B` prints when Node.js processes the completed filesystem request and invokes the callback.

**Can the callback execute during the loop?** No, not on the same thread. Node.js JavaScript execution is *run-to-completion*: a synchronous operation must finish before another event-loop callback can execute. The underlying I/O may progress independently, but callback execution waits.

#### What each component does

- **Node.js filesystem API:** starts and coordinates the filesystem request.
- **Operating system / libuv:** supports the underlying I/O and completion handling. Depending on the operation and platform, filesystem work may use libuv's thread pool and/or OS facilities.
- **libuv event loop:** coordinates event processing and callback execution opportunities.
- **V8:** executes the JavaScript callback when Node.js invokes it.

**Key rule:** libuv does not directly push arbitrary JavaScript callbacks onto the call stack. Node.js handles the completed request and invokes the callback at an appropriate point. V8 then executes the callback on the JavaScript thread.

### 4. Async I/O is not parallel JavaScript

- Asynchronous I/O allows the main JavaScript thread to do other work while I/O is pending.
- Synchronous CPU-heavy JavaScript blocks that thread.
- Worker Threads can execute JavaScript in separate threads, each with its own V8 isolate.

### 5. Better approaches to CPU-heavy work

1. **Optimize the algorithm first.** Reducing unnecessary work may be simpler than adding infrastructure.
2. **Use a Worker Thread or reusable worker pool** for CPU-intensive JavaScript that must run separately from the main thread.
3. **Use BullMQ or another durable queue** when work can happen after the HTTP response and needs retries, tracking, or decoupling. A queue alone does not automatically move CPU-heavy JavaScript off the worker's event loop.
4. **Use streaming** if the task processes large files and can operate incrementally. See [Streams & backpressure](07-streams-and-backpressure.md).

### Interview-ready answer

> Async I/O improves concurrency by avoiding unnecessary waiting: the OS and libuv handle the I/O while the single JavaScript thread keeps running other code, and Node invokes the callback later on that same thread. It does not make JavaScript parallel — CPU-heavy synchronous code still blocks the event loop, which is what Worker Threads are for. They solve different problems.
