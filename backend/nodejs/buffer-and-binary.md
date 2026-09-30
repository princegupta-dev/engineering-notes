# Lesson 6 — Buffers and Binary Data in Node.js

In Node.js, a Buffer is a built-in class used to handle binary data as a sequence of bytes. JavaScript traditionally focuses on strings and other high-level data types, but backend applications also need to process files, images, network data, and other binary content.

Buffers allow us to read, manipulate, and transfer this data efficiently. They are commonly used with file system operations, streams, TCP sockets, and HTTP payloads.

For example, when we read a file or receive data from a network stream, Node.js may provide the data in Buffer chunks. We can process those chunks incrementally instead of loading an entire large file into memory.

We can create Buffers using methods such as Buffer.from() and Buffer.alloc(). We also need to understand encoding and memory ownership, because some operations copy bytes while others share the same underlying memory.

Node.js Internals Mastery · Lesson 6 of 16

Prince, in Lesson 5, you learned how Node.js moves data through streams without needing to load an entire file into memory.

Now let's answer a deeper question:

When a stream gives you a chunk of data, what exactly is that chunk, and how does Node.js store it?

To understand that, we need to understand bytes, binary data, and Buffers.

## 1. The story: your API receives a 100 MB image

![What Are Buffers, Really? - DEV Community](https://images.openai.com/static-rsc-4/IjJB3idbnc6DnrB-52tkaavetrVyzEGOPakATpJzoSTeDGCXmAFux7tiK6Oz6AlkZgdPKlzEQpqfnl5k2yJrvZVZKoimpHNQvhFOipLyOtN_lXmCF4UxvgjNR_d0K2eXYhm0OMlpBxGUcVJ8XplXWbGppahVejtQWYnyMBedrVs?purpose=inline)

Imagine you're building an e-commerce application. A user uploads a product image to your NestJS API.

The journey looks like this:

Product image

100 MB file on the user's device

Network transmission

Data arrives progressively in bytes

Node.js Buffer

A byte-oriented view of binary data

Object storage

Image is uploaded to storage such as S3

Your application must handle the image's contents, but it doesn't necessarily need to understand every byte as a character.

That's the key distinction: text and binary data are not the same thing.

- Text such as `"Prince"` is represented using an encoding such as UTF-8.

- An image, compressed file, audio clip, or encrypted payload is fundamentally a sequence of bytes.

- A Node.js `Buffer` gives you a way to work with those bytes directly.

If your API accidentally converts arbitrary binary data to text and back, it can corrupt the data. If it accumulates the whole upload in memory, it can create a memory problem.

Let's understand why.

## 2. What is a byte?

A byte is a unit of digital information consisting of 8 bits. Each bit is either `0` or `1`.

For example, a byte might contain:

## 0

## 1

## 0

## 0

## 0

## 0

## 0

## 1

8 bits = 1 byte. The pattern above represents the number 65, or hexadecimal 0x41.

In ASCII and UTF-8, the byte `0x41` represents the letter `A`.

But bytes don't inherently mean letters. The same byte value could be interpreted as a number, part of an image, part of an encrypted message, or something else entirely.

The bytes are the data; the encoding or format determines how you interpret them.

## 3. Meet the Node.js Buffer

A `Buffer` is a Node.js class for working with sequences of bytes. It is built on top of JavaScript's typed-array facilities.

Let's try it.

JavaScript

```
const buffer = Buffer.from("Prince");

console.log(buffer);
console.log(buffer.length);
console.log(buffer.toString("utf8"));
```

Output:

```
<Buffer 50 72 69 6e 63 65>
6
Prince
```

Why is the length `6`? Because `"Prince"` contains six ASCII characters, each represented by one byte in UTF-8.

Now consider a character outside basic ASCII:

JavaScript

```
const buffer = Buffer.from("₹", "utf8");

console.log(buffer.length);
console.log(buffer);
console.log(buffer.toString("utf8"));
```

Output:

```
3
<Buffer e2 82 b9>
₹
```

The rupee symbol takes three bytes in UTF-8.

This distinction matters when you work with file sizes, HTTP payloads, binary protocols, and network messages. String length and byte length are not always the same.

JavaScript

```
const text = "₹";

console.log(text.length);                 // 1
console.log(Buffer.byteLength(text, "utf8")); // 3
```

JavaScript's string `.length` counts UTF-16 code units, not UTF-8 bytes. For this particular symbol, the string length is one while the UTF-8 representation occupies three bytes.

## 4. Creating Buffers safely

There are several ways to create a Buffer. Three are particularly important.

1

`Buffer.from()`

Use this when you already have data you want to copy or encode.

JavaScript

```
const textBuffer = Buffer.from("Hello", "utf8");
const byteBuffer = Buffer.from([65, 66, 67]);

console.log(byteBuffer.toString()); // ABC
```

2

`Buffer.alloc()`

Use this when you need a buffer of a specified size initialized to zero.

JavaScript

```
const buffer = Buffer.alloc(5);

console.log(buffer); // <Buffer 00 00 00 00 00>
```

3

`Buffer.allocUnsafe()`

Allocates a buffer without initializing its contents to zero. It can be faster in some situations, but its initial contents must never be treated as valid data.

JavaScript

```
const buffer = Buffer.allocUnsafe(5);

buffer.fill(0); // Initialize before use
```

Important: before every byte is overwritten, the buffer may contain old data from reused memory. Never expose or read those uninitialized bytes as meaningful content.

For normal application development, `Buffer.from()` and `Buffer.alloc()` are the right defaults. Reach for `allocUnsafe()` only when you understand the initialization and security requirements.

## 5. The subtle memory trap: copying versus sharing

This is where Buffers become especially important for senior backend engineers.

Consider the following:

JavaScript

```
const original = Buffer.from([10, 20, 30, 40]);

const view = original.subarray(1, 3);

view[0] = 99;

console.log(original);
console.log(view);
```

Output:

```
<Buffer 0a 63 1e 28>
<Buffer 63 1e>
```

Why did modifying `view` change `original`?

Because `subarray()` creates a view over the same underlying memory, not an independent copy.

One underlying buffer

## 10

Byte 0

## 99

Byte 1

## 30

Byte 2

## 40

Byte 3

Both `original` and `view` refer to overlapping bytes in the same memory region.

If you need an independent copy, use:

JavaScript

```
const copy = Buffer.from(original.subarray(1, 3));

copy[0] = 7;

console.log(original); // Unchanged by the modification to copy
console.log(copy);     // <Buffer 07 1e>
```

### Why does this matter in production?

Imagine your API receives a 100 MB payload and keeps a small 100-byte slice for later processing. If that slice is a view into the original buffer, it can keep the larger underlying memory allocation alive.

A small object in your application can therefore retain a much larger memory region than you expect.

This is closely related to the memory-retention problems you studied in Lesson 3.

Engineering rule: Understand whether an API returns a view or a copy before retaining slices of large buffers.

## 6. Buffer vs. ArrayBuffer vs. TypedArray

These names sound similar because they are related, but they serve slightly different purposes.

|
Type

|

What it represents

|

Common use

|
| --- | --- | --- |
|

`Buffer`

|

Node.js byte-oriented buffer

|

Files, sockets, HTTP payloads

|
|

`ArrayBuffer`

|

A fixed-length region of binary data

|

Underlying storage for typed arrays

|
|

`Uint8Array`

|

A typed view that accesses bytes as unsigned 8-bit integers

|

Browser APIs and portable binary processing

|
|

`DataView`

|

A view for reading and writing binary values with explicit byte order

|

Custom binary protocols and file formats

|

Here's a small example:

JavaScript

```
const storage = new ArrayBuffer(4);
const bytes = new Uint8Array(storage);

bytes[0] = 65;
bytes[1] = 66;
bytes[2] = 67;
bytes[3] = 68;

console.log(Buffer.from(storage).toString("utf8"));
// ABCD
```

`ArrayBuffer` provides storage, while `Uint8Array` provides a way to access that storage as individual bytes. `Buffer` is Node.js's specialized byte-handling interface.

One subtlety: `Buffer.from(arrayBuffer)` shares the underlying storage in this form. By contrast, `Buffer.from(uint8Array)` copies the elements of the typed array.

## 7. Endianness: when byte order matters

Suppose you're reading a four-byte integer from a binary network protocol. The bytes are:

`00 00 01 00`

How do those bytes map to an integer? That depends on their order.

- Big-endian: the most significant byte comes first.

- Little-endian: the least significant byte comes first.

Node.js lets you specify the interpretation explicitly:

JavaScript

```
const buffer = Buffer.from([0x00, 0x00, 0x01, 0x00]);

console.log(buffer.readUInt32BE(0)); // 256
console.log(buffer.readUInt32LE(0)); // 65536
```

Both results are correct for their respective byte orders.

You will encounter this when parsing binary protocols, dealing with file formats, or integrating with systems that exchange compact binary messages. For ordinary UTF-8 text, you usually don't need to think about endianness.

## 8. Real-world application: stream a large upload

Let's connect today's lesson to your backend work.

Suppose a client uploads a large image. A naive implementation might collect every chunk and concatenate them:

JavaScript

```
const chunks = [];

req.on("data", (chunk) => {
  chunks.push(chunk);
});

req.on("end", () => {
  const completeFile = Buffer.concat(chunks);
  // Upload completeFile to storage
});
```

This may work for small payloads, but it retains all chunks and then constructs the combined buffer. During concatenation, memory can temporarily increase further.

A better architecture for large uploads is often:

```
HTTP request stream
        ↓
Size validation / streaming transform
        ↓
Storage upload stream
        ↓
Object storage
```

For example, if the destination exposes a writable stream:

JavaScript

```
const { pipeline } = require("node:stream/promises");

async function uploadImage(req, destinationStream) {
  await pipeline(req, destinationStream);
}
```

This is an illustrative stream-to-stream example; a real object-storage integration needs the provider's upload API, appropriate multipart handling where applicable, request-size limits, authentication, and cleanup on failure.

Also remember: a Buffer represents bytes, not trust. Validate file type and size, don't rely solely on a filename or client-supplied MIME type, and avoid logging sensitive payload contents.

## 9. What senior engineers watch for

Unexpected memory growth

Look for accumulated chunks, large concatenations, retained buffer views, and too many concurrent uploads.

Uninitialized memory

Never read or expose uninitialized bytes from `Buffer.allocUnsafe()`.

Encoding corruption

Don't convert arbitrary binary data to a UTF-8 string and back. Keep binary payloads as Buffers unless text decoding is intended.

Copy versus view

A small `subarray()` can retain the underlying larger buffer. Copy it when independent ownership is necessary.

## 10. Your Lesson 6 checkpoint

Let's test your understanding with three production-style scenarios. Explain your reasoning in your own words; focus on the underlying mechanism, not just memorizing the API.

Question 1

String length vs. byte length

JavaScript

```
const text = "₹";
console.log(text.length);
console.log(Buffer.byteLength(text, "utf8"));
```

Why do these two expressions return different values, and why does the difference matter when processing uploads?

Question 2

The disappearing memory problem

A service stores `buffer.subarray(0, 100)` in a cache. The original buffer was 50 MB. Even after the rest of the request completes, memory remains elevated.

Explain how a 100-byte view can contribute to retaining a much larger memory allocation, and how you would avoid that when independent ownership is needed.

Question 3

The production upload incident

Your Node.js API receives several concurrent 100 MB uploads. Developers collect every request chunk into an array, call `Buffer.concat()`, and then upload each complete buffer to object storage. Memory usage spikes and the service sometimes crashes.

Describe the root cause and the changes you would make to the data flow to reduce memory pressure safely.

Review my answers

Once you've worked through these, we'll move to Lesson 7 — Networking Internals: TCP, HTTP, sockets, keep-alive, and how Node.js handles connections.

Prince, imagine you're building your Fills e-commerce application. A user uploads a product image, and your Node.js server receives it.

Why can't you simply treat that image as text?

The answer is: because text is an interpretation of bytes, not the bytes themselves. Some data doesn't represent text at all.

Let's build the intuition step by step.

## 1. Computers store everything as bytes

At the lowest level, computers work with bits (`0` and `1`), grouped into bytes.

For example, the letter `A` in ASCII and UTF-8 is represented by the byte `65`, or `01000001` in binary.

JavaScript

```
const buffer = Buffer.from("A");

console.log(buffer);        // <Buffer 41>
console.log(buffer.toString()); // A
```

Here, `0x41` is the hexadecimal representation of the byte `65`.

So far, treating the bytes as text works perfectly.

But now let's look at other kinds of data.

## 2. Text has an encoding; binary data has a format

![Anam Trust Center](https://images.openai.com/static-rsc-4/fWQMh3HRBzJtoFIRbc7rfpLx8AL_y8Ma0gsw-uj6rA0u1GqyEAAlBaX3DPLzQNs25DWh4x39lgqkbkb2X9B0udx8lEYCTtKZznkF-DMsYfdph-aK1dQGOg3Pq38JOA8UdM1hEMfxrab4NzKeEVYjw5zeY_xtuTBWoMrE-mDsk1M?purpose=inline)

Case A: Text

The bytes `48 65 6c 6c 6f` decode as `"Hello"` in UTF-8.

The encoding tells us how to interpret the bytes as characters.

![Red Apple - Free Stock Photo by 2happy on Stockvault.net](https://images.openai.com/static-rsc-4/l2m4pz6tILUo-IuPCRZCzz4gnw2AllWwkCbWFraqK68TOm2PbeM3olt17sfSivvEjLZTymIV5I57sVIP043H6FKedpCAK_dJiUplmmFYz9li4UVkyLr6E5IPHM1pCOv63OflcjLHmvMGWILTKa8oXGR_Ad2K7KKkSAJrTQdrP28?purpose=inline)

Case B: An image

An image file contains bytes that follow a format such as PNG or JPEG. Those bytes encode things such as image dimensions, color information, and compressed pixel data.

Interpreting arbitrary bytes as UTF-8 text doesn't reconstruct the image.

![Azure Developer Day - Hyderabad | Reskilll](https://images.openai.com/static-rsc-4/qETI8L58YShYgrRLa_Mpqt9kbkxxfSHTplfBXOSLMvH7e2j9wc2pSDW2ua5ZSYw6_QdoxAR8QwE3SxuA8C5SMwr1q6-LPasUU4Y4ievunnwsoemo7mbvc0miPl431YFIYeQxRcuBAeWngtiuVS-cjFXc2eupxEuE1W8FPV5Tegk?purpose=inline)

Case C: Compressed or encrypted data

These bytes may have no meaningful human-readable text representation. Their structure is understood using the appropriate compression format or cryptographic algorithm.

The important distinction is that text encoding and file formats are different things. UTF-8 tells you how to decode text. PNG tells you how to interpret an image file's structure.

## 3. What goes wrong if we convert binary data into text?

Let's experiment with Node.js.

JavaScript

```
const original = Buffer.from([0xff, 0xfe, 0x41]);

const text = original.toString("utf8");

console.log(text);
console.log(Buffer.from(text, "utf8"));
```

The original bytes are:

```
FF FE 41
```

But `FF` and `FE` are not valid standalone UTF-8 bytes. Node.js replaces malformed sequences with the Unicode replacement character, `�`.

When the resulting string is encoded back into UTF-8, the original bytes are not recovered.

Original binary data

## `FF FE 41`

Decode as UTF-8

## `�A`

Encode the text back to UTF-8

## Original bytes may be lost

This is why converting arbitrary binary data into text can corrupt it.

Note that converting valid text to a string using its correct encoding is perfectly normal. The problem is treating arbitrary bytes as if they were valid text.

## 4. How does this matter in your backend?

Imagine your Node.js API receives a product image.

Incorrect approach:

JavaScript

```
const text = imageBuffer.toString("utf8");
const corruptedBuffer = Buffer.from(text, "utf8");
```

If the image contains byte sequences that are invalid UTF-8, this conversion can change its contents.

Correct approach:

JavaScript

```
// Preserve the original bytes.
const imageBuffer = receivedBuffer;

// Send the binary data to a compatible storage API.
await uploadToStorage(imageBuffer);
```

For large images, you would generally stream the bytes to storage rather than buffering the entire file.

This principle also applies to PDFs, ZIP files, encrypted payloads, audio, and TCP messages.

## 5. But can't we represent binary data as text?

Yes! Formats such as Base64 and hexadecimal represent binary bytes using text characters.

For example:

JavaScript

```
const buffer = Buffer.from("Hello");

console.log(buffer.toString("base64"));
// SGVsbG8=

console.log(buffer.toString("hex"));
// 48656c6c6f
```

These representations are useful when a system requires textual data, such as embedding a small image in JSON or transmitting binary content through a text-only interface.

However, they add overhead. Base64 typically requires about 33% more characters than the original binary data, and decoding is required to recover the bytes.

So representing binary as text is possible, but it isn't the same as treating arbitrary binary bytes as UTF-8.

## The mental model to remember

String

A sequence of text characters, represented internally using JavaScript's string model.

Buffer

A sequence of bytes that you can preserve and manipulate without interpreting it as text.

Encoding or file format

The rules that tell you how to interpret bytes—as characters, image data, compressed content, or something else.

The senior-engineer explanation: We don't treat everything as text because text encoding is a specific interpretation of bytes. Arbitrary binary data may not be valid text, and decoding it with the wrong encoding can lose information. Buffers let Node.js preserve and manipulate the original bytes correctly.
