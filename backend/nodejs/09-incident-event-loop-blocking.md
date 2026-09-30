---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, incident, event-loop, cpu, bullmq, production]
---

# Incident: High CPU & Event-Loop Delay

> **Concepts used:** [Runtime](01-runtime-and-call-stack.md), [Worker Threads vs BullMQ](06-worker-threads-vs-queues.md), [libuv pool](05-libuv-thread-pool.md)

## TL;DR

- Symptoms: p95 4.8 s, **event-loop delay 750 ms, CPU 95%**, MySQL/Redis **normal**, memory stable, release added a **large synchronous JSON transformation**, BullMQ backlog, bigger DB pool didn't help.
- Hypothesis: sync CPU work blocks the main thread. Healthy databases can't help a blocked app thread.
- Order: **mitigate first** (rollback / feature flag) → **measure** → **confirm** (CPU profile) → **durable fix** → **prevent**.
- Don't change unrelated infrastructure (DB pool) without evidence.

## Recall questions

<details><summary>Why is the event loop delayed if MySQL and Redis are healthy?</summary>

The main thread must finish synchronous JS before processing anything else. A transformation eating hundreds of ms of CPU delays request callbacks, DB responses, timers — regardless of how fast the DB answered.

</details>

<details><summary>What do you do in the first five minutes?</summary>

1. Correlate release timeline. 2. Roll back / disable via feature flag if safe. 3. Watch event-loop delay, CPU, latency recover. 4. Check queue depth and job age. 5. CPU profile if safe. 6. Avoid unhelpful changes (bigger DB pool).

</details>

<details><summary>What evidence do you collect before/after mitigation?</summary>

CPU + profiles, event-loop delay/utilization, latency percentiles + error rate, throughput, queue depth / oldest-job age / throughput, transformation duration & payload sizes, DB/Redis latency + pool wait time, memory.

</details>

<details><summary>Growing queue: cause, symptom, or both?</summary>

Both. Symptom: blocked workers complete jobs slower than arrivals. Cause: consumers running too many CPU-heavy jobs concurrently saturate CPU further. Compare arrival vs completion rate, queue age, worker CPU/event-loop delay, job duration by type, configured concurrency.

</details>

<details><summary>Optimize, Worker Threads, or BullMQ?</summary>

Optimize if it does unnecessary work / repeated serialization. Worker Threads if inherently CPU-heavy and must run while serving requests. BullMQ if it can happen after the response and needs tracking/retries. Often combined: enqueue, and have workers run CPU work in a thread pool.

</details>

---

## Deep dive

### Incident summary

| Metric           | Observation                            |
| ---------------- | -------------------------------------- |
| API p95 latency  | 4.8 seconds                            |
| Event-loop delay | 750 ms                                 |
| CPU utilization  | 95%                                    |
| MySQL latency    | Normal                                 |
| Redis latency    | Normal                                 |
| Memory usage     | Stable                                 |
| Recent change    | Large synchronous JSON transformation  |
| BullMQ           | Jobs accumulating                      |
| Tried            | Increasing MySQL pool — didn't help    |

### 1. Leading hypothesis

CPU-intensive synchronous JavaScript is blocking the event loop. Evidence: high event-loop delay, high CPU, began after a release with expensive sync processing, DB/Redis latency normal, bigger DB pool didn't help. It's a strong hypothesis, not proof — a CPU profile and comparison with the previous release confirm it.

### 2. Why is the loop delayed if the DBs are healthy?

The main thread must execute synchronous JavaScript before processing other callbacks. If the transformation consumes CPU for hundreds of milliseconds, the thread cannot promptly process incoming requests, DB responses, timers, or other JS work. Healthy databases don't prevent a blocked application thread.

### 3. First five minutes — reduce impact, then investigate

1. Check the release timeline; confirm correlation.
2. If safe, roll back or disable the feature with a flag.
3. Observe whether event-loop delay, CPU, and API latency improve.
4. Check queue depth and job age.
5. Capture a CPU profile if safe and won't worsen the incident.
6. Avoid unhelpful changes such as blindly increasing the MySQL pool.

A rollback or feature disablement is usually safer than deploying a complex optimization mid-incident.

### 4. Evidence to collect (before and after mitigation)

- CPU utilization and CPU profiles.
- Event-loop delay and utilization.
- API latency percentiles and error rate.
- Request throughput.
- BullMQ queue depth, oldest-job age, processing throughput.
- Transformation duration and input payload sizes.
- MySQL/Redis latency and connection-pool wait time.
- Memory metrics, even though currently stable.

### 5. Optimize, Worker Threads, or BullMQ?

**Optimize** when the algorithm does unnecessary work, large intermediate objects / repeated serialization are expensive, or a simpler algorithm materially reduces CPU.

**Worker Threads** when the computation is inherently CPU-intensive, must run while the main thread keeps serving, and the communication overhead is justified.

**BullMQ** when the work can happen after the response, needs durable tracking and retries, and the service can report status instead of immediate completion.

A combined solution may fit: enqueue non-urgent work, and have workers run CPU-heavy calculations in a separate thread pool.

### 6. Is the growing queue a cause or symptom?

Both, potentially:

- **Symptom:** workers can't keep up because their event loops are blocked or capacity dropped.
- **Cause:** consumers starting too many CPU-heavy jobs concurrently further saturate CPU.

Investigate job arrival vs completion rate, queue depth and oldest-job age, worker CPU and event-loop delay, job duration by type, configured concurrency and active workers. If arrivals exceed completions over time, the queue grows — reduce load, restore capacity, or both.

### 7. Prevent recurrence

- Regression benchmarks for large JSON payloads.
- Monitor event-loop delay, CPU, API latency, queue age.
- Profile CPU-intensive code paths.
- Bounded concurrency and backpressure.
- Production-like load tests.
- Alerts for sustained queue growth and event-loop delay.
- Feature flags / rollback mechanisms for risky changes.
- An incident runbook; verify recovery after mitigation.

### Interview-ready answer

> Form a testable hypothesis from evidence, mitigate customer impact first, verify the result, then implement a durable fix. Here high event-loop delay + high CPU + healthy DBs + a new synchronous transformation points to main-thread blocking, so I'd roll back or flag it off, confirm with a CPU profile, then optimize, move it to a worker pool, or defer it to a queue — not grow the DB pool.
