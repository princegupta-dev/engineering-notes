# Node.js Internals

> Goal: explain *how* Node.js works under load — mechanism, trade-offs, failure modes, and the evidence I'd collect — well enough for senior backend interviews and production incidents.

## Learning path

| #  | Note | One-line hook |
| -- | ---- | ------------- |
| 01 | [Runtime, call stack & async I/O](01-runtime-and-call-stack.md) | V8 runs JS, libuv waits; callbacks can't interrupt sync code |
| 02 | [Event loop & microtasks](02-event-loop-and-microtasks.md) | sync → nextTick → promises → loop phases (context matters) |
| 03 | [Async concurrency](03-async-concurrency.md) | `Promise.all` = max not sum; bound it; essential vs optional |
| 04 | [Memory leaks & GC](04-memory-leaks-and-gc.md) | GC frees unreachable, not useless |
| 05 | [libuv thread pool](05-libuv-thread-pool.md) | 4 threads shared by crypto & fs; pool ≠ main thread |
| 06 | [Worker Threads vs BullMQ](06-worker-threads-vs-queues.md) | CPU isolation vs durable jobs; idempotency + outbox |
| 07 | [Streams & backpressure](07-streams-and-backpressure.md) | `write()` false → wait for `'drain'`; memory is end-to-end |
| 08 | [Buffers & binary data](08-buffers-and-binary-data.md) | bytes ≠ text; views share memory |
| 09 | [Incident: event-loop blocking](09-incident-event-loop-blocking.md) | mitigate → measure → confirm → fix → prevent |
| 10 | Networking internals: TCP, HTTP, sockets, keep-alive | *next up* |

## One-page revision sheet

1. **Async I/O** — the I/O completes independently, but its callback can't interrupt synchronous code on the main thread.
2. **Event-loop scheduling** — `nextTick`, promise microtasks, timers and immediates follow different rules. Context matters.
3. **Promise concurrency** — `Promise.all()` coordinates; it doesn't create threads or cancel the rest on failure. Bound it.
4. **Memory leaks** — objects retained by global maps/caches stay reachable, so GC can't reclaim them.
5. **Thread-pool saturation** — pool contention ≠ main-thread blocking. Measure before tuning `UV_THREADPOOL_SIZE`.
6. **Background architecture** — Worker Threads isolate CPU; BullMQ manages jobs & retries; idempotency protects repeated effects; outbox keeps DB and queue consistent.
7. **Streams** — process incrementally; respect backpressure; stream the *input* too (cursor / keyset batches).
8. **Buffers** — keep binary as bytes; byte length ≠ string length; copy slices you retain.
9. **Incidents** — mitigate first, collect evidence, validate the hypothesis, fix the actual bottleneck.

## Self-assessment

- [ ] I can explain why a completed file read's callback cannot interrupt a synchronous loop.
- [ ] I can distinguish `process.nextTick()`, promise microtasks, timers, and `setImmediate()`.
- [ ] I can predict when sequential and concurrent I/O change endpoint latency.
- [ ] I can explain why `Promise.all()` does not create threads or cancel remaining operations.
- [ ] I can identify connection-pool contention and set concurrency limits.
- [ ] I can implement explicit partial-failure behavior for optional dependencies.
- [ ] I can diagnose a leak with heap snapshots and retaining paths.
- [ ] I can explain when increasing the libuv pool helps and when it doesn't.
- [ ] I can choose between optimization, Worker Threads, and BullMQ based on evidence.
- [ ] I can explain backpressure and the `'drain'` event precisely.
- [ ] I can explain why converting binary to UTF-8 corrupts it, and view vs copy for Buffers.
- [ ] I can diagnose event-loop blocking using metrics and CPU profiles.

> **How to practice:** open a note, answer the *Recall questions* out loud without expanding them, then check. Explaining the mechanism, trade-offs, failure modes and evidence matters more than memorizing the final answer.
