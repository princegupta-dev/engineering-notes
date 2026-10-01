# Lesson 9 — CommonJS vs ES Modules

Node.js Internals · Level 9 of 16 · Senior Backend Engineering

Prince, imagine you're debugging a production NestJS application. It works locally, but after deployment, Node.js throws:

```
Error [ERR_REQUIRE_ESM]: require() of ES Module not supported
```

Or perhaps two services import each other, and one receives `undefined` instead of the expected function.

These are not ordinary business-logic bugs. They come from how Node.js loads, evaluates, and caches modules.

Today, we'll understand the module system from the inside out.

## 1. First, what problem do modules solve?

Imagine your entire backend was written in one file:

JavaScript

```
// app.js — everything in one file
function createUser() {}
function authenticateUser() {}
function createOrder() {}
function processPayment() {}
function sendNotification() {}
```

As the application grows, maintaining this becomes difficult. Modules let you split code into separate files with explicit interfaces.

NestJS Application

Auth module

Authentication logic

Orders module

Order processing

Database module

Persistence logic

Notification module

SMS and email

Each file can expose a public interface for other files to use.

Node.js has two main JavaScript module systems:

- CommonJS (CJS): uses `require()` and `module.exports`.

- ECMAScript Modules (ESM): uses `import` and `export`.

Both organize code, but their loading and evaluation semantics differ.

## 2. CommonJS: how `require()` works

Let's create two files.

`math.js`

JavaScript

```
function add(a, b) {
  return a + b;
}

module.exports = { add };
```

`app.js`

JavaScript

```
const math = require("./math");

console.log(math.add(2, 3)); // 5
```

When Node.js executes `require("./math")`, the simplified process is:

1. Resolve the module path to a file.

2. Check the CommonJS module cache.

3. If it is not cached, load and wrap the module's code.

4. Execute the module and populate its exports.

5. Return the exported value and cache the module.

Conceptually, Node.js wraps CommonJS code in a function similar to this:

JavaScript

```
(function (exports, require, module, __filename, __dirname) {
  // Your module code runs here
});
```

This is a conceptual representation of Node's CommonJS wrapper, not code you need to write yourself.

The wrapper gives each module its own scope for variables and provides module-specific values such as `require`, `module`, `exports`, `__filename`, and `__dirname`.

### The important distinction: `exports` vs `module.exports`

This is a common interview question.

JavaScript

```
exports.add = (a, b) => a + b;
```

This works because `exports` initially references the same object as `module.exports`.

But look at this:

JavaScript

```
exports = {
  add: (a, b) => a + b,
};
```

This reassigns the local `exports` variable. It does not replace the object Node.js will return from `require()`.

If you want to replace the exported value, use:

JavaScript

```
module.exports = {
  add: (a, b) => a + b,
};
```

Rule: modify `exports` as an object if you want to add properties; assign to `module.exports` when you want to replace the exported value.

## 3. CommonJS module caching: a production-relevant detail

Consider this file, `counter.js`:

JavaScript

```
console.log("counter module initialized");

let count = 0;

module.exports = {
  increment() {
    count++;
    return count;
  },
};
```

And `app.js`:

JavaScript

```
const first = require("./counter");
const second = require("./counter");

console.log(first.increment());
console.log(second.increment());
console.log(first === second);
```

Expected output:

```
counter module initialized
1
2
true
```

Why does the initialization message appear only once?

Node.js caches the loaded CommonJS module. Subsequent `require()` calls resolving to the same cached module generally return its existing exports rather than executing the module again.

Both variables refer to the same exported object, which maintains the same internal `count`.

### When does this become dangerous?

Suppose a module stores request-specific data globally:

JavaScript

```
// current-user.js
let currentUserId;

module.exports = {
  setUser(id) {
    currentUserId = id;
  },

  getUser() {
    return currentUserId;
  },
};
```

If two concurrent requests use this shared module, one request can overwrite the other request's value.

This is a potential cross-request data leak caused by shared mutable state.

For example, Request A sets user `101`; before it reads the value, Request B sets user `202`. Request A might now see `202`.

Senior-engineer lesson: module caching is not the bug. Unintentionally storing request-scoped state in a shared module is the bug.

In a NestJS application, be especially careful with mutable properties in singleton-scoped providers. Request-specific data should normally be passed explicitly or handled using an appropriate request-scoped design.

## 4. ES Modules: `import` and `export`

Now let's write the same example using ESM.

`math.mjs`

JavaScript

```
export function add(a, b) {
  return a + b;
}
```

`app.mjs`

JavaScript

```
import { add } from "./math.mjs";

console.log(add(2, 3)); // 5
```

ESM uses explicit import and export declarations.

You can also use a default export:

JavaScript

```
// logger.mjs
export default function log(message) {
  console.log(message);
}
```

JavaScript

```
// app.mjs
import log from "./logger.mjs";

log("Hello");
```

Named exports and default exports have different import syntax. A module can have multiple named exports but at most one default export.

### How Node.js identifies the module system

Common ways to identify modules in Node.js include:

|
File or configuration

|

Interpretation

|
| --- | --- |
|

`.cjs`

|

CommonJS

|
|

`.mjs`

|

ES module

|
|

`.js` with `"type": "commonjs"` in the relevant `package.json`

|

CommonJS

|
|

`.js` with `"type": "module"` in the relevant `package.json`

|

ES module

|

Node.js also has syntax-detection behavior for some ambiguous `.js` files in current releases. For predictable projects, explicitly setting `"type"` or using `.cjs`/`.mjs` is often clearer.

For example, a TypeScript project may compile source code into CommonJS or ESM depending on its compiler and package configuration. Writing `import` in TypeScript alone does not guarantee that the emitted JavaScript will use native ESM.

## 5. The deeper difference: how imports behave

This is where senior-level understanding begins.

### CommonJS: exported values are returned from `require()`

JavaScript

```
// config.cjs
module.exports = {
  mode: "development",
};
```

JavaScript

```
// app.cjs
const config = require("./config.cjs");

console.log(config.mode);
```

`require()` returns the value currently exposed by the loaded module's `module.exports`.

### ESM: imports are live bindings

Consider:

`counter.mjs`

JavaScript

```
export let count = 0;

export function increment() {
  count++;
}
```

`app.mjs`

JavaScript

```
import { count, increment } from "./counter.mjs";

console.log(count); // 0

increment();

console.log(count); // 1
```

The imported `count` is a live binding to the exported variable. It reflects changes made by the exporting module.

You cannot reassign the imported binding in the importing module:

JavaScript

```
import { count } from "./counter.mjs";

count = 10; // TypeError
```

In ESM, imports are read-only from the importer's perspective, even though the exporting module may update an exported `let` binding.

CommonJS behaves differently because `require()` returns an exported object or value. If a module exports an object, the importer can generally mutate that object unless the module or object prevents it.

## 6. The circular dependency incident

Imagine your backend has two modules:

- `user.js` imports `order.js`.

- `order.js` imports `user.js`.

This creates a circular dependency.

user.js

imports

order.js

Each module depends on the other.

Here's a simplified CommonJS example.

`a.cjs`

JavaScript

```
exports.name = "A";

const b = require("./b.cjs");

exports.getBName = () => b.name;
```

`b.cjs`

JavaScript

```
exports.name = "B";

const a = require("./a.cjs");

console.log(a.name);
```

`main.cjs`

JavaScript

```
const a = require("./a.cjs");

console.log(a.getBName());
```

This can work because CommonJS inserts a module into its cache before it has finished executing. When a circular dependency encounters a module that is still initializing, the requiring module can receive its partially initialized exports.

That behavior can become problematic if a module accesses an export before it has been assigned.

### Why does this matter?

In a large backend, circular dependencies can create:

- Undefined or incomplete exports during initialization.

- Fragile startup behavior.

- Difficult-to-understand coupling between services.

- Dependency injection problems in frameworks such as NestJS.

ESM has different circular-dependency semantics based on its linking and evaluation process. It uses live bindings, and accessing a lexical binding before initialization can throw a `ReferenceError` due to the temporal dead zone.

The architectural fix: don't rely on circular imports as a design pattern. Extract shared interfaces or utilities into a third module, or reverse the dependency using dependency injection.

NestJS's `forwardRef()` can help resolve certain circular provider or module references, but it doesn't automatically make a circular architecture easy to maintain.

## 7. Dynamic imports and interoperability

Sometimes you need to load a module conditionally or lazily.

ESM supports dynamic imports:

JavaScript

```
async function loadReportGenerator() {
  const reportModule = await import("./report-generator.mjs");

  return reportModule.generateReport();
}
```

`import()` returns a Promise, so the module can be loaded asynchronously.

This can be useful for optional features or expensive modules that aren't needed on every request. However, dynamically importing a module does not guarantee that its initialization cost disappears; it shifts when the cost is incurred.

### What about mixing CommonJS and ESM?

In real Node.js projects, interoperability matters.

For example, a CommonJS file can often load an ESM module using dynamic `import()`:

JavaScript

```
// app.cjs
async function main() {
  const module = await import("./math.mjs");

  console.log(module.add(2, 3));
}

main().catch(console.error);
```

Using `require()` to load ESM has version- and module-dependent behavior. Recent Node.js releases support `require(esm)` for some synchronous ESM graphs, but it is not a universal replacement for dynamic `import()`. In particular, asynchronous module graphs involving top-level `await` cannot be loaded synchronously this way.

When integrating a package that changed from CommonJS to ESM-only, check the package's compatibility requirements and your deployed Node.js version before changing imports.

## 8. CommonJS vs ESM — interview comparison

|
Feature

|

CommonJS

|

ES Modules

|
| --- | --- | --- |
|

Import syntax

|

`require()`

|

`import`

|
|

Export syntax

|

`module.exports`, `exports`

|

`export`, `export default`

|
|

Loading model

|

Synchronous `require()` interface

|

Static imports linked and evaluated by the module loader

|
|

Import behavior

|

Returns exported value

|

Imports are live bindings

|
|

Top-level `this`

|

Usually the module's exports object in a regular CJS module

|

`undefined`

|
|

Module cache

|

CommonJS module cache

|

ESM module map and loader caching

|
|

Dynamic loading

|

`require()` or dynamic `import()`

|

Dynamic `import()`

|
|

File conventions

|

`.cjs` or configured `.js`

|

`.mjs` or configured `.js`

|

A few caveats matter: CommonJS and ESM can interoperate, module resolution rules differ, and package configuration affects how `.js` files are interpreted.

Neither system is inherently a guarantee of faster application performance. The important concerns are compatibility, predictable resolution, initialization behavior, and architecture.

## 9. Production debugging scenario

Your NestJS backend deploys successfully on your laptop but fails in a Docker container after a dependency upgrade.

The dependency's latest version is ESM-only, and your compiled application still uses CommonJS `require()`.

A disciplined debugging process would be:

1. Inspect the actual Node.js version inside the container.

2. Inspect the package's `package.json`, especially its `"type"` and `"exports"` fields.

3. Check your project's `package.json` and TypeScript `module` and `moduleResolution` settings.

4. Inspect the emitted JavaScript, not just the TypeScript source.

5. Decide whether to use a compatible dependency version, dynamic `import()`, or migrate the application to ESM.

6. Run the production build and integration tests inside the same container environment used for deployment.

This avoids randomly changing import syntax without understanding how the code is actually compiled and loaded.

## 10. Checkpoint — explain it like a senior engineer

Scenario 1

Two files call `require("./config")`. The first changes a property on the returned object, and the second sees the change. Explain why, and identify when this behavior could cause a production bug.

Scenario 2

Your TypeScript application uses `import` syntax, but production throws `ERR_REQUIRE_ESM`. Why can this happen, and what would you inspect before fixing it?

Scenario 3

`UserService` imports `OrderService`, and `OrderService` imports `UserService`. Explain the potential CommonJS initialization problem and how you would improve the design.

Review my answers

Next lesson: Lesson 10 — V8 Optimization: hidden classes, inline caches, deoptimization, and how seemingly harmless JavaScript patterns can affect production performance.
