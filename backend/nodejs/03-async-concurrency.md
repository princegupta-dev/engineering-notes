---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, promises, concurrency, connection-pool, partial-failure]
---

# Async Concurrency: `Promise.all`, Limits & Partial Failure

> **Prev:** [Event loop](02-event-loop-and-microtasks.md) · **Next:** [Memory leaks](04-memory-leaks-and-gc.md) · **Related:** [Worker Threads vs BullMQ](06-worker-threads-vs-queues.md)

## TL;DR

- 3 independent 200 ms queries: sequential `await` ≈ **600 ms**, `Promise.all` ≈ **200 ms** (`max`, not `sum`).
- `Promise.all` **coordinates promises** — it creates no threads and **cancels nothing** when one rejects.
- Unbounded concurrency (`Promise.all(ids.map(...))` over 100s of items) → pool contention, DB overload, cascading timeouts. **Bound it**, or replace N queries with one bulk query.
- Decide explicitly which dependencies are **essential** (fail the request) vs **optional** (fallback + log).

## Recall questions

<details><summary>Does <code>Promise.all()</code> create threads?</summary>

No. The calls are evaluated (and their I/O started) before `Promise.all` waits. The I/O overlaps; all JS callbacks still run on the main thread. Expensive sync JS before a function returns its promise still blocks.

</details>

<details><summary>When is running queries concurrently the wrong choice?</summary>

- One depends on another's result.
- They must execute in order.
- They conflict over state or locks.
- The DB / connection pool can't handle the added load.
- Too many in flight → memory pressure / overload.

</details>

<details><summary>What can go wrong if 100 queries launch at once?</summary>

Connection-pool contention, higher latency, DB CPU/lock/IO pressure, memory from pending ops, timeouts + cascading retries, and `Promise.all` rejects on the first failure **without cancelling** the rest.

</details>

<details><summary>How do you control concurrency, and how do you pick the limit?</summary>

Concurrency limiter, bounded batches, or a worker pool. Tune from connection-pool size, query cost, DB capacity, overall traffic and measured latency — never a blind "10". Also consider replacing N+1 queries with one bulk query.

</details>

<details><summary>How do you make "rewards" optional in a dashboard endpoint?</summary>

Attach `.catch()` to the rewards promise that logs and returns `null`, pass it into `Promise.all` with the essential calls, and return `rewardsAvailable: rewards !== null`. Add a timeout — catching a rejection doesn't cancel or time-limit the operation.

</details>

## Gotchas

- Batching waits for the **slowest** item in each batch; a limiter that keeps N in flight is often more efficient for uneven durations.
- Catch only failures the business logic can safely handle; distinguish dependency failures from programming errors.

---

## Deep dive

### 1. Sequential `await` vs concurrent I/O

```ts
async getDashboard() {
  const user = await this.userService.getUser();
  const orders = await this.orderService.getOrders();
  const rewards = await this.rewardService.getRewards();

  return { user, orders, rewards };
}
```

Assume three independent queries of ~200 ms each, no pool contention.

```text
User:     0–200 ms
Orders: 200–400 ms
Rewards: 400–600 ms
Total:   ≈ 600 ms      (T_sequential ≈ 200 + 200 + 200)
```

Concurrent version:

```ts
async getDashboard() {
  const [user, orders, rewards] = await Promise.all([
    this.userService.getUser(),
    this.orderService.getOrders(),
    this.rewardService.getRewards(),
  ]);

  return { user, orders, rewards };
}
```

```text
T_concurrent ≈ max(200, 200, 200) = 200 ms   (+ overhead)
```

Actual latency includes application overhead, connection-pool waiting, network time, and database load.

### 2. When concurrency can be wrong

- One operation depends on another operation's result.
- Queries must execute in a particular order.
- Concurrent operations conflict over state or locks.
- The database or connection pool cannot handle the added load.
- Launching too many operations creates memory pressure or overload.

### 3. Controlling concurrency and database load

This can be dangerous:

```ts
const results = await Promise.all(userIds.map((id) => getUserData(id)));
```

If `userIds` has 100 entries, this can initiate 100 operations at once.

**Possible consequences**

- **Connection-pool contention:** only a limited number of operations can use connections at once; the rest wait.
- **Higher latency:** waiting for connections increases response time.
- **Database overload:** CPU, locks, I/O, or query capacity become bottlenecks.
- **Resource pressure:** pending operations consume memory.
- **Cascading failures:** timeouts and retries increase load further.
- **Fail-fast promise behavior:** `Promise.all()` rejects when one input rejects, but does not cancel operations already started.

**Illustrative batch limiter**

```ts
async function processInBatches<T, R>(
  items: T[],
  batchSize: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = [];

  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(batch.map(fn));

    results.push(...batchResults);
  }

  return results;
}
```

This limits each batch to `batchSize` concurrent operations and waits for the batch before starting the next. A concurrency limiter can keep a steady number in flight and may be more efficient for uneven durations.

**Do not blindly choose 10 or any fixed limit.** Tune based on connection-pool size, query cost, database capacity, overall traffic, and measured latency. Also consider whether one bulk query could replace 100 individual queries — avoiding an N+1 pattern can beat limiting concurrency.

### 4. Partial failure: essential vs optional dependencies

User data and orders are required; rewards are optional.

```ts
async getDashboard() {
  const rewardsPromise = this.rewardService
    .getRewards()
    .catch((error) => {
      this.logger.warn("Could not fetch rewards", error);
      return null;
    });

  const [user, orders, rewards] = await Promise.all([
    this.userService.getUser(),
    this.orderService.getOrders(),
    rewardsPromise,
  ]);

  return {
    user,
    orders,
    rewards,
    rewardsAvailable: rewards !== null,
  };
}
```

- User query fails → endpoint fails.
- Orders query fails → endpoint fails.
- Rewards query fails → endpoint returns essential data with `rewards: null`, `rewardsAvailable: false`.

**Production considerations**

- Add timeouts for optional dependencies that might hang.
- Use cancellation if the driver/API supports it.
- Log useful error context without exposing secrets or sensitive data.
- Distinguish expected dependency failures from programming errors.
- Document the response schema and fallback semantics.
- Consider caching optional data if stale data is acceptable.

Catching a rejection does not itself cancel or time-limit the underlying operation.

### Interview-ready answer

> Use concurrency to reduce latency — `Promise.all` turns sum-of-latencies into max-of-latencies for independent I/O — but it's coordination, not threads, and it doesn't cancel the others on failure. Bound it to protect the connection pool and database, prefer bulk queries over N+1, and explicitly define which dependencies are essential and which get a fallback with a timeout.
