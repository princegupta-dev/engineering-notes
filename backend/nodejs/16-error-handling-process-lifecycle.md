# Lesson 13 — Error Handling and Process Lifecycle

Node.js Internals Mastery · Senior Backend Engineer Track

Today, we'll investigate a question every senior backend engineer must be able to answer:

What happens when a production Node.js application encounters an unexpected error, receives a shutdown signal, or crashes while processing a request?

We'll connect the concepts to your NestJS APIs, BullMQ workers, Redis, MySQL, and AWS deployments.

## 1. The production incident: your application is shutting down

Imagine your loyalty platform is processing reward payouts. Your Node.js service receives a termination signal because a new deployment is starting.

At that moment:

- Some HTTP requests are still running.

- A MySQL transaction may be in progress.

- BullMQ jobs may be processing.

- Redis connections and database pools are open.

- New requests may still arrive until traffic is drained.

If the application exits immediately, requests can fail and jobs can be interrupted. If it ignores shutdown indefinitely, deployment may stall.

A production service needs a controlled lifecycle: start, operate, handle failures, drain traffic, finish or safely abandon work, release resources, and exit.

## Node.js process lifecycle

1. Startup

Load configuration, connect dependencies, initialize the server.

2. Serving traffic

Handle requests, timers, background jobs, and I/O.

3. Failure or shutdown signal

Handle expected errors; initiate graceful shutdown when requested.

4. Drain and release

Stop accepting work, finish or safely interrupt in-flight work, close resources.

5. Process exits

The process manager can replace it with a healthy instance.

One important distinction: a graceful shutdown is a planned lifecycle event. An unrecoverable process failure is different; your code may not get an opportunity to clean up.

## 2. First principle: not all errors should be handled the same way

Consider three incidents in your backend:

1. A customer enters an invalid OTP.

2. Shopify times out while your service is fetching products.

3. Your application encounters an unexpected `TypeError` because an internal invariant has been violated.

These are all errors, but their recovery strategies differ.

|
Error category

|

Example

|

Appropriate response

|
| --- | --- | --- |
|

Expected business error

|

Invalid OTP, coupon already used

|

Return a controlled response; don't crash

|
|

Recoverable dependency error

|

Temporary Redis or Shopify failure

|

Apply timeouts, bounded retries, or a fallback

|
|

Job-level error

|

A reward job fails validation

|

Mark the job failed or retry if appropriate

|
|

Unexpected programming error

|

Broken internal state, unexpected `TypeError`

|

Record diagnostics; determine whether the process can safely continue

|
|

Fatal process failure

|

Runtime or native-level failure, unrecoverable state

|

Let a supervisor replace the process; don't depend on in-process cleanup

|

The senior-level principle is:

Handle an error at the layer that understands how to recover from it.

A controller should not need to know how to recover a broken database connection pool. A queue retry should not automatically retry a permanent validation error. A global exception filter should not turn every unexpected programming error into a successful response.

## 3. `try/catch`, rejected promises, and the async trap

Let's start with a familiar NestJS service.

TypeScript

```
async function getProducts() {
  try {
    return shopifyService.fetchProducts();
  } catch (error) {
    logger.error("Could not fetch products", error);
    throw error;
  }
}
```

At first glance, this looks correct. But if `fetchProducts()` returns a promise that rejects later, the local `catch` does not catch that rejection because the promise was returned without being awaited inside the `try`.

A corrected version is:

TypeScript

```
async function getProducts() {
  try {
    return await shopifyService.fetchProducts();
  } catch (error) {
    logger.error("Could not fetch products", error);
    throw error;
  }
}
```

Now the rejection is observed inside the `try`/`catch`, so this function can log or transform it.

Alternatively, if you don't need local recovery or logging, simply return the promise and let the caller handle its rejection.

TypeScript

```
async function getProducts() {
  return shopifyService.fetchProducts();
}
```

### What if you forget to `await` at the call site?

TypeScript

```
async function controllerAction() {
  try {
    productService.getProducts();
    return { accepted: true };
  } catch (error) {
    // Does not catch a later rejection from getProducts().
  }
}
```

The call starts, but the controller does not wait for its result. A later rejection may become unhandled unless some other code observes it.

Correct:

TypeScript

```
async function controllerAction() {
  try {
    const products = await productService.getProducts();
    return products;
  } catch (error) {
    // Handles the rejected promise here.
    throw error;
  }
}
```

For NestJS, let the framework's normal exception-handling path handle the error when appropriate. Avoid catching exceptions merely to log and rethrow them at every layer, because this can generate duplicate logs without adding recovery.

## 4. The four process-level mechanisms you must understand

Node.js exposes several process events, but they are not interchangeable.

`uncaughtException`

An exception escaped the normal JavaScript call stack without being caught.

Potentially fatal

The process may be in an unsafe state. Use this event for minimal emergency diagnostics and controlled termination, not to resume normal service blindly.

`unhandledRejection`

A promise was rejected without a handler being attached within the relevant event-loop turn.

Bug or missing handling

Under Node.js's default `--unhandled-rejections=throw` behavior, an unhandled rejection can be raised as an uncaught exception if it isn't handled by an `unhandledRejection` listener.

`SIGTERM`

A termination signal commonly sent during container or process shutdown.

Planned shutdown

Stop accepting new work, drain requests, close dependencies, and exit within a bounded time.

`SIGKILL`

The operating system terminates the process without allowing it to run cleanup handlers.

No graceful cleanup

Durable state, transactions, idempotency, and external supervision must protect the system when graceful shutdown is impossible.

A subtle but important detail: installing an `uncaughtException` listener changes the default fatal behavior. If you add one, you must explicitly arrange for termination after minimal diagnostics; do not assume Node.js will automatically exit as before.

Also, do not install an `unhandledRejection` listener just to log every rejection and then carry on. That can mask bugs that should be fixed.

## 5. Graceful shutdown: what happens when AWS sends `SIGTERM`?

Imagine your NestJS application is running inside a Docker container on AWS. A deployment replaces the container and sends `SIGTERM`.

Your service should not immediately call `process.exit(0)`. That can terminate pending operations before they finish.

Instead, use this sequence:

1. Mark the instance as shutting down so readiness checks fail.

2. Stop accepting new connections.

3. Allow in-flight HTTP requests to finish within a deadline.

4. Stop accepting new queue jobs and finish or safely interrupt active jobs.

5. Close Redis, MySQL pools, and other application resources.

6. Exit within the orchestrator's termination grace period.

Diagram options

![](<data:image/svg+xml;utf8,%3Csvg%20id%3D%22mermaid-_r_dtr_%22%20width%3D%22277.0390625%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20class%3D%22flowchart%22%20height%3D%22819%22%20viewBox%3D%224%204%20277.0390625%20819%22%20role%3D%22graphics-document%20document%22%20aria-roledescription%3D%22flowchart-v2%22%3E%3Cstyle%3E%23mermaid-_r_dtr_%7Bfont-family%3A%22-apple-system%22%2C%22BlinkMacSystemFont%22%2C%22Segoe%20UI%22%2C%22Roboto%22%2C%22Oxygen%22%2C%22Ubuntu%22%2C%22Cantarell%22%2C%22Helvetica%20Neue%22%2C%22Arial%22%2C%22sans-serif%22%3Bfont-size%3A14px%3Bfill%3Argb(255%2C%20255%2C%20255)%3B%7D%40keyframes%20edge-animation-frame%7Bfrom%7Bstroke-dashoffset%3A0%3B%7D%7D%40keyframes%20dash%7Bto%7Bstroke-dashoffset%3A0%3B%7D%7D%23mermaid-_r_dtr_%20.edge-animation-slow%7Bstroke-dasharray%3A9%2C5!important%3Bstroke-dashoffset%3A900%3Banimation%3Adash%2050s%20linear%20infinite%3Bstroke-linecap%3Around%3B%7D%23mermaid-_r_dtr_%20.edge-animation-fast%7Bstroke-dasharray%3A9%2C5!important%3Bstroke-dashoffset%3A900%3Banimation%3Adash%2020s%20linear%20infinite%3Bstroke-linecap%3Around%3B%7D%23mermaid-_r_dtr_%20.error-icon%7Bfill%3Argb(33%2C%2033%2C%2033)%3B%7D%23mermaid-_r_dtr_%20.error-text%7Bfill%3Argb(255%2C%20255%2C%20255)%3Bstroke%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20.edge-thickness-normal%7Bstroke-width%3A1px%3B%7D%23mermaid-_r_dtr_%20.edge-thickness-thick%7Bstroke-width%3A3.5px%3B%7D%23mermaid-_r_dtr_%20.edge-pattern-solid%7Bstroke-dasharray%3A0%3B%7D%23mermaid-_r_dtr_%20.edge-thickness-invisible%7Bstroke-width%3A0%3Bfill%3Anone%3B%7D%23mermaid-_r_dtr_%20.edge-pattern-dashed%7Bstroke-dasharray%3A3%3B%7D%23mermaid-_r_dtr_%20.edge-pattern-dotted%7Bstroke-dasharray%3A2%3B%7D%23mermaid-_r_dtr_%20.marker%7Bfill%3Argb(205%2C%20205%2C%20205)%3Bstroke%3Argb(205%2C%20205%2C%20205)%3B%7D%23mermaid-_r_dtr_%20.marker.cross%7Bstroke%3Argb(205%2C%20205%2C%20205)%3B%7D%23mermaid-_r_dtr_%20svg%7Bfont-family%3A%22-apple-system%22%2C%22BlinkMacSystemFont%22%2C%22Segoe%20UI%22%2C%22Roboto%22%2C%22Oxygen%22%2C%22Ubuntu%22%2C%22Cantarell%22%2C%22Helvetica%20Neue%22%2C%22Arial%22%2C%22sans-serif%22%3Bfont-size%3A14px%3B%7D%23mermaid-_r_dtr_%20p%7Bmargin%3A0%3B%7D%23mermaid-_r_dtr_%20.label%7Bfont-family%3A%22-apple-system%22%2C%22BlinkMacSystemFont%22%2C%22Segoe%20UI%22%2C%22Roboto%22%2C%22Oxygen%22%2C%22Ubuntu%22%2C%22Cantarell%22%2C%22Helvetica%20Neue%22%2C%22Arial%22%2C%22sans-serif%22%3Bcolor%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20.cluster-label%20text%7Bfill%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20.cluster-label%20span%7Bcolor%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20.cluster-label%20span%20p%7Bbackground-color%3Atransparent%3B%7D%23mermaid-_r_dtr_%20.label%20text%2C%23mermaid-_r_dtr_%20span%7Bfill%3Argb(255%2C%20255%2C%20255)%3Bcolor%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20.node%20rect%2C%23mermaid-_r_dtr_%20.node%20circle%2C%23mermaid-_r_dtr_%20.node%20ellipse%2C%23mermaid-_r_dtr_%20.node%20polygon%2C%23mermaid-_r_dtr_%20.node%20path%7Bfill%3Argb(9%2C%2023%2C%2044)%3Bstroke%3Argb(31%2C%2078%2C%20148)%3Bstroke-width%3A1px%3B%7D%23mermaid-_r_dtr_%20.rough-node%20.label%20text%2C%23mermaid-_r_dtr_%20.node%20.label%20text%2C%23mermaid-_r_dtr_%20.image-shape%20.label%2C%23mermaid-_r_dtr_%20.icon-shape%20.label%7Btext-anchor%3Amiddle%3B%7D%23mermaid-_r_dtr_%20.node%20.katex%20path%7Bfill%3A%23000%3Bstroke%3A%23000%3Bstroke-width%3A1px%3B%7D%23mermaid-_r_dtr_%20.rough-node%20.label%2C%23mermaid-_r_dtr_%20.node%20.label%2C%23mermaid-_r_dtr_%20.image-shape%20.label%2C%23mermaid-_r_dtr_%20.icon-shape%20.label%7Btext-align%3Acenter%3B%7D%23mermaid-_r_dtr_%20.node.clickable%7Bcursor%3Apointer%3B%7D%23mermaid-_r_dtr_%20.root%20.anchor%20path%7Bfill%3Argb(205%2C%20205%2C%20205)!important%3Bstroke-width%3A0%3Bstroke%3Argb(205%2C%20205%2C%20205)%3B%7D%23mermaid-_r_dtr_%20.arrowheadPath%7Bfill%3Argb(205%2C%20205%2C%20205)%3B%7D%23mermaid-_r_dtr_%20.edgePath%20.path%7Bstroke%3Argb(205%2C%20205%2C%20205)%3Bstroke-width%3A2.0px%3B%7D%23mermaid-_r_dtr_%20.flowchart-link%7Bstroke%3Argb(205%2C%20205%2C%20205)%3Bfill%3Anone%3B%7D%23mermaid-_r_dtr_%20.edgeLabel%7Bbackground-color%3Argb(0%2C%200%2C%200)%3Btext-align%3Acenter%3B%7D%23mermaid-_r_dtr_%20.edgeLabel%20p%7Bbackground-color%3Argb(0%2C%200%2C%200)%3B%7D%23mermaid-_r_dtr_%20.edgeLabel%20rect%7Bopacity%3A0.5%3Bbackground-color%3Argb(0%2C%200%2C%200)%3Bfill%3Argb(0%2C%200%2C%200)%3B%7D%23mermaid-_r_dtr_%20.labelBkg%7Bbackground-color%3Argba(0%2C%200%2C%200%2C%200.5)%3B%7D%23mermaid-_r_dtr_%20.cluster%20rect%7Bfill%3Argb(33%2C%2033%2C%2033)%3Bstroke%3Argba(255%2C%20255%2C%20255%2C%200.05)%3Bstroke-width%3A1px%3B%7D%23mermaid-_r_dtr_%20.cluster%20text%7Bfill%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20.cluster%20span%7Bcolor%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20div.mermaidTooltip%7Bposition%3Aabsolute%3Btext-align%3Acenter%3Bmax-width%3A200px%3Bpadding%3A2px%3Bfont-family%3A%22-apple-system%22%2C%22BlinkMacSystemFont%22%2C%22Segoe%20UI%22%2C%22Roboto%22%2C%22Oxygen%22%2C%22Ubuntu%22%2C%22Cantarell%22%2C%22Helvetica%20Neue%22%2C%22Arial%22%2C%22sans-serif%22%3Bfont-size%3A12px%3Bbackground%3Argb(33%2C%2033%2C%2033)%3Bborder%3A1px%20solid%20rgba(255%2C%20255%2C%20255%2C%200.05)%3Bborder-radius%3A2px%3Bpointer-events%3Anone%3Bz-index%3A100%3B%7D%23mermaid-_r_dtr_%20.flowchartTitleText%7Btext-anchor%3Amiddle%3Bfont-size%3A18px%3Bfill%3Argb(255%2C%20255%2C%20255)%3B%7D%23mermaid-_r_dtr_%20rect.text%7Bfill%3Anone%3Bstroke-width%3A0%3B%7D%23mermaid-_r_dtr_%20.icon-shape%2C%23mermaid-_r_dtr_%20.image-shape%7Bbackground-color%3Argb(0%2C%200%2C%200)%3Btext-align%3Acenter%3B%7D%23mermaid-_r_dtr_%20.icon-shape%20p%2C%23mermaid-_r_dtr_%20.image-shape%20p%7Bbackground-color%3Argb(0%2C%200%2C%200)%3Bpadding%3A2px%3B%7D%23mermaid-_r_dtr_%20.icon-shape%20rect%2C%23mermaid-_r_dtr_%20.image-shape%20rect%7Bopacity%3A0.5%3Bbackground-color%3Argb(0%2C%200%2C%200)%3Bfill%3Argb(0%2C%200%2C%200)%3B%7D%23mermaid-_r_dtr_%20.label-icon%7Bdisplay%3Ainline-block%3Bheight%3A1em%3Boverflow%3Avisible%3Bvertical-align%3A-0.125em%3B%7D%23mermaid-_r_dtr_%20.node%20.label-icon%20path%7Bfill%3AcurrentColor%3Bstroke%3Arevert%3Bstroke-width%3Arevert%3B%7D%23mermaid-_r_dtr_%20.node%20text%7Bfont-size%3A16px%3Bfont-weight%3A600%3Bletter-spacing%3A-0.32px%3Bfill%3A%2399ceff%3B%7D%23mermaid-_r_dtr_%20.edgeLabels%20text%7Bfont-size%3A13px%3Bfont-weight%3A600%3Bletter-spacing%3A-0.08px%3Bfill%3A%2399ceff%3B%7D%23mermaid-_r_dtr_%20.node%20tspan%5Bfont-weight%3D%22normal%22%5D%2C%23mermaid-_r_dtr_%20.edgeLabels%20tspan%5Bfont-weight%3D%22normal%22%5D%7Bfont-weight%3A600%3B%7D%23mermaid-_r_dtr_%20.edgeLabel%20.label%20rect%7Bopacity%3A1%3Brx%3A13px%3Bry%3A13px%3Bfill%3A%23000e1a%3Bstroke%3Argb(26%2C%2062%2C%2095)%3Bstroke-width%3A1px%3B%7D%23mermaid-_r_dtr_%20.node%20rect%2C%23mermaid-_r_dtr_%20.node%20circle%2C%23mermaid-_r_dtr_%20.node%20ellipse%2C%23mermaid-_r_dtr_%20.node%20polygon%2C%23mermaid-_r_dtr_%20.node%20path%7Bfill%3Argb(0%2C%2040%2C%2077)%3Bstroke%3Argba(255%2C%20255%2C%20255%2C%200.1)%3Bstroke-width%3A1px%3B%7D%23mermaid-_r_dtr_%20.node%20rect%7Brx%3A16px%3Bry%3A16px%3B%7D%23mermaid-_r_dtr_%20.node.mermaid-decision%20.label-container%7Bfill%3A%23000e1a%3Bstroke%3Argb(26%2C%2062%2C%2095)%3Bstroke-dasharray%3A2%202%3B%7D%23mermaid-_r_dtr_%20.edgePaths%20.flowchart-link%7Bstroke%3Argb(26%2C%2062%2C%2095)%3Bstroke-width%3A1px%3Bstroke-linecap%3Around%3Bstroke-linejoin%3Around%3B%7D%23mermaid-_r_dtr_%20.marker%7Bfill%3Argb(26%2C%2062%2C%2095)%3Bstroke%3Argb(26%2C%2062%2C%2095)%3B%7D%23mermaid-_r_dtr_%20.node%7Bcolor-scheme%3Adark%3B%7D%23mermaid-_r_dtr_%20%3Aroot%7B--mermaid-font-family%3A%22-apple-system%22%2C%22BlinkMacSystemFont%22%2C%22Segoe%20UI%22%2C%22Roboto%22%2C%22Oxygen%22%2C%22Ubuntu%22%2C%22Cantarell%22%2C%22Helvetica%20Neue%22%2C%22Arial%22%2C%22sans-serif%22%3B%7D%3C%2Fstyle%3E%3Cg%3E%3Cmarker%20id%3D%22mermaid-_r_dtr__flowchart-v2-pointEnd%22%20class%3D%22marker%20flowchart-v2%22%20viewBox%3D%22-5%20-5%2010%2010%22%20refX%3D%220%22%20refY%3D%220%22%20markerUnits%3D%22userSpaceOnUse%22%20markerWidth%3D%2210%22%20markerHeight%3D%2210%22%20orient%3D%22auto%22%3E%3Cpath%20d%3D%22M%200%200%20L%204%200%20M%200.8180194846605362%20-3.181980515339464%20L%204%200%20L%200.8180194846605362%203.181980515339464%22%20class%3D%22arrowMarkerPath%22%20style%3D%22stroke-width%3A%201%3B%20stroke-dasharray%3A%20none%3B%20fill%3A%20none%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%22%3E%3C%2Fpath%3E%3C%2Fmarker%3E%3Cmarker%20id%3D%22mermaid-_r_dtr__flowchart-v2-pointStart%22%20class%3D%22marker%20flowchart-v2%22%20viewBox%3D%22-5%20-5%2010%2010%22%20refX%3D%220%22%20refY%3D%220%22%20markerUnits%3D%22userSpaceOnUse%22%20markerWidth%3D%2210%22%20markerHeight%3D%2210%22%20orient%3D%22auto%22%3E%3Cpath%20d%3D%22M%200%200%20L%20-4%200%20M%20-0.8180194846605362%20-3.181980515339464%20L%20-4%200%20L%20-0.8180194846605362%203.181980515339464%22%20class%3D%22arrowMarkerPath%22%20style%3D%22stroke-width%3A%201%3B%20stroke-dasharray%3A%20none%3B%20fill%3A%20none%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%22%3E%3C%2Fpath%3E%3C%2Fmarker%3E%3Cmarker%20id%3D%22mermaid-_r_dtr__flowchart-v2-circleEnd%22%20class%3D%22marker%20flowchart-v2%22%20viewBox%3D%220%200%2010%2010%22%20refX%3D%2211%22%20refY%3D%225%22%20markerUnits%3D%22userSpaceOnUse%22%20markerWidth%3D%2211%22%20markerHeight%3D%2211%22%20orient%3D%22auto%22%3E%3Ccircle%20cx%3D%225%22%20cy%3D%225%22%20r%3D%225%22%20class%3D%22arrowMarkerPath%22%20style%3D%22stroke-width%3A%201%3B%20stroke-dasharray%3A%201%2C%200%3B%22%3E%3C%2Fcircle%3E%3C%2Fmarker%3E%3Cmarker%20id%3D%22mermaid-_r_dtr__flowchart-v2-circleStart%22%20class%3D%22marker%20flowchart-v2%22%20viewBox%3D%220%200%2010%2010%22%20refX%3D%22-1%22%20refY%3D%225%22%20markerUnits%3D%22userSpaceOnUse%22%20markerWidth%3D%2211%22%20markerHeight%3D%2211%22%20orient%3D%22auto%22%3E%3Ccircle%20cx%3D%225%22%20cy%3D%225%22%20r%3D%225%22%20class%3D%22arrowMarkerPath%22%20style%3D%22stroke-width%3A%201%3B%20stroke-dasharray%3A%201%2C%200%3B%22%3E%3C%2Fcircle%3E%3C%2Fmarker%3E%3Cmarker%20id%3D%22mermaid-_r_dtr__flowchart-v2-crossEnd%22%20class%3D%22marker%20cross%20flowchart-v2%22%20viewBox%3D%220%200%2011%2011%22%20refX%3D%2212%22%20refY%3D%225.2%22%20markerUnits%3D%22userSpaceOnUse%22%20markerWidth%3D%2211%22%20markerHeight%3D%2211%22%20orient%3D%22auto%22%3E%3Cpath%20d%3D%22M%201%2C1%20l%209%2C9%20M%2010%2C1%20l%20-9%2C9%22%20class%3D%22arrowMarkerPath%22%20style%3D%22stroke-width%3A%202%3B%20stroke-dasharray%3A%201%2C%200%3B%22%3E%3C%2Fpath%3E%3C%2Fmarker%3E%3Cmarker%20id%3D%22mermaid-_r_dtr__flowchart-v2-crossStart%22%20class%3D%22marker%20cross%20flowchart-v2%22%20viewBox%3D%220%200%2011%2011%22%20refX%3D%22-1%22%20refY%3D%225.2%22%20markerUnits%3D%22userSpaceOnUse%22%20markerWidth%3D%2211%22%20markerHeight%3D%2211%22%20orient%3D%22auto%22%3E%3Cpath%20d%3D%22M%201%2C1%20l%209%2C9%20M%2010%2C1%20l%20-9%2C9%22%20class%3D%22arrowMarkerPath%22%20style%3D%22stroke-width%3A%202%3B%20stroke-dasharray%3A%201%2C%200%3B%22%3E%3C%2Fpath%3E%3C%2Fmarker%3E%3C%2Fg%3E%3Cg%20class%3D%22subgraphs%22%3E%3C%2Fg%3E%3Cg%20class%3D%22nodes%22%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-A-0%22%20transform%3D%22translate(142.51953125%2C%2042)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-100.48828125%22%20y%3D%22-30%22%20width%3D%22200.9765625%22%20height%3D%2260%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-9.5)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EReceive%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20SIGTERM%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-B-1%22%20transform%3D%22translate(142.51953125%2C%20142)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-119.11958312988281%22%20y%3D%22-30%22%20width%3D%22238.23916625976562%22%20height%3D%2260%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-9.5)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EMark%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20instance%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20unready%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-C-3%22%20transform%3D%22translate(142.51953125%2C%20246.29999923706055)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-130.51953125%22%20y%3D%22-34.29999923706055%22%20width%3D%22261.0390625%22%20height%3D%2268.5999984741211%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-18.299999237060547)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EStop%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20accepting%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20new%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20HTTP%3C%2Ftspan%3E%3C%2Ftspan%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%221em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3Ework%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-D-5%22%20transform%3D%22translate(142.51953125%2C%20350.5999984741211)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-119.75390625%22%20y%3D%22-30%22%20width%3D%22239.5078125%22%20height%3D%2260%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-9.5)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EDrain%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20in-flight%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20requests%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-E-7%22%20transform%3D%22translate(142.51953125%2C%20454.89999771118164)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-117.12890625%22%20y%3D%22-34.29999923706055%22%20width%3D%22234.2578125%22%20height%3D%2268.5999984741211%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-18.299999237060547)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EStop%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20queue%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20intake%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20and%3C%2Ftspan%3E%3C%2Ftspan%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%221em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3Esettle%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20active%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20jobs%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-F-9%22%20transform%3D%22translate(142.51953125%2C%20563.4999961853027)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-129.71484375%22%20y%3D%22-34.29999923706055%22%20width%3D%22259.4296875%22%20height%3D%2268.5999984741211%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-18.299999237060547)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EClose%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20Redis%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20and%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20database%3C%2Ftspan%3E%3C%2Ftspan%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%221em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3Eresources%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-G-11%22%20transform%3D%22translate(142.51953125%2C%20672.0999946594238)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-113.0546875%22%20y%3D%22-34.29999923706055%22%20width%3D%22226.109375%22%20height%3D%2268.5999984741211%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-18.299999237060547)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3EExit%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20before%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20shutdown%3C%2Ftspan%3E%3C%2Ftspan%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%221em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3Edeadline%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22node%20default%22%20id%3D%22flowchart-H-13%22%20transform%3D%22translate(142.51953125%2C%20780.6999931335449)%22%3E%3Crect%20class%3D%22basic%20label-container%22%20style%3D%22%22%20x%3D%22-108.578125%22%20y%3D%22-34.29999923706055%22%20width%3D%22217.15625%22%20height%3D%2268.5999984741211%22%3E%3C%2Frect%3E%3Cg%20class%3D%22label%22%20style%3D%22%22%20transform%3D%22translate(0%2C%20-18.299999237060547)%22%3E%3Crect%3E%3C%2Frect%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3Ctext%20y%3D%22-10.1%22%20style%3D%22%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3ESupervisor%3C%2Ftspan%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3E%20replaces%3C%2Ftspan%3E%3C%2Ftspan%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%221em%22%20dy%3D%221.1em%22%3E%3Ctspan%20font-style%3D%22normal%22%20class%3D%22text-inner-tspan%22%20font-weight%3D%22normal%22%3Einstance%3C%2Ftspan%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edges%20edgePaths%22%3E%3Cpath%20d%3D%22M142.51953125%2C72L142.51953125%2C100%22%20id%3D%22L_A_B_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_A_B_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5Ijo3Mn0seyJ4IjoxNDIuNTE5NTMxMjUsInkiOjEwNH1d%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3Cpath%20d%3D%22M142.51953125%2C172L142.51953125%2C200%22%20id%3D%22L_B_C_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_B_C_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5IjoxNzJ9LHsieCI6MTQyLjUxOTUzMTI1LCJ5IjoyMDR9XQ%3D%3D%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3Cpath%20d%3D%22M142.51953125%2C280.5999984741211L142.51953125%2C308.5999984741211%22%20id%3D%22L_C_D_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_C_D_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5IjoyODAuNTk5OTk4NDc0MTIxMX0seyJ4IjoxNDIuNTE5NTMxMjUsInkiOjMxMi41OTk5OTg0NzQxMjExfV0%3D%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3Cpath%20d%3D%22M142.51953125%2C380.5999984741211L142.51953125%2C408.5999984741211%22%20id%3D%22L_D_E_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_D_E_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5IjozODAuNTk5OTk4NDc0MTIxMX0seyJ4IjoxNDIuNTE5NTMxMjUsInkiOjQxMi41OTk5OTg0NzQxMjExfV0%3D%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3Cpath%20d%3D%22M142.51953125%2C489.1999969482422L142.51953125%2C517.1999969482422%22%20id%3D%22L_E_F_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_E_F_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5Ijo0ODkuMTk5OTk2OTQ4MjQyMn0seyJ4IjoxNDIuNTE5NTMxMjUsInkiOjUyMS4xOTk5OTY5NDgyNDIyfV0%3D%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3Cpath%20d%3D%22M142.51953125%2C597.7999954223633L142.51953125%2C625.7999954223633%22%20id%3D%22L_F_G_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_F_G_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5Ijo1OTcuNzk5OTk1NDIyMzYzM30seyJ4IjoxNDIuNTE5NTMxMjUsInkiOjYyOS43OTk5OTU0MjIzNjMzfV0%3D%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3Cpath%20d%3D%22M142.51953125%2C706.3999938964844L142.51953125%2C734.3999938964844%22%20id%3D%22L_G_H_0%22%20class%3D%22edge-thickness-normal%20edge-pattern-solid%20edge-thickness-normal%20edge-pattern-solid%20flowchart-link%22%20style%3D%22%3B%22%20data-edge%3D%22true%22%20data-et%3D%22edge%22%20data-id%3D%22L_G_H_0%22%20data-points%3D%22W3sieCI6MTQyLjUxOTUzMTI1LCJ5Ijo3MDYuMzk5OTkzODk2NDg0NH0seyJ4IjoxNDIuNTE5NTMxMjUsInkiOjczOC4zOTk5OTM4OTY0ODQ0fV0%3D%22%20marker-end%3D%22url(%23mermaid-_r_dtr__flowchart-v2-pointEnd)%22%3E%3C%2Fpath%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabels%22%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%3E%3Crect%20class%3D%22background%22%20style%3D%22stroke%3A%20none%22%3E%3C%2Frect%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_A_B_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_B_C_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_C_D_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_D_E_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_E_F_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_F_G_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3Cg%20class%3D%22edgeLabel%22%3E%3Cg%20class%3D%22label%22%20data-id%3D%22L_G_H_0%22%20transform%3D%22translate(0%2C%200)%22%3E%3Ctext%20y%3D%22-10.1%22%3E%3Ctspan%20class%3D%22text-outer-tspan%22%20x%3D%220%22%20y%3D%22-0.1em%22%20dy%3D%221.1em%22%3E%3C%2Ftspan%3E%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fsvg%3E>)

If draining takes too long, a deadline is necessary. The orchestrator may eventually force termination, so your application must not rely on unlimited cleanup time.

### A practical NestJS setup

For a NestJS HTTP service, begin with the framework's lifecycle hooks.

TypeScript

```
// main.ts
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Enables NestJS lifecycle hooks for supported signals.
  app.enableShutdownHooks();

  await app.listen(process.env.PORT ?? 3000);
}

bootstrap().catch((error) => {
  console.error("Application startup failed", error);
  process.exitCode = 1;
});
```

When the process receives a supported termination signal, NestJS can invoke lifecycle hooks such as `onModuleDestroy()` and `onApplicationShutdown()`.

For example:

TypeScript

```
import {
  Injectable,
  OnApplicationShutdown,
} from "@nestjs/common";

@Injectable()
export class DatabaseLifecycle
  implements OnApplicationShutdown
{
  constructor(
    private readonly database: DatabaseService,
  ) {}

  async onApplicationShutdown() {
    await this.database.close();
  }
}
```

Here, `DatabaseService.close()` is illustrative: implement it using your actual Sequelize or database-pool lifecycle API.

Important: this is only one part of graceful shutdown. NestJS lifecycle hooks do not automatically guarantee correct load-balancer draining, bounded shutdown, or safe BullMQ job handling. Those responsibilities must be designed for your deployment.

### Why `process.exit()` can be dangerous

Compare:

TypeScript

```
// Risky during ordinary shutdown:
process.exit(0);
```

with:

TypeScript

```
// Lets the event loop drain naturally:
process.exitCode = 0;
```

`process.exit()` terminates the process immediately and can truncate pending asynchronous output or interrupt cleanup. Setting `process.exitCode` requests an exit status while allowing the event loop to continue naturally.

A process that still has active handles may not exit promptly, so shutdown code must close the resources it owns.

## 6. BullMQ workers need their own shutdown plan

Your API server and your BullMQ worker may be separate processes. Shutting down the API does not automatically settle jobs in a different process.

A worker should stop fetching new jobs and coordinate its active jobs before closing its connections.

Conceptually:

TypeScript

```
import { Worker } from "bullmq";

const worker = new Worker(
  "reward-processing",
  async (job) => {
    return processReward(job.data);
  },
  {
    connection: redisConnection,
    concurrency: 5,
  },
);

let closing: Promise<void> | undefined;

function shutdown() {
  if (closing) return closing;

  closing = (async () => {
    // Gracefully stop taking new work and wait for active work.
    await worker.close();

    // Close other resources owned by this process here.
    await database.close();
    await redisConnection.quit();
  })();

  return closing;
}

process.once("SIGTERM", () => {
  void shutdown().catch((error) => {
    console.error("Graceful shutdown failed", error);
    process.exitCode = 1;
  });
});

process.once("SIGINT", () => {
  void shutdown().catch((error) => {
    console.error("Graceful shutdown failed", error);
    process.exitCode = 1;
  });
});
```

This is an illustrative skeleton, not a complete production shutdown coordinator. In a real deployment:

- Ensure the database and Redis clients are actually owned by this process and that their close methods are correct.

- Use a single shutdown coordinator so API, queue, and dependency cleanup cannot race.

- Enforce a total shutdown deadline shorter than the container's grace period.

- If cleanup exceeds the deadline, report the failure and allow the supervisor to enforce termination.

- Account for the possibility that a job is interrupted and retried after restart.

One more distinction: `worker.close()` is a graceful operation, not a magic cancellation mechanism. If an active processor is stuck indefinitely, shutdown may also wait indefinitely unless you design a timeout and recovery strategy.

## 7. What happens to an in-flight request when the process crashes?

Suppose your reward service does this:

TypeScript

```
async function payReward(userId: string, amount: number) {
  await paymentProvider.pay(userId, amount);
  await database.markRewardPaid(userId, amount);
}
```

The payment provider processes the payout successfully, but the Node.js process crashes before the database update completes.

After restart, your database says the payout is unpaid. A retry might send the payment again.

This is not fundamentally an exception-handling problem. It is a distributed systems consistency problem.

The external payment and your database are two separate systems. A local `try/catch` cannot make their operations atomic.

A safer design uses a stable idempotency key:

TypeScript

```
async function payReward(reward: Reward) {
  await paymentProvider.pay({
    userId: reward.userId,
    amount: reward.amount,
    idempotencyKey: `reward:${reward.id}`,
  });

  await database.markRewardPaid(reward.id);
}
```

This works only if the payment provider actually supports and correctly enforces idempotency keys. Your own database should also enforce uniqueness for the reward operation, and you must reconcile ambiguous outcomes when a request times out.

For queue-driven financial operations, consider a durable reward record, explicit processing states, idempotent job handlers, and reconciliation for payouts whose outcomes are uncertain.

Remember: retries provide another execution attempt, not exactly-once execution of an external side effect.

## 8. The right way to handle an uncaught exception

A common mistake is to use a process-level handler as a global recovery mechanism.

TypeScript

```
process.on("uncaughtException", (error) => {
  console.error(error);
  // Dangerous: blindly continue serving requests.
});
```

Logging is useful, but the application may have corrupted in-memory state or partially completed operations. Continuing to serve requests may compound the incident.

If you register this handler, its job should be limited to emergency diagnostics and controlled termination.

TypeScript

```
process.on("uncaughtException", (error) => {
  try {
    console.error("Fatal uncaught exception:", error);
  } finally {
    process.exitCode = 1;

    // A real application should signal its supervisor or
    // use a carefully designed bounded shutdown mechanism.
  }
});
```

This example deliberately does not call `process.exit()` or implement an unsafe recovery strategy. It also does not guarantee the process will exit promptly if handles remain active. Production systems should arrange for the supervisor to replace a process that cannot shut down cleanly.

For many applications, relying on Node.js's default fatal behavior and having a reliable external supervisor is preferable to adding a custom global exception handler.

Your process manager might be Docker, Kubernetes, or an AWS deployment platform. It should restart failed instances according to an explicit policy, while health checks and deployment controls prevent unhealthy instances from receiving traffic.

## 9. A production error-handling architecture

Here is how I would organize error handling in a NestJS backend.

### Layer 1 — Controller / HTTP boundary

Validate input, authenticate callers, return appropriate HTTP responses, and let NestJS handle propagated exceptions.

### Layer 2 — Service / domain logic

Enforce business invariants. Distinguish expected business failures from unexpected programming errors.

### Layer 3 — Dependency boundary

Apply timeouts, limited retries, error classification, and circuit-breaking where appropriate for MySQL, Redis, and third-party APIs.

### Layer 4 — Background job boundary

Decide whether a failure is retryable, record job state, apply idempotency, and send permanent failures to an appropriate failure-handling path.

### Layer 5 — Process and infrastructure

Record fatal diagnostics, terminate unsafe processes, drain healthy processes during deployment, and rely on external supervision.

For observability, correlate logs with request IDs and job IDs. Track shutdown duration, restart count, unhandled errors, failed jobs, and dependency failures. Avoid logging OTPs, access tokens, payment credentials, or other sensitive data.

## 10. Production incident simulator

## Choose your response

Select a scenario, then choose the response you would take as the engineer on call.

A. Deployment sends SIGTERM while requests are in flight.

B. An unexpected TypeError escapes all normal handlers.

C. A background promise rejects without being awaited or handled.

D. A payout may have succeeded, but the database update failed.

Your proposed response

Gracefully drain or shut down, preserve state, and recover through established lifecycle controls.

Log the error and continue normal operation.

Immediately retry the operation until it succeeds.

Restart the process without investigating or preserving relevant state.

### Engineering assessment

Appropriate direction

Stop accepting new work, drain requests and jobs within a deadline, close owned resources, and exit before the deployment grace period expires.

Explore this incident

## 11. Your checkpoint

Answer these in your own words. I'll review your reasoning and refine it into interview-ready answers.

1. Async error handling: Why might a `try/catch` fail to catch a rejected promise? Explain when `return await` is useful.

2. Graceful shutdown: Your NestJS service is deployed in Docker and receives `SIGTERM`. Describe the shutdown sequence, including what happens to active BullMQ jobs.

3. Fatal errors: Why is it dangerous to catch an `uncaughtException` and continue serving traffic? What role does the process supervisor play?

4. Distributed systems: A payment succeeds at the provider, but your application crashes before recording success in MySQL. How would you make retries safe?

5. Interview challenge: Explain the difference between `SIGTERM`, `SIGKILL`, `uncaughtException`, and `unhandledRejection` without treating them as equivalent error handlers.

Once you've answered, we'll review them and continue to Lesson 14 — Node.js Security Internals, covering prototype pollution, unsafe deserialization, command injection, secrets, and practical defenses for production APIs.
