---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, worker-threads, bullmq, queues, idempotency, outbox]
---

# Worker Threads vs BullMQ (+ Idempotency & Outbox)

> **Prev:** [libuv thread pool](05-libuv-thread-pool.md) · **Next:** [Streams & backpressure](07-streams-and-backpressure.md) · **Related:** [Incident: event-loop blocking](09-incident-event-loop-blocking.md)

## TL;DR

- **Worker Threads = CPU isolation.** **Queues (BullMQ) = job lifecycle, retries, durability.** Different problems.
- A Worker Thread lives in the same process → dies with it. No durability.
- BullMQ doesn't make CPU-heavy JS non-blocking inside its worker.
- Neither gives **exactly-once external side effects** → you need **idempotency** (stable business key + status tracking).
- DB commit + queue publish can diverge → **transactional outbox**.

| Mechanism                  | Main purpose                                                   |
| -------------------------- | -------------------------------------------------------------- |
| Async DB/network I/O       | Don't block JS while waiting for I/O                           |
| Worker Threads             | Run CPU-intensive JS off the main thread                       |
| BullMQ                     | Background jobs, delayed work, retries, queue state            |
| Idempotency                | Make repeated attempts safe                                    |
| Transactional outbox       | Don't lose queue publication when the DB change commits        |

## Recall questions

<details><summary>Loyalty request: 800 ms CPU calc, 100 ms MySQL, 2 s flaky SMS. Where does each go?</summary>

Main thread validates + coordinates; MySQL async; CPU calc → Worker Thread/pool *if profiling shows it blocks* (first try optimizing); SMS → BullMQ after responding, with retries and idempotency.

</details>

<details><summary>Should the HTTP request wait for SMS delivery?</summary>

Usually not. Acknowledge acceptance, track delivery separately, and be honest in the response ("notification queued", not "SMS delivered").

</details>

<details><summary>How do you prevent duplicate SMS sends?</summary>

Durable notification record with a unique business key, reused across retries; track status; use provider idempotency if available; never treat a timeout as proof it wasn't sent. BullMQ job IDs alone don't guarantee exactly-once external effects.

</details>

<details><summary>DB commits but queue publish fails. What happens and what's the fix?</summary>

Business state and notification diverge (job never published). Fix: transactional outbox — write an outbox row in the same transaction, a separate publisher sends unpublished rows and marks them published, retrying safely.

</details>

<details><summary>Does a Worker Thread survive a process crash?</summary>

No — same process. Durability needs a persisted queue (e.g. BullMQ + properly configured Redis persistence), and even then guarantees depend on config and idempotent handlers.

</details>

---

## Deep dive

### The scenario

A loyalty request involves:

- CPU-heavy calculation: 800 ms.
- MySQL query: 100 ms.
- Third-party SMS: 2 seconds, may temporarily fail.

The API needs to respond quickly.

### A possible design

1. **Main thread:** validate the request and coordinate the operation.
2. **MySQL:** fetch the required data asynchronously.
3. **Worker Thread/pool:** run CPU-intensive JavaScript if profiling confirms it's expensive enough to justify offloading.
4. **BullMQ:** schedule SMS delivery if it can happen after the API response and needs durable handling and retries.
5. **Idempotency:** give the notification a stable business/job identifier and record delivery state so retries don't cause duplicate effects.
6. **Transactional outbox:** if DB state and queue publication must be reliably coordinated, write an outbox record in the same transaction and publish asynchronously.

### What belongs in a Worker Thread?

The CPU-intensive calculation, **if profiling confirms** it blocks the main thread. First consider whether it can be optimized. Worker Threads add communication and lifecycle overhead.

### What belongs in BullMQ?

SMS delivery: it can happen after the response and may need retries. A queue manages job state, retry policies, and delayed execution — configure persistence and failure handling.

If the calculation is also non-urgent it may be background work too, but CPU-heavy JS must still be isolated so it doesn't block the queue worker's event loop.

### Should the HTTP request wait for the SMS?

Usually not, if the product allows asynchronous delivery. Acknowledge that the request was accepted and track notification status separately. Only return a response that accurately represents what happened — "notification queued" rather than "SMS delivered".

### Preventing duplicate sends (idempotency)

- Create a durable notification record with a unique business key.
- Use that identifier consistently across retries.
- Track processing and delivery status.
- Check provider idempotency support.
- Don't treat a timeout as proof that the provider didn't send.

**Limitation:** if the provider accepts the SMS but the response is lost, a retry can send a duplicate unless the provider offers idempotency or delivery reconciliation. BullMQ job IDs alone don't guarantee exactly-once external side effects.

### Transactional outbox pattern

Problem: DB transaction commits, queue publication fails → notification never published.

1. Start a MySQL transaction.
2. Write the business change.
3. Insert an outbox record in the same transaction.
4. Commit.
5. A separate publisher reads unpublished outbox records and publishes them to the queue.
6. Mark them published; retry failures safely.

This avoids "commit database, then hope queue publication succeeds".

### Does a Worker Thread survive a crash?

No. A Worker Thread is part of the same Node.js process. BullMQ backed by appropriately configured Redis persistence is intended to support durable processing, but actual guarantees depend on configuration, failure mode, and idempotent job handling.

### Interview-ready answer

> Worker Threads provide CPU isolation; queues provide job lifecycle and durability. I'd keep the request path to validation and I/O, offload proven CPU hotspots to a worker pool, and push the SMS to a durable queue after responding. Neither gives exactly-once external effects, so I'd add an idempotency key with status tracking, and a transactional outbox so the DB change and the job can't diverge.
