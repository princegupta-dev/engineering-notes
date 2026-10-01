# Lesson 12 — Worker Pools and Concurrency Patterns

Node.js Internals Mastery · Senior Backend Engineer Track

Today, we'll learn how to handle CPU-heavy work without making your API unresponsive, how worker pools operate, and why Worker Threads, the libuv thread pool, BullMQ, and asynchronous I/O solve different problems.

We'll use examples from your Node.js/TypeScript backend: reward calculations, large CSV imports, loyalty campaigns, and report generation.

## 1. The production incident: your API is freezing

Imagine your Fills application has an endpoint that imports 100,000 products from a CSV file.

TypeScript

```
@Post("import")
async importProducts(@UploadedFile() file: Express.Multer.File) {
  const products = parseAndValidateCsv(file.buffer);

  return this.productService.importProducts(products);
}
```

Suppose `parseAndValidateCsv()` performs substantial synchronous parsing, validation, and transformation on the main JavaScript thread.

While that computation runs, the same Node.js process may be unable to process other JavaScript callbacks promptly.

### What your customers experience

Request A: CSV import

Consumes the main thread with CPU-heavy work.

Blocking

Request B: Product listing

Even a simple request can wait for JavaScript execution to resume.

Delayed

Request C: OTP verification

Its callback may also be delayed, even if Redis responds quickly.

Delayed

The important distinction is that Node.js can handle many concurrent I/O operations, but a long-running synchronous JavaScript computation can block other JavaScript work on that event loop.

The solution depends on the work you're doing.

## 2. Four mechanisms that solve four different problems

A. Asynchronous I/O

Best for waiting on I/O

Use for MySQL queries, Redis commands, HTTP requests, and network sockets. Node.js can do other work while the operation is pending.

Example: waiting for Shopify's API response.

B. Worker Threads

Best for CPU-heavy JavaScript

Run JavaScript computation on separate threads so the main event loop can remain responsive.

Example: CPU-intensive reward calculations or data transformations.

C. libuv thread pool

Runtime-managed pool

Node.js uses this pool for certain operations, including many filesystem operations, `crypto` operations, and compression operations. It does not automatically execute arbitrary synchronous JavaScript there.

Example: asynchronous password hashing with a supported crypto API.

D. BullMQ and background workers

Durable job processing

Move work into a queue that separate worker processes can consume, with job state, retries, concurrency controls, and other queue features.

Example: processing a loyalty campaign's payout jobs reliably.

Senior-level insight: these mechanisms aren't interchangeable. Worker Threads provide parallel JavaScript execution within a process; BullMQ coordinates jobs across workers and processes using Redis; asynchronous I/O avoids blocking while waiting for external operations.

BullMQ itself does not magically make CPU-heavy synchronous code non-blocking. Its worker can still block its own event loop if it performs heavy computation.

## 3. What actually happens inside a Worker Thread?

Think of your Node.js process as a restaurant.

- The main thread receives API requests and coordinates work.

- A worker thread is another chef who can perform a CPU-intensive task independently.

- A worker pool is a team of reusable chefs.

- A task queue holds work until a chef is available.

![How Worker Threads Bring Multithreading to Node.js](https://images.openai.com/static-rsc-4/8vRrlp-iiIdouEh5rJ8giKFFC2zWccQTDlJhyPnAtO88O5g5BSg58_QbnOCDpY8UedRq7goQ25tU7iO3deuN6Yw0QNONOEuZ2AP42OeQ-2sxHwb4DCqpK9iD2ALJawBQTrcT0sUsAJEPXAQqj3YXWStHAsdybUBIA-I_mcWOeAA?purpose=inline)

A Worker Thread has its own JavaScript execution environment and event loop. It can perform computation in parallel with the main thread, subject to available CPU resources.

The usual workflow is:

Main thread

Receives request and validates input

Bounded task queue

Waits when all workers are busy

Worker 1

Task A

Worker 2

Task B

Worker N

Task C

Main thread receives results

Continues handling API requests while computation runs elsewhere

One important detail: workers have separate JavaScript heaps by default. Sending data to a worker may involve structured cloning, which costs time and memory. Transferable objects and shared memory can help in appropriate cases.

## 4. Your first Worker Thread in TypeScript

Let's implement a CPU-intensive calculation that simulates computing a reward score over a large input.

Create `reward.worker.ts`:

TypeScript

```
import { parentPort, workerData } from "node:worker_threads";

if (!parentPort) {
  throw new Error("This module must run inside a Worker");
}

const { values } = workerData as { values: number[] };

let score = 0;

for (const value of values) {
  // Illustrative CPU-heavy calculation
  for (let i = 0; i < 100; i++) {
    score += Math.sqrt(value * value + i);
  }
}

parentPort.postMessage({ score });
```

Then create `reward.service.ts`:

TypeScript

```
import { Worker } from "node:worker_threads";
import { join } from "node:path";

export function calculateRewardScore(
  values: number[],
): Promise<number> {
  return new Promise((resolve, reject) => {
    const worker = new Worker(
      join(__dirname, "reward.worker.js"),
      {
        workerData: { values },
      },
    );

    worker.once("message", ({ score }) => {
      resolve(score);
    });

    worker.once("error", reject);

    worker.once("exit", (code) => {
      if (code !== 0) {
        reject(
          new Error(`Worker exited with code ${code}`),
        );
      }
    });
  });
}
```

This example assumes your TypeScript build emits `reward.worker.js` next to the service file. Your build configuration must ensure the worker file is compiled and deployed correctly.

### What does this code accomplish?

1. The main thread creates a worker.

2. The worker receives the input and performs the computation.

3. The worker posts the result.

4. The main thread resolves the promise.

The main thread remains free to process other JavaScript callbacks during the worker's computation.

However, this is a learning example, not production-ready pool code. It creates a new thread per call, has no queue limit or task timeout, and doesn't fully coordinate message, error, and exit events. We will address the architecture next.

## 5. Why creating one worker per request is a bad design

Imagine 500 requests arrive simultaneously, each asking for a CPU-heavy report.

If your code creates a new Worker for every request, you could create hundreds of threads. Each worker introduces memory, scheduling, initialization, and communication overhead.

### Unbounded workers

New requests continually create workers → memory and scheduling overhead grow.

### Bounded worker pool

Worker 1

Worker 2

Worker 3

Bounded queue

Extra work waits; excess work is rejected or deferred.

A pool reuses a fixed number of workers instead of starting a new thread for every task.

A useful initial architecture is:

- A fixed number of workers.

- At most one CPU-intensive task per worker at a time.

- A bounded waiting queue.

- A defined overload policy.

- Task timeouts and worker failure handling.

- Metrics for queue depth, task duration, worker utilization, and failures.

The right pool size depends on CPU availability, task characteristics, memory usage, and the other work your process must perform. More workers do not always mean more throughput.

## 6. The hidden problem: queueing and overload

Suppose your service can process 100 CPU-heavy tasks per second, but requests arrive at 150 tasks per second.

Your backlog grows by roughly 50 tasks per second while that imbalance persists. A larger queue can absorb a temporary burst, but it cannot fix a sustained capacity shortage.

This is why a queue needs an explicit capacity and overload policy.

|
Policy

|

Behavior

|

Trade-off

|
| --- | --- | --- |
|

Reject

|

Return an overload response, such as HTTP 429 or 503

|

Client may need to retry

|
|

Bounded wait

|

Accept only up to a queue limit

|

Requests can wait longer

|
|

Durable background queue

|

Store jobs for later processing

|

Results may be delayed

|
|

Scale out

|

Add worker capacity or replicas

|

Costs more and still needs limits

|

A senior engineer thinks about the entire workload, not just the number of threads.

For an interactive API, it may be better to reject excess computation quickly than to accept every request and make every customer's response slow.

For a large campaign import, it may be better to accept the job, return `202 Accepted` with a job ID, and process it asynchronously.

## 7. Worker Threads vs BullMQ: your loyalty platform example

Imagine your GPI loyalty platform needs to process 100,000 eligible retailers.

Each retailer's reward calculation requires several steps.

## Recommended separation of responsibilities

API layer

Accept the campaign request

Validate input, authorize the caller, create a campaign record, and enqueue a job.

BullMQ + Redis

Manage background jobs

Track pending work, retries, failures, and processing status.

Job worker

Process campaign batches

Load data in bounded batches, compute rewards, and persist results using safe database operations.

Use Worker Threads only where justified

If reward computation is genuinely CPU-heavy, offload that portion to a bounded thread pool. If most time is spent waiting for MySQL or external APIs, focus on I/O concurrency and database efficiency instead.

### Why not just use BullMQ concurrency?

BullMQ's concurrency setting lets a worker process multiple jobs concurrently. For jobs that spend most of their time awaiting I/O, this can improve throughput because Node.js can handle other work during those waits.

But consider this:

TypeScript

```
new Worker(
  "reward-calculation",
  async (job) => {
    // This is synchronous CPU-heavy JavaScript.
    const result = calculateMillionsOfValues(job.data);

    return result;
  },
  {
    concurrency: 10,
  },
);
```

Even though `concurrency` is 10, that synchronous calculation blocks the worker's event loop while it runs. The other jobs do not gain parallel JavaScript execution simply because the concurrency number is 10.

For CPU-heavy jobs, options include:

- Offload the computation to a Worker Thread pool.

- Run separate worker processes, with bounded parallelism.

- Use a BullMQ processor configuration that isolates CPU-heavy work in separate processes, where supported by your setup.

BullMQ is the job orchestration layer; the execution strategy determines where the computation actually runs.

One more production concern: retries can cause the same job's business operation to run more than once. Reward payouts and other financial operations therefore need idempotency, transaction boundaries, and appropriate uniqueness constraints.

## 8. Choosing the right mechanism: a decision framework

Use this when reviewing a production performance issue.

## Choose an execution strategy

1. What dominates the work?

Waiting for a database, network, or API

CPU-heavy JavaScript computation

Filesystem, compression, or supported crypto operations

2. When must the work finish?

During an interactive request

Can finish in the background with job tracking and retries

3. How will you control incoming work?

Bounded concurrency and a queue limit

Durable queue with retry and overload policies

### Suggested approach

Worker Threads or separate worker processes are candidates for the CPU-heavy portion. Use a bounded Worker Thread pool and define an overload response for interactive requests.

Volume policy: Limit concurrent work and reject or defer excess tasks.

## 9. Interview-ready answer

Question: How would you handle CPU-intensive work in Node.js without blocking the event loop?

A strong senior-level answer:

> Node.js handles asynchronous I/O efficiently, but CPU-intensive synchronous JavaScript can block the main event loop and increase request latency. I would first profile the workload to establish whether the bottleneck is CPU computation, database latency, or external I/O.
>
> For CPU-heavy JavaScript, I would use Worker Threads or separate worker processes. I would generally reuse workers through a bounded pool rather than create a new thread for every request. The design would include bounded queues, overload handling, timeouts, error recovery, and metrics.
>
> For durable background operations, such as processing a large loyalty campaign, I would use BullMQ to manage jobs, retries, and processing status. If the job contains CPU-heavy computation, I would offload that part separately. I would also make business operations idempotent because retries can result in repeated execution.
>
> Finally, I would load-test the solution and compare throughput, event-loop delay, p95/p99 latency, queue depth, and CPU utilization before and after the change.

## 10. Your checkpoint — production scenarios

Answer in your own words. Focus on the reasoning, not memorizing definitions.

Scenario 1

Your NestJS API generates a large Excel report. While the report is being generated, unrelated API requests become slow. Would you choose asynchronous I/O, Worker Threads, or BullMQ? Explain your decision and what you would investigate first.

Scenario 2

A BullMQ worker has `concurrency: 20`, but CPU-heavy JavaScript tasks execute slowly and block one another. Why isn't the concurrency setting enough, and what architecture would you consider?

Scenario 3

Your campaign processor receives 1,000 jobs per second but can finish only 600 per second. What happens to the queue over time, and what controls would you introduce?

Scenario 4

A reward payout job fails after the payment provider processes the payout, but before your worker records success. When BullMQ retries, how would you prevent paying the retailer twice?

Review my answers

Once we review these, we'll move to Lesson 13 — Error Handling and Process Lifecycle, covering uncaught exceptions, unhandled promise rejections, graceful shutdown, signals, and what happens when a production Node.js process crashes.
