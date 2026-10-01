# Lesson 15 — Production Debugging and Observability

Node.js Internals Mastery · Senior Backend Engineer Track

Today, we're going to learn how senior engineers investigate production incidents without guessing.

We'll use a scenario from your stack: Node.js, NestJS, MySQL on AWS RDS, Redis, BullMQ, Docker, and CloudWatch.

The central principle is:

Don't ask only whether the system is slow. Determine which part is slow, why it is slow, and what evidence proves it.

## 1. The production incident: your API suddenly becomes slow

Imagine your Fills application usually responds in 100–200 ms. Suddenly, customers report that product listings take 3 seconds, OTP verification is delayed, and some requests time out.

You inspect the application logs and find no obvious errors.

What do you do?

A junior debugging approach might be to add more Redis caching, increase the database connection pool, or restart the service.

A senior debugging approach starts by narrowing the failure.

## Incident snapshot

HTTP p99 latency

# 3,000 ms

Normally 180 ms

MySQL query latency

# 15 ms

Appears healthy

Redis latency

# 3 ms

Appears healthy

CPU utilization

# 94%

Potential bottleneck

Illustrative incident data, not measurements from your actual application.

These measurements suggest investigating CPU contention and event-loop responsiveness. They do not yet prove the root cause. CPU could be consumed by synchronous JavaScript, garbage collection, compression, other processes, or a combination of factors.

Our job is to collect evidence that distinguishes those possibilities.

## 2. The three pillars of observability

Observability is the ability to infer a system's internal state from the evidence it produces.

1. Logs — what happened?

Individual events with timestamps, severity, request IDs, error details, and relevant context.

Example: a Shopify request timed out while fetching product variants.

2. Metrics — how much, how often, and how long?

Numerical measurements collected over time, such as request rates, p99 latency, CPU utilization, heap usage, and queue depth.

Example: p99 latency rose from 180 ms to 3 seconds after a deployment.

3. Traces — where did this request spend its time?

A trace follows a request across operations and services, with spans for individual steps.

Example: 20 ms in the API, 2,700 ms waiting for an upstream provider, and 30 ms in MySQL.

Each pillar answers a different question. Logs give detail, metrics reveal patterns, and traces show how latency is distributed across a request's journey.

For production-grade debugging, you usually need all three.

## 3. Structured logging: make logs searchable

Consider this log:

```
Something went wrong while fetching products
```

It tells you almost nothing. Which request? Which tenant? Which upstream API? How long did the operation take?

A structured log captures useful context as fields.

TypeScript

```
logger.error({
  message: "Product fetch failed",
  requestId,
  tenantId,
  operation: "shopify.fetchProducts",
  durationMs: 2500,
  errorName: error.name,
  errorMessage: error.message,
});
```

A JSON log might look like this:

JSON

```
{
  "level": "error",
  "message": "Product fetch failed",
  "requestId": "req-abc123",
  "tenantId": "tenant-42",
  "operation": "shopify.fetchProducts",
  "durationMs": 2500,
  "errorName": "TimeoutError"
}
```

The values above are illustrative.

Now you can filter logs by `requestId`, group errors by operation, or compare durations across tenants.

### What should you log?

For your NestJS backend, useful fields include:

- `timestamp`, `level`, `message`

- `requestId` or `correlationId`

- `route`, `method`, `statusCode`

- `durationMs`

- `operation` or dependency name

- `jobId` for BullMQ jobs

- Error type and stack trace when appropriate

Avoid logging passwords, OTPs, access tokens, payment credentials, or full sensitive request bodies.

### Correlation IDs

Suppose a single user request triggers a service call, a MySQL query, and a BullMQ job. You need to connect those events without guessing from timestamps.

A correlation ID can help:

```
HTTP request       requestId=req-123
Service operation  requestId=req-123
Database operation requestId=req-123
Queue job          correlationId=req-123
```

Use a request-scoped mechanism such as NestJS interceptors and, where appropriate, `AsyncLocalStorage` to propagate context through asynchronous operations. When processing a queued job, persist the correlation ID in the job's metadata because the job may execute in a different process.

If a client supplies a request ID, validate it and treat it as untrusted input. Don't use arbitrary user-controlled values as metric labels.

## 4. Metrics: learn to read the shape of a system

Averages can hide serious problems.

Imagine these request durations, in milliseconds:

`50, 55, 60, 65, 70, 80, 100, 120, 150, 3000`

The average is influenced by the 3-second request. More importantly, some users are experiencing a much worse delay than most users.

- p50: the median; half of observations are at or below this value.

- p95: 95% of observations are at or below this value.

- p99: 99% of observations are at or below this value.

For production APIs, track latency percentiles alongside request volume and errors.

## A useful service dashboard

Latency

p50, p95, p99

Traffic

Requests/sec

Errors

Error rate, timeouts

Saturation

CPU, memory, pool usage

### Node.js-specific signals

Event-loop delay

Event-loop utilization

Heap usage

GC activity

Open handles

Queue depth

### The four golden signals

A useful service-level view includes:

1. Latency: how long requests take.

2. Traffic: how much demand the service receives.

3. Errors: how often operations fail.

4. Saturation: how close resources are to their capacity.

A service can have a low error rate and still be unhealthy if latency is high. Similarly, CPU utilization alone cannot tell you whether users are getting slow responses.

## 5. Instrument the Node.js event loop

In Lesson 11, we discussed event-loop delay. Now we'll use it as an operational diagnostic.

TypeScript

```
import {
  monitorEventLoopDelay,
  performance,
} from "node:perf_hooks";

const histogram = monitorEventLoopDelay({
  resolution: 20,
});

histogram.enable();

let previousELU = performance.eventLoopUtilization();

const interval = setInterval(() => {
  const currentELU = performance.eventLoopUtilization();

  const intervalELU = performance.eventLoopUtilization(
    currentELU,
    previousELU,
  );

  previousELU = currentELU;

  console.log({
    eventLoopUtilization: intervalELU.utilization,
    eventLoopDelayP99Ms:
      histogram.percentile(99) / 1e6,
    eventLoopDelayMaxMs:
      histogram.max / 1e6,
  });

  histogram.reset();
}, 10_000);

interval.unref();
```

In production, export these values to your metrics backend instead of relying only on console logs.

Interpret the measurements together:

|
Observation

|

What to investigate

|
| --- | --- |
|

High event-loop delay and high CPU

|

CPU-heavy JavaScript, garbage collection, or other CPU contention

|
|

High event-loop delay and modest CPU

|

Blocking operations, scheduling delays, or measurement and environment effects

|
|

Low event-loop delay but high API p99

|

Database or upstream latency, connection-pool waits, network delays, or queueing elsewhere

|
|

High event-loop utilization

|

The event loop spends much of its measured time active; identify which work is responsible

|
|

High memory growth and increasing latency

|

Heap growth, allocation pressure, garbage collection, or a memory leak

|

These are diagnostic clues, not definitive diagnoses. A CPU profile, heap analysis, traces, and dependency metrics help establish the cause.

## 6. CPU profiling: find what is actually consuming CPU

Imagine CPU usage rises to 95% after a release. Your logs show successful requests, and MySQL latency remains low.

You suspect an expensive loop, but where is the CPU actually going?

A CPU profile samples execution stacks over time and helps identify hot functions.

For a reproducible workload, you can start Node.js with:

Bash

```
node --cpu-prof dist/main.js
```

Exercise the affected endpoint or workload, then stop the process cleanly. Node.js writes a CPU profile that you can inspect in Chrome DevTools or another compatible profile viewer.

Look for:

- Functions consuming a large proportion of sampled CPU time.

- Expensive serialization, transformation, or parsing.

- Repeated operations inside large loops.

- Excessive logging or object allocation.

- Unexpectedly hot dependencies.

A profile showing a function as hot does not automatically mean that function is defective. It may simply be where the application performs its intended work. Compare the profile with the expected workload and a healthy baseline.

### Production example: slow reward calculation

Suppose a campaign calculates rewards for 100,000 retailers.

Your investigation shows:

- MySQL query latency: 12 ms.

- Redis command latency: 3 ms.

- CPU utilization: 92%.

- CPU profile: most sampled time is spent in synchronous reward calculations.

The evidence points toward CPU-bound application work rather than slow database access.

Potential fixes include reducing repeated computation, improving the algorithm, processing bounded batches, or offloading CPU-heavy work to Worker Threads.

Don't add database indexes to solve a CPU bottleneck unless the evidence points to a database problem.

## 7. Heap snapshots: investigate memory leaks

Now consider a different incident.

Your Node.js service starts with 300 MB of memory. After several hours, it reaches 1.8 GB and restarts.

The important question is not simply whether memory is high. It is whether memory is growing because of normal workload behavior, allocation pressure, caching, or objects that should have been released but remain reachable.

### Understand the memory measurements

- `heapUsed`: JavaScript heap currently used by objects.

- `heapTotal`: memory allocated to the V8 JavaScript heap.

- `external`: memory associated with native or external allocations tracked by Node.js.

- `rss`: resident memory used by the process, including more than the JavaScript heap.

Example:

TypeScript

```
setInterval(() => {
  const memory = process.memoryUsage();

  console.log({
    heapUsedMB: Math.round(memory.heapUsed / 1024 / 1024),
    heapTotalMB: Math.round(memory.heapTotal / 1024 / 1024),
    externalMB: Math.round(memory.external / 1024 / 1024),
    rssMB: Math.round(memory.rss / 1024 / 1024),
  });
}, 30_000).unref();
```

These measurements describe different parts of memory usage. A high RSS value does not necessarily mean you have a JavaScript object leak.

### A typical leak

TypeScript

```
const requestHistory: unknown[] = [];

function handleRequest(request: unknown) {
  requestHistory.push(request);
}
```

If the array grows indefinitely, it keeps references to objects that might otherwise become collectible.

Other common sources include unbounded caches, event listeners that are never removed, closures retaining large objects, and accumulating buffers.

### How to investigate

1. Observe memory after warm-up under a repeatable workload.

2. Compare heap usage over time, preferably after comparable garbage-collection conditions.

3. Capture heap snapshots at different stages when it is safe to do so.

4. Compare retained objects and reference paths.

5. Identify why those objects remain reachable.

6. Apply a fix and repeat the workload to verify the trend.

Heap snapshots can pause the process and temporarily require substantial additional memory. Capturing one from a near-OOM production instance can make the incident worse. Prefer a controlled replica when possible.

For deeper investigation, Node.js provides [diagnostic reports](https://nodejs.org/api/report.html) , [CPU profiling](https://nodejs.org/api/cli.html#--cpu-prof) , and [V8 profiling and memory tools](https://nodejs.org/api/v8.html) .

## 8. Distributed tracing: find the slow hop

Your API might perform these operations:

```
GET /products
    ├── Read Redis cache
    ├── Query MySQL if needed
    └── Fetch Shopify product details
```

Suppose the HTTP request takes 2.9 seconds. A log at the controller level tells you the total duration but not which operation dominates.

A distributed trace can expose spans like these:

## Example request trace

Illustrative timings for one request

HTTP server span

2900 ms

Redis lookup

3 ms

MySQL query

15 ms

Shopify request

2700 ms

The example shows durations and relative scale, not a complete nested timeline. In real traces, spans also show parent-child relationships and overlapping operations.

Here, Shopify is the obvious investigation target. You might need an upstream timeout, bounded retries, caching, or a background synchronization strategy.

For Node.js services, OpenTelemetry is a widely used option for traces and metrics. It can instrument HTTP requests and supported libraries, while custom spans capture application-specific operations.

Remember that a trace shows where time was spent, but you still need to understand why. A slow span might represent remote processing, connection establishment, queueing, or waiting for a connection from a local pool.

## 9. Debugging BullMQ and database incidents

Production debugging becomes easier when you separate the different kinds of waiting.

Imagine your BullMQ jobs are piling up, but the API itself is healthy.

Collect these measurements:

|
Signal

|

What it tells you

|
| --- | --- |
|

Waiting job count

|

Whether work is accumulating

|
|

Active job count

|

How much work workers are processing

|
|

Job processing duration

|

Whether individual jobs are getting slower

|
|

Failed and stalled jobs

|

Whether workers are failing or jobs are being recovered

|
|

Worker CPU and event-loop delay

|

Whether workers are overloaded

|
|

MySQL pool acquisition time

|

Whether jobs are waiting for database connections

|
|

MySQL query duration

|

Whether database execution is slow

|
|

Redis latency and connectivity

|

Whether queue operations are impaired

|

A growing queue does not necessarily mean BullMQ is broken.

Possible causes include a burst in job arrivals, a slow downstream API, insufficient worker capacity, MySQL connection exhaustion, or a CPU-bound processor.

For example, if jobs arrive at 120 per second and complete at 80 per second, the backlog grows by approximately 40 jobs per second while those rates persist. Increasing worker concurrency helps only if the bottleneck permits additional parallelism.

For a database issue, distinguish query execution time from connection-pool acquisition time. A query can execute in 10 ms yet take much longer end-to-end because the application waits for an available connection.

Senior debugging habit: measure the full operation, then break it into stages.

## 10. CloudWatch: turning Node.js diagnostics into operational signals

Since your services run on AWS, you can use CloudWatch Logs for structured logs and CloudWatch metrics and alarms for operational monitoring.

A useful dashboard could include:

- HTTP request rate, latency percentiles, and error rate.

- Container or host CPU and memory.

- Node.js heap usage, event-loop delay, and event-loop utilization.

- MySQL connection counts, query latency, and resource utilization.

- Redis latency, connections, memory, and errors.

- BullMQ queue depth, processing duration, failed jobs, and stalled jobs.

Not all of these are available automatically as native CloudWatch metrics. Application-level Node.js metrics and BullMQ measurements generally need instrumentation and a publishing path, such as a CloudWatch agent, custom metrics, or an OpenTelemetry pipeline.

### Example: useful structured logging

TypeScript

```
logger.error({
  message: "Reward job failed",
  jobId: job.id,
  campaignId: job.data.campaignId,
  durationMs,
  errorName: error.name,
  errorMessage: error.message,
});
```

Use consistent field names and avoid high-cardinality metric dimensions such as a unique request ID for every measurement. High-cardinality values are useful in logs and traces but can make metrics expensive or difficult to aggregate.

A CloudWatch alarm should correspond to a meaningful operational condition, such as sustained elevated error rate, increasing queue backlog, or high latency—not merely a metric crossing a threshold for a few seconds without context.

## 11. A repeatable production incident workflow

When an alert fires, follow a sequence instead of randomly changing infrastructure.

Step 1 — Establish impact

Which endpoints, tenants, regions, and jobs are affected? When did the issue start? Is it still getting worse?

Step 2 — Compare against a healthy baseline

Check latency percentiles, traffic, errors, CPU, memory, event-loop delay, and dependency metrics.

Step 3 — Localize the bottleneck

Use request traces, structured logs, database timings, queue metrics, and runtime profiles.

Step 4 — Mitigate safely

Reduce incoming load, disable a problematic feature, roll back a bad release, or isolate an unhealthy dependency where appropriate.

Step 5 — Verify and prevent recurrence

Confirm user-facing metrics recover, identify the root cause, add regression tests, and create an alert or diagnostic that catches the failure earlier.

During an active incident, mitigation may need to happen before the root cause is fully established. Record what you changed and verify the effect rather than assuming the mitigation worked.

## 12. Your checkpoint — investigate the incident

You're the senior engineer on call. Your team is waiting for your diagnosis.

## Production incident simulator

Choose the incident and explain how you would investigate it.

Incident A — CPU reaches 95%, HTTP p99 reaches 2 seconds, MySQL queries remain fast.

Incident B — RSS grows from 300 MB to 1.8 GB over several hours.

Incident C — BullMQ backlog grows, but API latency remains normal.

Incident D — HTTP p99 is 3 seconds, but event-loop delay is low.

### Your investigation target

Establish whether CPU-heavy JavaScript, GC, or another source of CPU contention is responsible. Compare CPU profiles with event-loop delay and request traces.

1. What do the symptoms suggest, and what do they not prove?

2. Which three measurements or diagnostic tools would you check first?

3. What would you do to mitigate the incident safely?

4. How would you prove the fix worked and prevent recurrence?

Review my incident investigation

## What you should now be able to explain in an interview

- Why logs, metrics, and traces answer different questions.

- Why p99 latency matters even when average latency is healthy.

- How to distinguish CPU saturation from slow database or upstream operations.

- How CPU profiles and heap snapshots help investigate performance and memory issues.

- How to diagnose growing BullMQ backlogs.

- How to turn production incidents into measurable prevention work.

Next: Lesson 16 — Capstone: Production-Grade Node.js Runtime Lab. We'll bring the curriculum together in one practical system, combining runtime diagnostics, concurrency, failure handling, security, and observability into a production-style investigation and improvement exercise.
