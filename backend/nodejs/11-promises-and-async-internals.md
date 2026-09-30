## 1. Scenario 1 — Sequential `await` vs `Promise.all()`

Your answer:

> If sequentially, then maybe 600ms, but with Promise.all then maybe 300ms.

Correct. Your reasoning about independent operations is also correct.

Assuming the operations take 100 ms, 200 ms, and 300 ms:

- Sequential: 100+200+300=600 ms100+200+300=600\text{ ms}100+200+300=600 ms

- Concurrent: approximately max⁡(100,200,300)=300 ms\max(100,200,300)=300\text{ ms}max(100,200,300)=300 ms

Your statement that `await` waits for the outcome before proceeding is right, but be precise about what waits: the current async function's continuation waits, not the entire Node.js JavaScript thread.

Compare these implementations:

TypeScript

```
// Sequential
const a = await getA();
const b = await getB();
const c = await getC();
```

TypeScript

```
// Concurrent
const [a, b, c] = await Promise.all([
  getA(),
  getB(),
  getC(),
]);
```

In the second example, the function calls are evaluated and each operation is initiated before execution reaches the `await Promise.all(...)`.

One qualification: concurrency is appropriate only if the operations can run independently and the available resources can handle the load. Real-world latency may also vary because of connection pools, CPU work, and network contention.

Interview-ready answer

Sequential `await` makes each subsequent operation wait for the previous result, so independent operation latencies accumulate. `Promise.all()` allows independent asynchronous operations to overlap, making total latency approximately the duration of the slowest operation. It improves elapsed time, not necessarily the execution speed of each operation.

## 2. Scenario 2 — What if one of 5,000 API calls fails?

Your answer:

> If external API fails for one user, the entire function is useless then; instead, we can use `Promise.allSettled`.

You've identified an important option, but there are two separate problems here.

### Problem A: Failure semantics

`Promise.all()` rejects when any input promise rejects. It does not return the successful results as a completed result array.

`Promise.allSettled()` waits for every promise to settle and returns an outcome for each one. This is useful when partial success is acceptable.

TypeScript

```
const results = await Promise.allSettled(
  userIds.map((id) => externalApi.fetchUser(id))
);

for (const result of results) {
  if (result.status === "fulfilled") {
    // Process successful result
    console.log(result.value);
  } else {
    // Record or handle this failure
    console.error(result.reason);
  }
}
```

But `Promise.allSettled()` does not automatically retry failed calls, and it does not make them faster or limit their number.

### Problem B: Concurrency overload

Launching 5,000 requests simultaneously can exceed an API's rate limit, exhaust connection-pool capacity, or increase memory pressure.

Even if you switch to `Promise.allSettled()`, you could still overwhelm the external service.

A more production-conscious approach is to limit concurrency:

TypeScript

```
import pLimit from "p-limit";

const limit = pLimit(20);

const results = await Promise.allSettled(
  userIds.map((id) =>
    limit(() => externalApi.fetchUser(id))
  )
);
```

This limits the number of active scheduled calls to 20. For a very large dataset, you should also consider bounded batches or streaming results rather than retaining every result in memory.

For durable background work, a queue such as BullMQ can provide controlled worker concurrency and configured retries.

Interview-ready answer

`Promise.all()` is appropriate when all results are required and a single rejection should reject the aggregate promise. If partial success is acceptable, I can use `Promise.allSettled()` and handle each outcome individually. For thousands of external API calls, I would also introduce bounded concurrency, rate limiting, timeouts, and appropriate retry policies. The choice depends on the business requirement, not just which Promise method is available.

## 3. Scenario 3 — Why doesn't this `catch` work?

Your answer:

> Because we haven't used `await` inside async function, so it will be in pending state only.

This is the main misconception to fix. The promise does not remain pending merely because you didn't use `await`.

Consider:

JavaScript

```
function getData() {
  return Promise.reject(new Error("Database failed"));
}

async function example() {
  try {
    return getData();
  } catch (error) {
    console.error("Caught:", error);
  }
}

example().catch((error) => {
  console.log("Outer catch:", error.message);
});
```

Output:

```
Outer catch: Database failed
```

Why?

1. `getData()` returns a promise.

2. `return getData()` returns that promise from the `try` block.

3. The promise rejects asynchronously from the perspective of the caller's promise handling.

4. The local `catch` does not catch the rejection because no `await` caused that rejection to be thrown into the local `try` block.

5. The async function's returned promise adopts the returned promise's eventual outcome, so the outer `.catch()` handles the rejection.

Now add `await`:

JavaScript

```
async function example() {
  try {
    return await getData();
  } catch (error) {
    console.error("Caught locally:", error.message);
    throw error;
  }
}
```

Here, the rejection from `getData()` is thrown at the `await` expression, inside the `try` block, so the local `catch` can handle it.

An even simpler example:

JavaScript

```
async function getCount() {
  return 5;
}

const result = getCount();

console.log(result); // Promise fulfilled with 5
```

The returned promise is not stuck in the pending state. An async function always returns a promise, and that promise can fulfill or reject even if you don't explicitly use `await`.

Interview-ready answer

A `try/catch` catches synchronous exceptions and rejections thrown into its scope by `await`. If I return a promise without awaiting it, a later rejection is not caught by that local `catch`; instead, it propagates through the returned promise to the caller. I use `await` inside the `try` when I need local rejection handling, or return the promise directly when I want the caller to handle it.

# Lesson 8 — Promises and Async Internals

Node.js Internals · Level 8 of 16 · Senior Backend Engineering

Prince, in the previous lessons, we learned how Node.js handles networking, how the event loop schedules callbacks, and why asynchronous I/O lets one JavaScript thread manage many connections.

Now let's answer a question that matters in almost every production backend:

When you write `async/await`, what is actually happening inside Node.js—and how can incorrect promise handling create production incidents?

We'll use examples from a NestJS backend that talks to MySQL, Redis, and third-party APIs.

## 1. The story: three services, one API request

Imagine your Fills e-commerce application has an endpoint:

`GET /products/123`

To build the response, your backend needs three things:

MySQL

Fetch product details · 80 ms

Redis

Fetch wishlist status · 10 ms

Shipping API

Fetch delivery estimate · 200 ms

Assume all three operations are independent and their durations are stable.

The engineering decision is whether to wait for each operation sequentially or start all three without waiting for the others to finish.

## 2. Sequential `await` vs `Promise.all`

### Approach A — Sequential execution

TypeScript

```
async function getProductPage(productId: string) {
  const product = await productService.findById(productId);

  const wishlist = await redis.get(`wishlist:${productId}`);

  const delivery = await shippingApi.getEstimate(productId);

  return { product, wishlist, delivery };
}
```

What happens?

0 ms

Request starts

MySQL query

80 ms

Redis query starts after MySQL

10 ms

Shipping API starts after Redis

200 ms

Approximate total

## 290 ms

Each `await` prevents the function from proceeding until its awaited promise settles. Since the next operation isn't even started until the previous one completes, the waiting times accumulate.

### Approach B — Concurrent execution

TypeScript

```
async function getProductPage(productId: string) {
  const [product, wishlist, delivery] = await Promise.all([
    productService.findById(productId),
    redis.get(`wishlist:${productId}`),
    shippingApi.getEstimate(productId),
  ]);

  return { product, wishlist, delivery };
}
```

Concurrent execution

All three operations start without waiting for the others to finish.

MySQL

80 ms

Redis

10 ms

Shipping

200 ms

Approximate total

## 200 ms

Illustrative timings; assumes independent operations and no significant scheduling or resource contention.

The response is approximately as fast as the slowest operation, rather than the sum of all three.

Senior-engineer insight: `Promise.all()` doesn't make each operation individually faster. It overlaps their waiting time.

It also doesn't automatically create threads or make synchronous CPU-heavy JavaScript parallel.

## 3. What exactly is a Promise?

A Promise is a JavaScript object representing the eventual result or failure of an operation.

It has three states:

Pending

Still waiting for a result

Fulfilled

Completed successfully

Rejected

Completed with failure

Let's see it in code:

JavaScript

```
const promise = new Promise((resolve, reject) => {
  setTimeout(() => {
    resolve("Product fetched");
  }, 100);
});

promise.then((result) => {
  console.log(result);
});
```

Here's the important distinction:

- `resolve(value)` fulfills the promise with a value, unless it adopts another promise or thenable.

- `reject(error)` rejects the promise.

- `.then()` registers a reaction to the result.

- `.catch()` handles a rejection in the promise chain.

A Promise does not itself perform asynchronous work. The executor passed to `new Promise(...)` runs synchronously; the timer in this example schedules the later callback.

For example:

JavaScript

```
console.log("A");

const p = new Promise((resolve) => {
  console.log("B");
  resolve("C");
});

p.then((value) => console.log(value));

console.log("D");
```

Output:

```
A
B
D
C
```

Why?

1. `A` prints.

2. The Promise executor runs immediately, so `B` prints.

3. The promise is fulfilled, and its `.then()` reaction is scheduled as a microtask.

4. The current synchronous code continues, so `D` prints.

5. Once the synchronous execution finishes, the promise reaction runs, printing `C`.

Remember: a fulfilled promise doesn't mean its `.then()` callback runs immediately.

## 4. What does `await` actually do?

Consider:

JavaScript

```
async function fetchData() {
  console.log("1");

  const result = await Promise.resolve("2");

  console.log(result);
}

fetchData();

console.log("3");
```

Output:

```
1
3
2
```

When `fetchData()` reaches `await`, its execution suspends until the awaited value has been processed. The rest of that async function resumes through promise-job scheduling.

The caller doesn't have to wait synchronously for the entire async function to finish.

A useful mental model:

Run synchronous JavaScript

Reach `await`

Suspend this async function's continuation

Other JavaScript can run

The event loop can process other work when eligible

Resume the async function

Continue with the fulfilled value or throw the rejection

Two critical qualifications:

- `await` doesn't block the entire Node.js thread while waiting for a normal asynchronous operation.

- `await` doesn't magically make synchronous work asynchronous. A CPU-heavy function still blocks the JavaScript thread.

Also, every call to an `async` function returns a Promise, even when you return an ordinary value:

JavaScript

```
async function getCount() {
  return 5;
}

console.log(getCount()); // Promise, not the number 5
```

Conceptually, `return 5` fulfills the returned promise with `5`.

## 5. Promise concurrency is not unlimited concurrency

Now let's introduce a production problem.

Suppose your backend needs to check 10,000 product IDs against an external API.

A developer writes:

TypeScript

```
await Promise.all(
  productIds.map((id) => shippingApi.getEstimate(id))
);
```

This starts all 10,000 operations without waiting for each one individually.

That may overload:

- The third-party API's rate limits.

- Your outbound connection pool.

- Memory, due to the large number of in-flight promises and associated data.

- Your own service's ability to handle other requests.

`Promise.all()` doesn't impose a concurrency limit.

A concurrency limiter can bound the number of active operations:

TypeScript

```
import pLimit from "p-limit";

const limit = pLimit(20);

const results = await Promise.all(
  productIds.map((id) =>
    limit(() => shippingApi.getEstimate(id))
  )
);
```

Here, at most 20 of these scheduled operations run concurrently through this limiter. This does not necessarily mean 20 network connections; the HTTP client has its own connection-pool settings.

For very large workloads, also consider batching, streaming results, rate limits, cancellation, and queue-based processing rather than creating a promise for every item at once.

For durable jobs such as sending reward notifications or processing loyalty payouts, BullMQ may be more suitable because it supports background processing, retries, and controlled worker concurrency.

## 6. The production trap: `Promise.all()` and failures

Imagine a reward endpoint performs three independent actions:

TypeScript

```
const [reward, profile, campaign] = await Promise.all([
  rewardService.getReward(userId),
  userService.getProfile(userId),
  campaignService.getCampaign(campaignId),
]);
```

If any one promise rejects, `Promise.all()` rejects with that failure.

But there's a subtle detail: it does not automatically cancel the other operations.

If the campaign lookup fails, the profile query or reward query may still be running. They might still consume resources or even perform side effects.

### When should you use each method?

|
Method

|

Behavior

|

Typical use

|
| --- | --- | --- |
|

`Promise.all()`

|

Rejects when an input rejects; otherwise returns all results

|

All results are required

|
|

`Promise.allSettled()`

|

Waits for every input to settle and reports each outcome

|

Independent tasks where partial success matters

|
|

`Promise.race()`

|

Settles with the first input to settle

|

Racing operations or implementing a timeout wrapper

|
|

`Promise.any()`

|

Fulfills with the first fulfilled input; rejects if all inputs reject

|

Trying alternative providers

|

Example: optional dashboard widgets.

TypeScript

```
const results = await Promise.allSettled([
  getOrders(userId),
  getRecommendations(userId),
  getRecentlyViewed(userId),
]);

const [orders, recommendations, recentlyViewed] = results;
```

You can return orders even if recommendations fail, provided the business rules permit it. Handle each result's `status` explicitly.

Don't replace every `Promise.all()` with `Promise.allSettled()`. If a financial operation requires every result to succeed, silently accepting partial completion may be incorrect.

Important: `Promise.race()` is not a cancellation mechanism. If you race an API request against a timeout promise, the request may continue after the timeout wins. Use the underlying API's cancellation support, such as `AbortController`, where available.

## 7. Error propagation: the hidden bug in async code

Consider a common mistake:

TypeScript

```
async function getProduct(id: string) {
  try {
    return await productService.findById(id);
  } catch (error) {
    console.error(error);
    throw error;
  }
}
```

This works, but if the `catch` only logs and rethrows the same error, the extra `try/catch` may be unnecessary.

The more dangerous mistake is forgetting to await a promise inside the `try` block:

TypeScript

```
async function getProduct(id: string) {
  try {
    return productService.findById(id);
  } catch (error) {
    console.error("Product lookup failed", error);
    throw error;
  }
}
```

If `findById()` returns a promise that later rejects, this `catch` will not catch that asynchronous rejection. The function returns the promise before it rejects.

There are two valid approaches:

TypeScript

```
// Approach 1: await inside try/catch
async function getProduct(id: string) {
  try {
    return await productService.findById(id);
  } catch (error) {
    logger.error({ error }, "Product lookup failed");
    throw error;
  }
}
```

TypeScript

```
// Approach 2: return the promise directly
function getProduct(id: string) {
  return productService.findById(id);
}
```

Use the first if you need to handle or transform the rejection locally. Use the second if you simply want to propagate the promise to the caller.

One more production issue: don't swallow errors accidentally.

TypeScript

```
try {
  await payoutService.processPayout(payoutId);
} catch (error) {
  logger.error({ error, payoutId }, "Payout failed");
  // Dangerous if the caller assumes the payout succeeded.
}
```

Logging alone does not communicate failure. Rethrow the error or return an explicit failure result according to the application's error-handling contract.

For money movement and reward processing, combine appropriate error propagation with idempotency and durable state tracking. A timeout or rejection doesn't necessarily prove that a remote side effect did not happen.

## 8. A senior backend engineer's checklist

Before using promises in a production endpoint, ask:

Dependency

Can these operations actually run independently?

Concurrency

Could this start too many database queries or HTTP requests?

Failure

Should one failure fail the entire operation?

Cancellation

Can remaining work be stopped if the request is abandoned?

Side effects

Could a retry duplicate a payout, order, or notification?

Observability

Do logs and metrics reveal which operation failed and how long it took?

## 9. Interview-ready explanation

If an interviewer asks, “How do Promises and async/await work in Node.js?”, you can say:

> A Promise represents the eventual fulfillment or rejection of an asynchronous computation. The `.then()` and `.catch()` handlers execute through promise-job scheduling, and `async/await` provides syntax for composing these asynchronous operations. When an async function reaches `await`, its continuation is suspended, allowing other eligible JavaScript work to proceed. `Promise.all()` enables concurrency when operations are independent, but it does not limit concurrency or automatically cancel other operations when one rejects. In production, I consider resource limits, failure semantics, cancellation, and idempotency rather than treating promises as a guarantee of parallel execution.

## 10. Checkpoint — apply the concepts

Scenario 1

Your API performs three independent calls taking 100 ms, 200 ms, and 300 ms. Roughly how long would sequential `await` take versus `Promise.all()`? Explain why.

If sequentially, then maybe 600ms, but with promise.all then maybe 300ms. Because await waits for the outcome of the request before processing other instructions. but promise.all execute simultaneously all the request. if requests are independent then we can use promise.all

Scenario 2

A developer uses `Promise.all()` to call an external API for 5,000 users. What can go wrong, and how would you redesign it?

If external api's fails for one user, entire function is useless then, iinsead of we can use promise.allSetteled

Scenario 3

Why might this `catch` fail to handle a rejected promise?

JavaScript

```
try {
  return service.getData();
} catch (error) {
  logger.error(error);
}
```

Becauase we haven't used await inside async funciton, so it will be in pending state only
