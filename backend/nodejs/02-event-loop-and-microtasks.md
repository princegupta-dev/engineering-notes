---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-03
tags: [nodejs, event-loop, microtasks, nextTick, promises, timers]
---

# Event Loop: `nextTick`, Promises, Timers & `setImmediate`

> **Prev:** [Runtime & call stack](01-runtime-and-call-stack.md) · **Next:** [Async concurrency](03-async-concurrency.md)

## TL;DR

- Order of priority: **sync code → `nextTick` queue → promise microtasks → event-loop phases** (timers, poll, check/`setImmediate`…).
- A `nextTick` scheduled *inside* a promise callback does **not** cut in front of promise reactions already queued.
- Top-level `setTimeout(fn, 0)` vs `setImmediate` order is **not guaranteed**.
- CommonJS and ES modules can differ at top level. Never say "`nextTick` always runs first".

## Recall questions

<details><summary>Predict the output (the 1–8 snippet below)</summary>

`1 8 7 5 6` is guaranteed. Then either `2 3 4` or `4 2 3` — top-level timer vs immediate order is not guaranteed; `3` always follows `2`.

</details>

<details><summary>Why does 7 (nextTick) print before 5 (promise)?</summary>

In CommonJS at the top-level checkpoint, Node processes the `process.nextTick()` queue before promise microtasks.

</details>

<details><summary>Promise A logs "A" and schedules nextTick "B"; Promise C logs "C". Output?</summary>

`A C B`. The promise-microtask queue keeps draining (C was already queued) before Node processes the newly scheduled nextTick.

</details>

<details><summary>Does <code>setTimeout(fn, 0)</code> run immediately?</summary>

No. It runs when the timer is eligible **and** the event loop reaches the timers phase.

</details>

<details><summary>What's the danger of recursive <code>process.nextTick()</code>?</summary>

It can starve I/O and all other event-loop work, because the nextTick queue is drained before the loop moves on.

</details>

## Gotchas

- Scheduling order depends on **execution context** (CJS vs ESM, which queue is currently draining), not a single universal rule.
- The mental model (sync → nextTick → microtasks → loop phases) is useful, not a claim that every callback uses one queue.

---

## Deep dive

### The classic example (CommonJS)

```js
console.log("1");

setTimeout(() => {
  console.log("2");
  Promise.resolve().then(() => console.log("3"));
}, 0);

setImmediate(() => {
  console.log("4");
});

Promise.resolve().then(() => {
  console.log("5");
  process.nextTick(() => console.log("6"));
});

process.nextTick(() => {
  console.log("7");
});

console.log("8");
```

**Guaranteed prefix:** `1 8 7 5 6`

**Possible complete outputs:**

| Output A | Output B |
| -------- | -------- |
| 1 8 7 5 6 **2 3 4** | 1 8 7 5 6 **4 2 3** |

### Why?

1. Synchronous statements execute first, in program order: `1`, `8`.
2. In this CommonJS top-level example, Node.js processes the `process.nextTick()` queue before promise microtasks at the relevant checkpoint, so `7` precedes `5`.
3. The promise callback prints `5` and schedules `6`.
4. Node.js does not interrupt the currently draining promise-microtask queue to run that new `nextTick` callback. With no other promise reaction queued behind it, `6` runs before the event-loop callbacks.
5. The timer callback prints `2` and schedules a promise reaction that prints `3`.
6. `setImmediate()` runs in the event loop's **check** phase. Its order relative to a top-level zero-delay timer is not guaranteed.

### Important counterexample

```js
Promise.resolve().then(() => {
  console.log("A");
  process.nextTick(() => console.log("B"));
});

Promise.resolve().then(() => {
  console.log("C");
});
```

Expected in modern Node.js:

```text
A
C
B
```

The promise reaction that prints `C` was already queued. Node.js continues draining the promise-microtask queue before processing the `nextTick` callback scheduled from inside the first reaction.

### Which parts depend on execution context?

| Operation                                        | Behavior                                                          |
| ------------------------------------------------ | ----------------------------------------------------------------- |
| Synchronous statements                           | Execute in program order                                          |
| Top-level `nextTick` in CommonJS                 | Generally runs before pending promise reactions at the checkpoint |
| Promise reactions                                | Run as microtasks in queue order                                  |
| `nextTick` scheduled inside a promise reaction   | Does not interrupt the currently draining promise queue           |
| `setTimeout(fn, 0)`                              | Runs when eligible and processed by the event loop                |
| Top-level `setImmediate()` vs zero-delay timer   | Relative order is not guaranteed                                  |
| ES modules vs CommonJS                           | Top-level scheduling behavior can differ                          |

### Scheduling caveats

- `setTimeout(fn, 0)` does not mean "run immediately".
- The relative order of a top-level `setImmediate()` and `setTimeout(fn, 0)` is not guaranteed.
- CommonJS and ES modules can differ in top-level scheduling because ES module evaluation uses promise-related machinery.
- Avoid recursive `process.nextTick()` scheduling: it can starve I/O and other event-loop work.

**Mental model:** synchronous JavaScript → Node.js checkpoints for `nextTick` and promise microtasks → event-loop callbacks when their scheduling conditions are met.

### Interview-ready answer

> Synchronous code runs first. At each checkpoint Node drains the `nextTick` queue and the promise microtask queue before moving to event-loop phases such as timers and `setImmediate`'s check phase. But the details depend on context: a `nextTick` scheduled inside a promise callback waits until the current promise queue drains, ESM and CommonJS differ at top level, and top-level `setTimeout(0)` vs `setImmediate` has no guaranteed order. I never reduce it to "`nextTick` always runs first".
