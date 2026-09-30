---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, libuv, thread-pool, crypto, performance]
---

# The libuv Thread Pool

> **Prev:** [Memory leaks](04-memory-leaks-and-gc.md) · **Next:** [Worker Threads vs BullMQ](06-worker-threads-vs-queues.md) · **Related:** [Runtime](01-runtime-and-call-stack.md)

## TL;DR

- Some async ops (`crypto.pbkdf2`, many `fs` ops) share libuv's pool — default **4 threads**, set by `UV_THREADPOOL_SIZE` **before process start**.
- Expensive hashing can occupy the pool → unrelated `fs` calls queue behind it. Network sockets generally use OS event notification, not a pool thread.
- **Pool contention ≠ main-thread blocking.** A bigger pool does nothing for a synchronous JS loop.
- Bigger pool isn't automatically better: more CPU contention and memory. **Measure first.**

## Recall questions

<details><summary>Why can password hashing slow down filesystem operations?</summary>

Both `crypto.pbkdf2()` and many `fs` operations use libuv's thread pool. If hashing occupies all workers, `fs` tasks wait in line.

</details>

<details><summary>Default pool size and how to change it?</summary>

Usually 4. `UV_THREADPOOL_SIZE`, set before the Node.js process starts.

</details>

<details><summary>Would increasing the pool size necessarily fix it?</summary>

No. It helps only if pool contention is the bottleneck *and* there is spare CPU. It can increase CPU contention and memory, compete with other processes, and leave the real bottleneck untouched.

</details>

<details><summary>How do you protect a service from thousands of hashing requests?</summary>

Rate limits + auth controls, bound concurrent hashing, queue/admission control, timeouts, monitor CPU/latency/queued requests, tune pool only after measuring, use established hashing libs with parameters fit for the threat model. Hashing is intentionally expensive → unlimited requests = resource-exhaustion attack.

</details>

## Gotchas

- First diagnose *which* bottleneck: event loop, libuv pool, CPU, or an external dependency.
- For repeated CPU work in JS, use a **reusable** worker pool to avoid paying worker startup costs each time.

---

## Deep dive

### Why hashing slows filesystem operations

Some asynchronous operations, including `crypto.pbkdf2()` and many filesystem operations, use libuv's thread pool. If expensive password-hashing tasks occupy the available pool workers, filesystem tasks that need the same pool must wait.

The network socket path generally uses operating-system event notification rather than consuming one libuv pool worker per socket.

### Pool size

The usual default is **4 workers**, configurable via `UV_THREADPOOL_SIZE` set before the process starts.

A larger pool can improve throughput when pool contention is the bottleneck and sufficient CPU exists. But it can also:

- Increase CPU contention.
- Increase memory consumption.
- Compete with other processes.
- Leave the real bottleneck untouched.

Measure thread-pool queueing, CPU utilization, and operation latency before changing the setting.

### What if the expensive work is synchronous JavaScript?

The main JavaScript thread is blocked. Increasing the libuv pool size does not fix a synchronous JavaScript loop, because that loop isn't executing in the pool.

### When are Worker Threads more appropriate?

When CPU-intensive **JavaScript** must execute separately from the main thread — expensive transformations, calculations, parsing, or compression implemented in JS. For repeated work, use a reusable worker pool.

### Protecting the service

- Apply rate limits and authentication controls.
- Bound the number of concurrent hashing operations.
- Use a queue or admission-control mechanism when appropriate.
- Set sensible request and operation timeouts.
- Monitor CPU, latency, and rejected/queued requests.
- Tune pool size only after measuring contention.
- Use established password-hashing libraries and parameters suitable for the threat model.

### Interview-ready answer

> Diagnose whether the bottleneck is the event loop, the libuv pool, CPU, or an external dependency before choosing a fix. Hashing and many fs calls share a 4-thread pool, so saturating it delays unrelated file I/O; raising `UV_THREADPOOL_SIZE` helps only with spare CPU, and does nothing for synchronous JS on the main thread. Bound and rate-limit expensive operations regardless.
