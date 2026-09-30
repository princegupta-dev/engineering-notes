---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, memory, garbage-collection, heap, debugging]
---

# Memory Leaks & Garbage Collection

> **Prev:** [Async concurrency](03-async-concurrency.md) · **Next:** [libuv thread pool](05-libuv-thread-pool.md) · **Related:** [Buffer views retain memory](08-buffers-and-binary-data.md)

## TL;DR

- GC frees **unreachable** objects. It knows nothing about business lifecycle ("job finished").
- Classic leak = **reachable but useless**: a global `Map`/cache that only ever grows.
- `x = null` removes *one* reference → object becomes *eligible*, not collected immediately.
- A leak is **unintended retention**, not just "high memory". Find *which* memory category grows and *what retains it*.
- `heapUsed` dropping while RSS stays high ≠ fixed: check `external`, `arrayBuffers`, native allocations, allocator retention.

## Recall questions

<details><summary>Why does a global <code>Map</code> of job results leak?</summary>

Entries are added per job and never removed. Everything stays reachable through the global map, so GC can't reclaim it; a continuously running worker grows forever.

</details>

<details><summary>Unreachable vs reachable-but-useless?</summary>

Unreachable: no live reference → eligible for GC. Reachable-but-useless: still referenced (global map, cache, closure, listener) though the app no longer needs it → a leak.

</details>

<details><summary>How do you confirm a suspected leak? (5 steps)</summary>

1. Watch `heapUsed`, `heapTotal`, RSS, `external` over time.
2. Check whether the map's size grows continuously.
3. Capture & compare heap snapshots (controlled env — they pause the process and use a lot of memory).
4. Inspect retaining paths.
5. Reproduce the workload; check memory returns to a stable baseline after cleanup.

</details>

<details><summary>Two fixes for the unbounded map?</summary>

A) Delete entries at the correct point in the lifecycle — or don't store them at all. B) Bounded retention: max-size + TTL cache or periodic cleanup. For durable history use a DB with a retention policy.

</details>

<details><summary>heapUsed drops but RSS stays high — fixed?</summary>

Not proven. RSS includes native allocations and Buffers outside the JS heap, and the allocator may keep freed memory for reuse. Check `process.memoryUsage().external` / `.arrayBuffers`, heap snapshots, and RSS under a repeatable workload.

</details>

---

## Deep dive

### The leak

```js
const notificationResults = new Map();

async function processNotification(job) {
  const result = await sendNotification(job.data);

  notificationResults.set(job.id, {
    result,
    processedAt: Date.now(),
  });
}
```

**Why memory grows without bound:** as jobs finish, new entries are added, but nothing removes old ones. The objects remain reachable through the global map, so garbage collection cannot reclaim them.

**Does GC remove completed jobs from the map?** No. GC identifies objects that are no longer *reachable*. It does not understand that a job is finished. Business lifecycle and object reachability are different concepts.

### Does `null` guarantee collection?

```js
let result = { data: "example" };

result = null;
```

This removes that particular reference. If no other references exist, the object becomes eligible for garbage collection, but it is not necessarily collected immediately.

### Unreachable vs reachable-but-useless

- **Unreachable object:** no live reference can reach it; eligible for collection.
- **Reachable but useless object:** still referenced (e.g. by a global map or cache) even though the application no longer needs it.

The second case is a common cause of memory leaks in long-running Node.js services.

### Confirming the leak

1. Observe `heapUsed`, `heapTotal`, RSS, and external memory over time.
2. Check whether the map's entry count grows continuously.
3. Capture and compare heap snapshots in a controlled environment.
4. Inspect retaining paths to determine what keeps the objects alive.
5. Reproduce the workload and check whether memory returns to a stable baseline after cleanup.

Heap snapshots can pause the process and consume significant memory, so use caution in production.

### Fixes

**Fix A — delete results after use**

```js
const notificationResults = new Map();

async function processNotification(job) {
  const result = await sendNotification(job.data);

  notificationResults.set(job.id, {
    result,
    processedAt: Date.now(),
  });

  // Delete when no longer needed by application logic.
}
```

Deletion must happen at the correct point in the lifecycle. If no in-memory retention is required, don't store the result at all.

**Fix B — bounded retention**

Use a cache with a maximum size and TTL, or a periodic cleanup mechanism. For durable history, store the data in a database with a retention policy rather than an unbounded in-memory map.

### Advanced twist: `heapUsed` drops, but RSS stays high

That does not prove the problem is fixed. RSS includes memory beyond the JavaScript heap, including native allocations and buffers. The runtime or allocator may also retain memory for reuse after objects are collected.

Investigate:

- `process.memoryUsage().external`
- `process.memoryUsage().arrayBuffers`
- Heap snapshots and retaining paths
- Native allocations and buffers
- RSS behavior under a repeatable workload

### Interview-ready answer

> A memory leak is about unintended retention, not merely high memory usage. GC only frees unreachable objects, so a global map or cache that never evicts keeps everything alive. I'd confirm it by tracking heap/RSS/external over time and comparing heap snapshots' retaining paths, then fix it by deleting at the right lifecycle point or bounding retention with size + TTL.
