---
status: learning
confidence: 2
last_reviewed: 2026-09-30
next_review: 2026-10-01
tags: [nodejs, buffer, binary, encoding, utf8, memory]
---

# Buffers & Binary Data

> **Prev:** [Streams & backpressure](07-streams-and-backpressure.md) · **Next:** Networking internals (TCP, HTTP, sockets, keep-alive) — *not written yet* · **Related:** [Memory leaks](04-memory-leaks-and-gc.md)

## TL;DR

- A **Buffer** is a sequence of raw **bytes** (Node's byte-oriented `Uint8Array`). Stream chunks are Buffers.
- **Bytes are the data; the encoding/format is the interpretation.** UTF-8 decodes text; PNG/ZIP/etc. describe file structure.
- **Never** round-trip arbitrary binary through a UTF-8 string → invalid bytes become `�` and are lost.
- String `.length` (UTF-16 code units) ≠ byte length: `"₹".length === 1`, `Buffer.byteLength("₹") === 3`.
- `subarray()` is a **view** (shared memory) — a 100-byte view can keep a 50 MB buffer alive. `Buffer.from(view)` makes a copy.
- Defaults: `Buffer.from()` / `Buffer.alloc()`. `allocUnsafe()` may contain old memory — fill before use.

## Recall questions

<details><summary>Why do <code>"₹".length</code> and <code>Buffer.byteLength("₹", "utf8")</code> differ, and why does it matter?</summary>

`.length` counts UTF-16 code units (1); UTF-8 encodes ₹ in 3 bytes (`e2 82 b9`). Size limits, `Content-Length`, binary protocols and upload validation are about **bytes**, not characters.

</details>

<details><summary>A cache stores <code>buffer.subarray(0, 100)</code> from a 50 MB buffer. Why does memory stay high?</summary>

`subarray()` returns a view over the same underlying memory, so the small view keeps the entire 50 MB allocation reachable. Store an independent copy (`Buffer.from(buf.subarray(0, 100))`) when you need ownership.

</details>

<details><summary>Concurrent 100 MB uploads collected into arrays + <code>Buffer.concat()</code> crash the service. Root cause & fix?</summary>

Every upload is fully held in memory (all chunks), and `concat` temporarily allocates another full-size buffer → peak ≈ 2× per upload × concurrency. Fix: stream request → size validation/transform → storage upload stream with `pipeline()`, enforce request-size limits, bound concurrent uploads, clean up on failure.

</details>

<details><summary>Why can't you treat an image as text?</summary>

Text is one interpretation of bytes. Image bytes follow a format (PNG/JPEG), and many byte sequences aren't valid UTF-8. Decoding replaces them with `�`; re-encoding doesn't restore the originals → corruption.

</details>

<details><summary>How do you legitimately represent binary as text, and at what cost?</summary>

Base64 or hex. Base64 costs ~33% more characters and needs decoding. That's different from decoding arbitrary bytes as UTF-8.

</details>

<details><summary><code>readUInt32BE</code> vs <code>readUInt32LE</code> on <code>00 00 01 00</code>?</summary>

BE → 256, LE → 65536. Endianness = byte order; matters for binary protocols and file formats, not ordinary UTF-8 text.

</details>

## Gotchas

- `Buffer.from(arrayBuffer)` **shares** memory; `Buffer.from(uint8Array)` **copies**.
- A Buffer represents bytes, not trust: validate type and size, don't rely on filename/client MIME type, don't log payloads.

---

## Deep dive

### 1. The story: your API receives a 100 MB image

A user uploads a product image to your NestJS e-commerce API:

```text
Product image      100 MB file on the user's device
      ↓
Network            data arrives progressively as bytes
      ↓
Node.js Buffer     byte-oriented view of the data
      ↓
Object storage     e.g. S3
```

Your application must handle the image's contents, but doesn't need to understand every byte as a character. **Text and binary data are not the same thing:**

- Text such as `"Prince"` is represented using an encoding such as UTF-8.
- An image, compressed file, audio clip, or encrypted payload is fundamentally a sequence of bytes.
- A Node.js `Buffer` lets you work with those bytes directly.

Converting arbitrary binary to text and back can corrupt it. Accumulating the whole upload in memory can create a memory problem.

### 2. What is a byte?

8 bits, each `0` or `1`:

```text
0 1 0 0 0 0 0 1   = 65 = 0x41
```

In ASCII/UTF-8, `0x41` is the letter `A`. But bytes don't inherently mean letters — the same value could be a number, part of an image, or part of an encrypted message. **The bytes are the data; the encoding or format determines how you interpret them.**

### 3. Meet the Buffer

A `Buffer` is Node's class for sequences of bytes, built on JavaScript typed arrays.

```js
const buffer = Buffer.from("Prince");

console.log(buffer);                  // <Buffer 50 72 69 6e 63 65>
console.log(buffer.length);           // 6
console.log(buffer.toString("utf8")); // Prince
```

Six ASCII characters → six bytes in UTF-8. Outside ASCII:

```js
const buffer = Buffer.from("₹", "utf8");

console.log(buffer.length);           // 3
console.log(buffer);                  // <Buffer e2 82 b9>
console.log(buffer.toString("utf8")); // ₹
```

```js
const text = "₹";

console.log(text.length);                     // 1
console.log(Buffer.byteLength(text, "utf8")); // 3
```

String `.length` counts UTF-16 code units, not UTF-8 bytes. This matters for file sizes, HTTP payloads, binary protocols, and network messages.

### 4. Creating Buffers safely

| Method                  | Use when                                         | Notes                                                        |
| ----------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `Buffer.from(data)`     | You already have data to copy/encode             | `Buffer.from([65,66,67]).toString()` → `ABC`                 |
| `Buffer.alloc(n)`       | You need `n` zero-filled bytes                   | `<Buffer 00 00 00 00 00>`                                    |
| `Buffer.allocUnsafe(n)` | Performance-sensitive, and you'll overwrite all  | May contain **old data from reused memory** — never expose it |

```js
const buffer = Buffer.allocUnsafe(5);
buffer.fill(0); // Initialize before use
```

`Buffer.from()` and `Buffer.alloc()` are the right defaults. Use `allocUnsafe()` only when you understand the initialization and security requirements.

### 5. The memory trap: copy vs view

```js
const original = Buffer.from([10, 20, 30, 40]);

const view = original.subarray(1, 3);

view[0] = 99;

console.log(original); // <Buffer 0a 63 1e 28>
console.log(view);     // <Buffer 63 1e>
```

`subarray()` creates a **view over the same memory**, not a copy:

```text
One underlying buffer
┌──────┬──────┬──────┬──────┐
│  10  │  99  │  30  │  40  │
└──────┴──────┴──────┴──────┘
 byte 0 byte 1 byte 2 byte 3
        └─── view ───┘
```

Independent copy:

```js
const copy = Buffer.from(original.subarray(1, 3));

copy[0] = 7;

console.log(original); // unchanged
console.log(copy);     // <Buffer 07 1e>
```

**Why it matters in production:** keeping a 100-byte slice of a 100 MB payload can keep the entire 100 MB allocation alive. Same family of problem as [memory leaks](04-memory-leaks-and-gc.md).

> **Engineering rule:** know whether an API returns a view or a copy before retaining slices of large buffers.

### 6. Buffer vs ArrayBuffer vs TypedArray vs DataView

| Type          | What it represents                                   | Common use                              |
| ------------- | ---------------------------------------------------- | --------------------------------------- |
| `Buffer`      | Node.js byte-oriented buffer                         | Files, sockets, HTTP payloads           |
| `ArrayBuffer` | Fixed-length region of binary data                   | Underlying storage for typed arrays     |
| `Uint8Array`  | Typed view: bytes as unsigned 8-bit integers         | Browser APIs, portable binary handling  |
| `DataView`    | View for reading/writing values with explicit byte order | Custom binary protocols, file formats |

```js
const storage = new ArrayBuffer(4);
const bytes = new Uint8Array(storage);

bytes[0] = 65;
bytes[1] = 66;
bytes[2] = 67;
bytes[3] = 68;

console.log(Buffer.from(storage).toString("utf8")); // ABCD
```

`ArrayBuffer` provides storage; `Uint8Array` accesses it byte by byte; `Buffer` is Node's specialized interface. `Buffer.from(arrayBuffer)` **shares** storage; `Buffer.from(uint8Array)` **copies**.

### 7. Endianness

Bytes `00 00 01 00` as a 4-byte integer:

- **Big-endian:** most significant byte first.
- **Little-endian:** least significant byte first.

```js
const buffer = Buffer.from([0x00, 0x00, 0x01, 0x00]);

console.log(buffer.readUInt32BE(0)); // 256
console.log(buffer.readUInt32LE(0)); // 65536
```

Both are correct for their byte order. Relevant for binary protocols and file formats; for ordinary UTF-8 text you usually don't think about it.

### 8. Text has an encoding; binary has a format

- **Text:** bytes `48 65 6c 6c 6f` decode as `"Hello"` in UTF-8.
- **Image:** bytes follow PNG/JPEG — dimensions, color info, compressed pixels. Decoding as UTF-8 doesn't reconstruct the image.
- **Compressed/encrypted:** may have no meaningful text form; understood via the compression format or cryptographic algorithm.

### 9. What goes wrong converting binary to text

```js
const original = Buffer.from([0xff, 0xfe, 0x41]);

const text = original.toString("utf8");

console.log(text);                      // �A  (roughly)
console.log(Buffer.from(text, "utf8")); // not FF FE 41 anymore
```

```text
Original bytes      FF FE 41
      ↓ decode as UTF-8
Text                �A        (FF, FE are not valid standalone UTF-8)
      ↓ encode back to UTF-8
Bytes               original bytes are lost
```

Decoding **valid** text with its correct encoding is normal. The problem is treating arbitrary bytes as if they were valid text.

In a backend:

```js
// ❌ Incorrect — can corrupt the image
const text = imageBuffer.toString("utf8");
const corruptedBuffer = Buffer.from(text, "utf8");

// ✅ Correct — preserve the original bytes
await uploadToStorage(imageBuffer);
```

Applies equally to PDFs, ZIPs, encrypted payloads, audio, and TCP messages.

### 10. Representing binary as text (legitimately)

```js
const buffer = Buffer.from("Hello");

console.log(buffer.toString("base64")); // SGVsbG8=
console.log(buffer.toString("hex"));    // 48656c6c6f
```

Useful when a system requires text (small image in JSON, text-only channel). Base64 costs ~33% more characters and must be decoded to recover the bytes.

### 11. Real-world: stream a large upload

Naive:

```js
const chunks = [];

req.on("data", (chunk) => {
  chunks.push(chunk);
});

req.on("end", () => {
  const completeFile = Buffer.concat(chunks);
  // Upload completeFile to storage
});
```

Retains every chunk, then builds another combined buffer — memory temporarily grows further during concatenation.

Better:

```text
HTTP request stream
        ↓
Size validation / streaming transform
        ↓
Storage upload stream
        ↓
Object storage
```

```js
const { pipeline } = require("node:stream/promises");

async function uploadImage(req, destinationStream) {
  await pipeline(req, destinationStream);
}
```

A real integration needs the provider's upload API, multipart handling where applicable, request-size limits, authentication, and cleanup on failure. Validate type and size; don't trust filename or client MIME type; don't log sensitive payloads.

### 12. What senior engineers watch for

- **Unexpected memory growth:** accumulated chunks, large concatenations, retained views, too many concurrent uploads.
- **Uninitialized memory:** never read/expose bytes from `allocUnsafe()` before writing them.
- **Encoding corruption:** keep binary as Buffers unless text decoding is intended.
- **Copy vs view:** a small `subarray()` can retain a large buffer — copy when you need independent ownership.

### Mental model

- **String** — a sequence of text characters (JavaScript's string model).
- **Buffer** — a sequence of bytes you can preserve and manipulate without interpreting as text.
- **Encoding / file format** — the rules that say how to interpret bytes: characters, image data, compressed content…

### Interview-ready answer

> We don't treat everything as text because text encoding is a specific interpretation of bytes. Arbitrary binary data may not be valid text, and decoding it with the wrong encoding can lose information. Buffers let Node.js preserve and manipulate the original bytes correctly — and for large payloads I stream them rather than concatenating, and I'm careful that retained `subarray()` views don't pin large allocations.
