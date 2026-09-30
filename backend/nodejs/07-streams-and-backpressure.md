---
status: learning
confidence: 3
last_reviewed: 2026-09-30
next_review: 2026-10-01
tags: [nodejs, streams, backpressure, memory, csv-export]
---

# Streams & Backpressure

> **Prev:** [Worker Threads vs BullMQ](06-worker-threads-vs-queues.md) · **Next:** [Buffers & binary data](08-buffers-and-binary-data.md) · **Related:** [Memory leaks](04-memory-leaks-and-gc.md)

## TL;DR

- `fs.readFile()` buffers the **whole** file before you get it → 5 GB file ≈ GBs of memory. Streams process **chunks**.
- **Backpressure:** `write(chunk)` returning `false` = chunk *accepted* but buffer hit `highWaterMark` → **stop writing, wait for `'drain'`**.
- Prefer `pipeline()` / `.pipe()` — they handle backpressure and errors for you.
- Memory control is **end-to-end**: streaming the output doesn't help if the ORM loaded 2M rows into an array first → use a cursor / keyset batches.

## Recall questions

<details><summary>Why are streams better than readFile() for a 5 GB file?</summary>

`readFile` buffers the complete file before making it available → huge memory, worse with concurrent requests. A readable stream reads and forwards smaller chunks (e.g. piped to the HTTP response), and backpressure slows the producer when the consumer can't keep up, keeping memory bounded.

</details>

<details><summary>What does <code>write(chunk) === false</code> mean, and what do you do?</summary>

The chunk was **not** lost — it's queued, but the writable buffer reached its high-water threshold. Stop writing more and resume on the `'drain'` event.

</details>

<details><summary>ORM loads 2M rows, then you stream them to CSV. Is memory fixed?</summary>

No — the input isn't streamed; the array holds all rows. Use a DB cursor/streaming query or bounded batches, transform incrementally, write with backpressure. For big tables prefer keyset pagination (`WHERE id > lastSeenId ORDER BY id LIMIT n`) over large OFFSETs.

</details>

<details><summary>Can streaming still use unbounded memory?</summary>

Yes — if you accumulate chunks in an array, buffer too much, ignore backpressure, or run an unbounded DB query upstream.

</details>

<details><summary>Export endpoint memory spikes with concurrent users. What do you check?</summary>

Follow the data path: (1) does Sequelize load all rows? (2) are rows converted to CSV incrementally? (3) does the writer respect backpressure? (4) are concurrent exports bounded? (5) are stream & DB errors handled without leaking resources?

</details>

## Gotchas / what I got wrong

- I said "stop generating data until the consumer catches up" — right idea, but be precise: `false` ≠ rejected; the signal to resume is `'drain'`.
- `readFile` doesn't "process as it reads" — it hands you the completed contents.
- Large `OFFSET` values get expensive and concurrent inserts/updates break naive pagination.

---

## Deep dive

### 1. Why streams beat `readFile()` for large files

`fs.readFile()` reads the file and makes the **completed** contents available to your callback/promise. For a 5 GB file, that can require several gigabytes for the contents alone.

A stream reads and forwards smaller chunks progressively:

```js
const fs = require("node:fs");

const source = fs.createReadStream("large-file.csv");

source.pipe(res); // res = HTTP response
```

Chunks flow from the file toward the client, and backpressure prevents the source from overwhelming the destination.

> **Senior nuance:** streaming doesn't guarantee constant memory. Memory can still grow if you accumulate chunks, buffer too much, or run an unbounded database query.

**Interview-ready answer**

> `fs.readFile()` buffers the complete file before making its contents available, which can create significant memory pressure for large files and concurrent requests. A readable stream processes the file incrementally and can pipe chunks directly to an HTTP response. With backpressure, the producer can slow down when the consumer cannot accept data quickly enough, helping keep memory usage bounded.

### 2. Backpressure: when `write(chunk)` returns `false`

`false` does **not** mean the chunk was rejected or lost. It has been accepted into the writable stream's internal buffer, but the buffer has reached its high-water threshold.

```text
Producer writes a chunk
        ↓
write(chunk) returns false
        ↓
Chunk is buffered — stop writing more
        ↓
Wait for 'drain'
        ↓
Buffer has drained enough → resume producing
```

```js
function writeMore() {
  let canContinue = true;

  while (canContinue && hasMoreData()) {
    const chunk = getNextChunk();
    canContinue = output.write(chunk);
  }

  if (hasMoreData()) {
    output.once("drain", writeMore);
  } else {
    output.end();
  }
}
```

Illustrative only: production code must also handle errors, avoid re-entrant/duplicate writes, and coordinate end-of-stream. For stream-to-stream transfers prefer `pipeline()` or `.pipe()`.

**Interview-ready answer**

> When `writable.write(chunk)` returns `false`, the chunk has already been queued, but the writable buffer has reached its high-water threshold. I must stop writing additional chunks and wait for the `'drain'` event before resuming. This is how backpressure prevents a fast producer from overwhelming a slower consumer.

### 3. Streaming output doesn't fix a fully loaded input

```js
const products = await Product.findAll(); // 2 million rows

for (const product of products) {
  // Write each row to a CSV stream
}
```

The output is streamed, but the input is not — `products` retains all two million records.

**Better:** a database cursor / streaming query if the driver/ORM supports it, otherwise bounded batches:

```js
const batchSize = 1000;
let offset = 0;

while (true) {
  const products = await Product.findAll({
    limit: batchSize,
    offset,
    order: [["id", "ASC"]],
  });

  if (products.length === 0) break;

  for (const product of products) {
    // Convert to CSV and write with backpressure handling
  }

  offset += products.length;
}
```

Simplified: large `OFFSET` values become expensive, and concurrent inserts/updates complicate pagination. For large exports consider **keyset pagination** (`WHERE id > lastSeenId ORDER BY id LIMIT ...`) or a DB cursor, depending on consistency requirements.

**Interview-ready answer**

> No. Streaming only the output doesn't solve the problem if the ORM materializes the entire result set in memory first. I'd use a database cursor or bounded batches, transform each record incrementally, and write through a backpressure-aware stream. For very large tables, I'd consider keyset pagination instead of repeatedly increasing OFFSET, and ensure the export has defined consistency semantics.

### 4. Production scenario: CSV export of 2M MySQL rows

A NestJS API exports two million rows to CSV; multiple users export at once and memory rises sharply. Follow the data path:

1. Does Sequelize load all rows into an array?
2. Are rows converted to CSV incrementally?
3. Is the writable stream respecting backpressure?
4. Are concurrent exports bounded by a sensible concurrency limit?
5. Are stream and database errors handled without leaving resources open?

### Key takeaways

- **Streaming:** process data incrementally instead of buffering an entire file or result set.
- **Backpressure:** when `write()` returns `false`, stop and wait for `'drain'`.
- **End-to-end memory control:** every stage matters — DB fetching, transformation, buffering, compression, HTTP delivery.
