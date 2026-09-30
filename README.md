# Engineering Notes

My engineering knowledge base — backend, databases, distributed systems,
system design, cloud, AI, and lessons from real-world engineering.

> Learn → Build → Break → Debug → Understand → Document → **Recall**

## Topics

| Topic | Notes | Status |
| ----- | ----- | ------ |
| [Node.js internals](backend/nodejs/README.md) | Runtime, event loop, concurrency, memory, thread pool, workers & queues, streams, buffers, incidents | 🟡 Learning |
| [Git](git/README.md) | Mental model, merge/rebase, undo & recovery, remotes, safety, incident drills | 🟢 Mostly solid |
| [DSA](dsa/README.md) | Graphs (DFS/BFS) + LeetCode problem cards | 🟡 Learning |

**Planned:** Redis · Databases · Distributed Systems · System Design · Networking · Cloud · Production Engineering · Projects

## How every note is structured

Every note has the same shape, so a 6-month-old note can be revised in about 2 minutes:

```text
---                        ← frontmatter: status, confidence (1–5), last_reviewed, next_review, tags
# Title
> Prev / Next / Related    ← links: concepts don't live in isolation
## TL;DR                   ← 3–5 bullets: what I must remember
## Recall questions        ← collapsed answers: test myself BEFORE reading
## Gotchas                 ← mistakes I made or almost made
---
## Deep dive               ← full explanation, code, trade-offs, interview-ready answer
```

- **One concept per file**, numbered in learning order (`01-…`, `02-…`).
- DSA separates **patterns** (`dsa/graphs/`) from **problem cards** (`dsa/problems/`).
- Start new notes from [`_templates/concept-note.md`](_templates/concept-note.md) or [`_templates/problem-note.md`](_templates/problem-note.md).

## Review routine (spaced repetition)

```bash
./scripts/review.sh         # what's due today
./scripts/review.sh --all   # everything, by next review date
```

For each due note:

1. Read only the **TL;DR**, then answer every **Recall question** out loud *before* expanding it.
2. Reread the deep dive only for the questions you missed.
3. Update the frontmatter:
   - Recalled well → `next_review` = today + double the last gap (**1 → 3 → 7 → 14 → 30 → 90 days**), and raise `confidence`.
   - Struggled → `next_review` = tomorrow, lower `confidence`, and add what tripped you up to **Gotchas**.

Suggested habit: a 30-minute review block every Sunday, plus a 5-minute check on weekdays.

## Philosophy

I don't want to learn engineering concepts in isolation.

I want to understand how different concepts connect to each other,
how they behave in real systems, and why particular engineering
decisions are made.

Every note should answer:

1. What is it?
2. Why does it exist?
3. How does it work?
4. What problem does it solve?
5. What are the trade-offs?
6. Where have I seen it in real systems?
7. What other concepts does it connect to?
