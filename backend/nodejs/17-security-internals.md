# Lesson 14 — Node.js Security Internals

Node.js Internals Mastery · Senior Backend Engineer Track

Today, we're going to think like a senior backend engineer responsible for protecting a production system—not just writing code that works.

We'll use examples from your Node.js, TypeScript, NestJS, MySQL, Redis, and BullMQ stack.

Our central question is:

How can an API behave correctly during normal usage but become dangerous when a malicious user controls its input?

Consider your loyalty platform. A user submits a coupon code, a retailer ID, or an object used to update their profile. Your API authenticates the user and validates the request format. Does that automatically make the operation secure?

No. Security also depends on authorization, how data is interpreted, what the database executes, which resources the user can consume, and what the application trusts.

## 1. The security mindset: never trust the boundary

Imagine a request to your API:

http

```
POST /api/retailers/profile
Authorization: Bearer <token>
Content-Type: application/json
```

The request body is:

JSON

```
{
  "name": "Prince",
  "phone": "9999999999"
}
```

It looks harmless. But an attacker can change the body, send unexpected fields, repeat requests at high speed, manipulate identifiers, or submit values designed to trigger unsafe behavior.

The backend must independently enforce its security rules.

## The five security boundaries

1. Authentication

Who is making the request?

2. Authorization

Is this user allowed to perform this operation on this specific resource?

3. Input validation

Does the request satisfy the application's expected schema and business rules?

4. Safe data handling

Are values handled safely by SQL, object operations, file paths, shell commands, and external APIs?

5. Resource protection

Can someone exhaust your CPU, memory, database connections, queues, or third-party API quota?

These boundaries complement each other. A request can pass validation and still be unauthorized. An authenticated user can still abuse a vulnerable endpoint.

## 2. Mass assignment: when a normal update becomes a privilege escalation

Let's start with a realistic NestJS bug.

Your retailer profile endpoint accepts a request and passes it directly to Sequelize:

TypeScript

```
// Vulnerable pattern
await Retailer.update(req.body, {
  where: { id: retailerId },
});
```

The intended request contains a name and phone number. But the client can submit additional fields:

JSON

```
{
  "name": "Prince",
  "phone": "9999999999",
  "isAdmin": true,
  "walletBalance": 100000
}
```

If those fields are accepted and writable, the user may be able to change properties they should never control.

This is called mass assignment, and it falls under broken object property-level authorization in the OWASP API Security Top 10.

![](https://www.google.com/s2/favicons?domain=https://api-security.owasp.org&sz=32)

OWASP API Security Top 10

+1

### The fix: allowlist writable fields

TypeScript

```
const { name, phone } = updateRetailerSchema.parse(req.body);

await retailer.update({
  name,
  phone,
});
```

With a validation library such as Joi, Zod, or `class-validator`, validate the request against an explicit schema. Also ensure the update operation uses the authenticated user's authorized retailer record.

For NestJS DTOs, a common approach is to enable strict validation and reject unexpected properties:

TypeScript

```
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }),
);
```

`whitelist` removes properties that don't have validation decorators; `forbidNonWhitelisted` rejects requests containing such properties. These settings help, but they do not replace authorization checks.

Senior-level rule: never let a client decide which internal model properties it is allowed to change.

## 3. Broken object-level authorization: changing an ID

Suppose your API exposes:

http

```
GET /api/retailers/1024
```

Your code retrieves the retailer using the ID from the URL:

TypeScript

```
const retailer = await Retailer.findByPk(retailerId);
```

The query may be perfectly safe from SQL injection. The problem is that the authenticated user might not own retailer `1024`.

An attacker could change the ID and access another tenant's data. This is broken object-level authorization (BOLA), a major API security risk.

![](https://www.google.com/s2/favicons?domain=https://api-security.owasp.org&sz=32)

OWASP API Security Top 10

+1

A safer pattern scopes the lookup to the authorized tenant or principal:

TypeScript

```
const retailer = await Retailer.findOne({
  where: {
    id: retailerId,
    tenantId: authenticatedUser.tenantId,
  },
});

if (!retailer) {
  throw new NotFoundException("Retailer not found");
}
```

This is illustrative: your actual policy may need to scope by ownership, project membership, assigned territory, or role.

For your multi-tenant GPI architecture, tenant isolation should be enforced in the data-access layer, not merely by hiding other tenants' IDs in the frontend.

## 4. SQL injection: the difference between data and executable instructions

Imagine a login endpoint that builds a SQL query by concatenating strings:

TypeScript

```
// Vulnerable pattern
const sql =
  `SELECT * FROM users WHERE phone = '${phone}'`;
```

The problem is that user-controlled input is being interpreted as part of the SQL program, rather than exclusively as a value.

The safer approach is a parameterized query:

TypeScript

```
const [users] = await sequelize.query(
  "SELECT * FROM users WHERE phone = :phone",
  {
    replacements: { phone },
  },
);
```

Sequelize safely binds or escapes the parameter according to its query mechanism. The SQL structure remains separate from the supplied value.

For ORM queries, prefer structured conditions:

TypeScript

```
const user = await User.findOne({
  where: { phone },
});
```

A few distinctions matter:

- Values should be parameterized.

- Dynamic identifiers, such as column names or sort directions, generally cannot be handled like ordinary values. Map client choices to a fixed allowlist.

- Avoid constructing raw SQL fragments from untrusted input.

- Use a database account with only the permissions the application needs.

Parameterization is a primary defense against SQL injection; input validation is an additional layer, not a substitute.

![](https://www.google.com/s2/favicons?domain=https://github.com&sz=32)

GitHub

+1

## 5. Prototype pollution: a JavaScript-specific security risk

This is particularly important for Node.js engineers because it involves how JavaScript objects inherit properties.

Normally, an object can inherit properties from its prototype:

JavaScript

```
const user = { name: "Prince" };

console.log(user.name); // "Prince"
console.log(user.toString); // Inherited method
```

Now imagine an unsafe recursive merge function processes attacker-controlled objects and modifies `Object.prototype`. Properties added there can affect unrelated objects throughout the process.

This family of bugs is known as prototype pollution. The Node.js security guidance discusses unsafe object merges, dangerous prototype-related properties, and defensive coding practices.

![](https://www.google.com/s2/favicons?domain=https://github.com&sz=32)

GitHub

+1

### Where the danger appears

Consider an API that lets a user customize an application configuration:

TypeScript

```
// Risky design
const config = deepMerge(defaultConfig, request.body);
```

If `deepMerge` is vulnerable and accepts malicious prototype-related keys, the attacker may influence behavior beyond the intended configuration object.

The exact impact depends on the merge implementation and how the resulting objects are used. It can range from logic errors to denial of service or, in certain vulnerable application chains, more serious consequences.

### How to defend against it

- Prefer explicit schemas and allowlisted fields over generic deep merging.

- Keep dependencies that perform object merging updated.

- Avoid using untrusted object keys to mutate shared configuration.

- Use `Object.hasOwn(obj, key)` when checking for an object's own properties rather than inherited properties.

- Consider null-prototype dictionaries for appropriate key-value maps.

- Never assume that TypeScript interfaces validate incoming JSON at runtime.

For example, TypeScript's declaration:

TypeScript

```
interface UpdateProfileDto {
  name: string;
}
```

does not prevent a client from sending additional properties. Runtime validation is still necessary.

## 6. Command injection: when input reaches the operating system

Imagine your backend creates a report by invoking a command-line utility.

TypeScript

```
// Dangerous pattern
exec(`convert ${uploadedFilename} report.png`);
```

If untrusted input is inserted into a shell command, shell metacharacters may change the command's meaning. The application could execute unintended commands with the privileges of the Node.js process.

The Node.js security guidance explicitly warns against exposing shell-execution APIs to untrusted input without proper controls.

![](https://www.google.com/s2/favicons?domain=https://github.com&sz=32)

GitHub

+1

### Safer approaches

Prefer a library API when one is available. If a subprocess is necessary, use `spawn` or `execFile` with an executable selected by trusted application code and a separate argument array, rather than building a shell command from user input.

TypeScript

```
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const result = await execFileAsync(
  "/usr/bin/convert",
  [validatedInputPath, validatedOutputPath],
  {
    shell: false,
    timeout: 10_000,
    maxBuffer: 1024 * 1024,
  },
);
```

This is safer against shell interpretation, but it is not a complete sandbox. You must still validate paths, control the executable and arguments, limit resource consumption, and run with minimal OS privileges.

Remember: escaping a dangerous string is usually more fragile than avoiding the dangerous interpretation entirely.

## 7. Path traversal: escaping the directory you intended

Suppose your service downloads invoice files:

TypeScript

```
const filePath = join(uploadDirectory, requestedFilename);
```

If the client can supply arbitrary path components, the resulting path may point outside the intended directory.

A common defense is to accept an application-level file identifier instead of a filesystem path. Resolve the file from a trusted database record. If you must accept a filename, validate it and verify the resolved path remains inside the permitted directory.

TypeScript

```
import path from "node:path";

function resolveUploadPath(
  uploadDirectory: string,
  filename: string,
) {
  if (
    filename.includes("/") ||
    filename.includes("\\") ||
    filename === "." ||
    filename === ".."
  ) {
    throw new Error("Invalid filename");
  }

  const root = path.resolve(uploadDirectory);
  const target = path.resolve(root, filename);
  const relative = path.relative(root, target);

  if (
    relative === "" ||
    relative.startsWith("..") ||
    path.isAbsolute(relative)
  ) {
    throw new Error("Path escapes upload directory");
  }

  return target;
}
```

Adjust the empty-relative-path check if the application intentionally allows access to the directory itself. For ordinary uploaded files, it is usually better to reject directory access entirely.

There are also filesystem edge cases involving symbolic links and time-of-check/time-of-use races. For security-sensitive file operations, use controlled storage layouts and appropriate filesystem permissions rather than relying only on string checks.

## 8. SSRF: when your server becomes the attacker's network client

SSRF means Server-Side Request Forgery.

Imagine you build a feature that fetches an image from a URL provided by the client:

TypeScript

```
// Risky design
const image = await fetch(req.body.imageUrl);
```

If the destination isn't properly controlled, a user may trick your backend into making requests to internal services or cloud metadata endpoints that aren't intended to be publicly accessible.

This is particularly relevant when your Node.js application runs in AWS, Docker, or Kubernetes. Internal network reachability can make a server-side request more powerful than the same request from a user's browser. SSRF is included in the OWASP API Security Top 10.

![](https://www.google.com/s2/favicons?domain=https://api-security.owasp.org&sz=32)

OWASP API Security Top 10

+1

### How to defend against SSRF

1. If possible, accept a resource identifier instead of an arbitrary URL.

2. Allowlist approved schemes, hosts, and ports.

3. Validate DNS resolution and the actual destination IP, including IPv4 and IPv6.

4. Block loopback, private, link-local, and other prohibited address ranges where appropriate.

5. Disable redirects or validate every redirect destination.

6. Apply outbound network restrictions so application-level checks aren't the only defense.

7. Set connection and response timeouts, and cap response size.

A simple hostname allowlist alone is not sufficient if DNS rebinding or redirects can bypass the intended restriction.

For systems that fetch external resources, the network policy is part of the security boundary—not just the URL validation code.

## 9. Denial of service: when a valid request becomes too expensive

Not every security incident requires code execution or database compromise. Sometimes an attacker repeatedly calls a legitimate endpoint until the service runs out of resources.

Think of your existing OTP endpoint:

http

```
POST /api/auth/send-otp
```

Even if authentication and validation are correct, an attacker might repeatedly trigger SMS messages, creating cost, consuming provider quotas, and degrading service.

OWASP identifies unrestricted resource consumption and unrestricted access to sensitive business flows as distinct API risks.

![](https://www.google.com/s2/favicons?domain=https://api-security.owasp.org&sz=32)

OWASP API Security Top 10

+1

For your backend, apply limits at several levels:

|
Resource

|

Example control

|
| --- | --- |
|

Request volume

|

Rate limits by account, IP, device, or phone number

|
|

Request size

|

Body-size limits and upload limits

|
|

CPU

|

Bound expensive computation and use worker pools

|
|

Database

|

Query timeouts, pagination, connection-pool limits

|
|

External APIs

|

Concurrency limits, timeouts, circuit breakers

|
|

BullMQ

|

Bounded intake, worker concurrency, backlog monitoring

|
|

OTP / rewards

|

Business-specific quotas, atomic counters, abuse detection

|

A per-IP rate limiter alone may not protect an OTP endpoint because distributed clients can use many IP addresses. Apply business-level limits too, while accounting for shared networks and legitimate users.

For your Redis-backed reward system, ensure quota reservation is atomic. A check-then-increment sequence without appropriate atomicity can allow concurrent requests to exceed a reward limit.

## 10. Secrets, dependencies, and deployment security

A secure API can still be compromised through exposed credentials, vulnerable dependencies, or unsafe deployment settings.

Secrets management

Keep database passwords, API keys, JWT signing keys, and payment credentials out of source control and logs. Use an appropriate secret manager or protected deployment configuration, rotate exposed credentials, and grant only necessary permissions.

Dependency security

Review dependency updates, audit known vulnerabilities, remove unused packages, and treat package installation scripts and dependency provenance as part of your supply-chain risk.

Least privilege

Use a database account with restricted permissions, scoped AWS IAM roles, non-root containers where practical, and minimal network access. Do not expose Node.js inspector ports or internal administration endpoints publicly.

Observability

Log security-relevant events with appropriate request or correlation IDs, avoid logging secrets and sensitive personal data, and alert on unusual authentication failures, quota abuse, and privilege violations.

Node.js's security guidance also emphasizes that application code and installed dependencies run with the privileges of the process. That makes dependency integrity and restrictive runtime permissions important layers of defense.

![](https://www.google.com/s2/favicons?domain=https://github.com&sz=32)

GitHub

+1

## 11. Security review checklist for your NestJS API

Use this checklist when reviewing an endpoint before production deployment.

## API security review

0/9

Authentication

Is the caller's identity verified, and are token expiry and signing handled correctly?

Object-level authorization

Can this user access this specific retailer, project, campaign, or reward?

Property-level authorization

Can the client change only the fields it is allowed to change?

Input validation

Are body, query, path parameters, and uploaded files validated at runtime?

Injection safety

Are SQL queries parameterized and shell execution avoided or tightly controlled?

Resource limits

Are body sizes, concurrency, timeouts, rate limits, and queue growth bounded?

External requests

Are outbound URLs, redirects, destinations, and response sizes controlled?

Secrets and privileges

Are credentials protected and database, IAM, and process privileges minimized?

Failure recovery

Are retries safe, payouts idempotent, and security events observable?

Copy checklist

For a structured reference, see the [OWASP API Security Top 10](https://api-security.owasp.org/editions/2023/en/0x11-t10/)  and the [Node.js Security Best Practices](https://github.com/nodejs/learn/blob/main/pages/getting-started/security-best-practices.md) .

## 12. Your checkpoint — think like a security engineer

Answer these five scenarios in your own words. Focus on the root cause and the defense, rather than memorizing definitions.

Scenario 1

Your API accepts a retailer profile DTO. A user submits {"name":"Prince","isAdmin":true}. Explain mass assignment and how you would prevent it in NestJS.

Scenario 2

A logged-in promoter changes /retailers/101 to /retailers/102 and sees another tenant's retailer. Why is authentication insufficient, and how would you fix the data-access layer?

Scenario 3

A developer concatenates user input into a SQL query. Explain the underlying security problem and how parameterized queries help.

Scenario 4

Your backend fetches arbitrary image URLs supplied by clients and runs inside AWS. Explain SSRF and name the defenses you would implement.

Scenario 5

Your OTP API is rate-limited by IP, but SMS costs are still increasing because of automated abuse. What additional controls would you introduce?

Review my answers

Next lesson: Lesson 15 — Production Debugging and Observability. We'll investigate incidents using logs, metrics, traces, CPU profiles, heap snapshots, event-loop delay, and real-world debugging workflows for Node.js services.
