# DailyOS — engineering notes

What I learned building DailyOS, a habit-first, local-first personal planning app. Everything here
is based on the code in this repository as of October 2026.

Live: https://princegupta-dev.github.io/dailyos/

---

## 1. What exists today

**Implemented**

- **Habits:**
  - Categories, and a schedule of daily, weekdays, specific days or weekly.
  - Optional target and unit, a minimum version, and alternatives.
  - One-tap check-off with undo, plus a log sheet (done, minimum, skipped, missed, amount, notes, tags, details per category).
  - Streaks, completion rate, a calendar for corrections, and ending a habit without losing history.
- **Today:** a progress ring, today's habits, an intention, 3 priorities, planned tasks and the evening review.
- **Tasks** with an event history; daily plans with snapshots of what was planned.
- **Learning notes** with search, topics, tags and suggested review dates (1, 7 and 30 days).
- **Reviews** (daily, weekly, monthly) with summaries computed from the records, and next actions that carry forward.
- **Insights:** this week's consistency per habit, streaks and recent notes.
- **Data:**
  - JSON backup download and checked restore ("add what's new" or "replace everything").
  - A versioned IndexedDB schema (v1–v5) with migrations.
- **App:** an installable PWA that works offline, deployed to GitHub Pages by GitHub Actions.

**Planned (not built)**

- The 4-prompt, 2-minute daily review UI. The extra review fields already exist in the schema (`src/domain/review.ts`), but no screen uses them yet.
- A local keyword suggestion engine. `src/components/TagInput.tsx` accepts suggestions, but nothing generates them yet.
- Insights and reviews broken down by category and activity log (pages read, gym, screen time).
- A sync server. [documentation/API_CONTRACT.md](documentation/API_CONTRACT.md) is a design only; there is no backend.
- Code-splitting (the build warns that the JS bundle is over 500 kB).

---

## 2. Architecture and tech stack

| Concern      | Choice                                                                                            |
| ------------ | ------------------------------------------------------------------------------------------------- |
| UI           | React 19, TypeScript (strict, `exactOptionalPropertyTypes`), React Router 7                       |
| Build        | Vite 6, `vite-plugin-pwa` (Workbox service worker + manifest)                                     |
| Storage      | IndexedDB through Dexie 4                                                                         |
| Validation   | Zod 4 (one schema per record type, reused for forms, writes and backups)                          |
| Icons        | lucide-react                                                                                      |
| Tests        | Vitest + React Testing Library + `fake-indexeddb`; Playwright (system Chrome, iPhone 13 viewport) |
| Hosting / CI | GitHub Pages, `.github/workflows/deploy.yml`                                                      |

### Layers (each one only imports from the ones below it)

```
src/features/*        screens and components (React)
src/hooks/*           useLiveData, useAction, useToday …
src/services/*        analytics.service.ts (review summaries), storage.service.ts (open DB)
src/db/repositories/* all reads and writes: validate → transaction → normalise errors
src/db/*              Dexie database, schema versions, errors, liveQuery wrapper
src/domain/*          pure types, Zod schemas and rules (no IndexedDB, no React)
src/lib/*             dates, validation helpers, groupBy, files
```

An ESLint rule enforces the boundary: UI code can't import `dexie`, `@/db/database` or `@/db/schema`. It has to go through a repository.

### Data model ([src/db/schema.ts](src/db/schema.ts))

| Table             | Notes                                                                        |
| ----------------- | ---------------------------------------------------------------------------- |
| `tasks`           | Current state of a task                                                      |
| `taskEvents`      | Append-only history; status-changing events carry `toStatus`                 |
| `dailyPlans`      | One per date (`&date` unique): intention + up to 3 priorities                |
| `planItems`       | Task placed on a day, with title/priority **snapshots**; never deleted       |
| `habits`          | Definition + schedule; `archivedOn` ends it without deleting                 |
| `habitEntries`    | One per habit per date (`&[habitId+date]` unique); status + optional details |
| `learningEntries` | Notes, with `*tags` and `*relatedTaskIds` multi-entry indexes                |
| `reviews`         | One per period (`&[periodType+periodStart]` unique)                          |
| `reviewActions`   | Next actions decided in a review                                             |
| `settings`        | Single row: time zone, week start, `lastBackupAt`                            |

---

## 3. Key concepts and how they work here

### Local calendar dates, not timestamps

A "day" is a `YYYY-MM-DD` string computed in an explicit IANA time zone
([src/lib/dates.ts](src/lib/dates.ts)):

```ts
toLocalDateKey(new Date(), "Asia/Kolkata"); // '2026-10-03'
```

- Uses `Intl.DateTimeFormat(...).formatToParts`, so no date library is needed.
- Date arithmetic (`addDays`, `startOfWeek`) runs in UTC on the date key, so daylight-saving changes can't shift a day.
- The time zone is a setting (or follows the device). Records keep the date they were saved with, even if the zone changes later.

### Derived, not stored: habit occurrences and streaks

[src/domain/habit.ts](src/domain/habit.ts) never stores "missed" days or streaks. It computes them from the habit and its entries:

- **Occurrences:** each scheduled day is an occurrence, and so is each week for weekly habits. Unscheduled days aren't occurrences at all.
- **Status of a day with no entry:** pending if it's today, missed if it's in the past.
- **Streaks:** completed extends a run, skipped is neutral, missed breaks it, and pending is ignored.
- **Rate:** completed ÷ (completed + missed). When the denominator is 0 it's `null`, shown as "Not enough data", never 0%.

Benefit: editing a schedule, correcting a past day, or a day passing never needs a migration or a background job. The streak tests in `tests/domain/habit.test.ts` pin down these rules.

### Event-sourced task history

`taskEvents` is append-only. `statusAtEndOf(date, events)` in [src/domain/task.ts](src/domain/task.ts) replays events up to a date. `derivePlanItemOutcome` in [src/domain/plan.ts](src/domain/plan.ts) uses it, so reopening a task next week doesn't change last week's plan result. Plan items also store `titleSnapshot` and `prioritySnapshot`, so later edits don't rewrite history.

### Live queries

[src/hooks/useLiveData.ts](src/hooks/useLiveData.ts) wraps Dexie's `liveQuery`
([src/db/live.ts](src/db/live.ts)):

- It returns `{ status: 'loading' | 'ready' | 'error' }`.
- It re-renders when any table the query read changes, including writes from another tab.
- Because the query function is the subscription key, callers pass a stable function (`useCallback`).

### Repositories: validate, transact, normalise

Every write in `src/db/repositories/*` follows the same pattern:

1. `parseInput(schema, draft)`: Zod validation becomes an `AppError('validation', …, { issues })`.
2. `db.transaction('rw', …)`: related writes happen together, e.g. a task change plus its event.
3. `guard()`: anything thrown becomes an `AppError` with a `kind` (`not_found`, `conflict`, `quota`, `version`, …). See [src/db/errors.ts](src/db/errors.ts).

On the UI side, `useAction().run()` shows a success or error toast and returns `{ ok }`.

### Schema versions and migrations

`SCHEMA_VERSIONS` is append-only: never edit a released version, add a new one. v5 was additive; its `upgrade()` fills defaults (`category ??= 'other'`, `tags ??= []`). `tests/db/migrations.test.ts` creates data shaped like each old version and upgrades it.

### Backup and restore

- **Pure checks** live in [src/domain/backup.ts](src/domain/backup.ts):
  - the file format;
  - the schema version (newer is refused; older is upgraded with the migration defaults);
  - every record against the same Zod schemas the app uses;
  - duplicate ids, duplicate days or periods, and references to records missing from the file.

  A file with any problem is rejected whole.

- **Writes** live in [src/db/repositories/backup.ts](src/db/repositories/backup.ts). Each restore is one transaction across all tables.
  - **Merge** keeps local data and adds only records that are new. Its preview and the actual restore share the same `planMerge()`.
  - **Replace** clears every table and writes the backup.

### PWA and deployment

- `vite.config.ts` reads `BASE_PATH`: `/` locally, `/dailyos/` on GitHub Pages. The router uses the matching `basename`.
- A small Vite plugin copies `index.html` to `404.html`, so deep links work on GitHub Pages.
- Workbox precaches the app shell (`navigateFallback: 'index.html'`), so the app opens offline.
- `deploy.yml` runs `pnpm check` and the e2e tests on every push to `main`, and deploys only if both pass.

---

## 4. Decisions and trade-offs

| Decision                                     | Why                                                    | Trade-off                                                                              |
| -------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| No backend; IndexedDB only                   | Privacy, offline, zero hosting cost                    | No sync between devices; data lost if site data is cleared (mitigated by backups)      |
| Derive streaks/rates/summaries on read       | Can't drift from data; no migrations when rules change | Recomputes from all entries; fine at personal scale, would need caching at large scale |
| Append-only task events + plan snapshots     | Honest history; past results never change              | More records; reads must replay events                                                 |
| Date keys + explicit time zone               | "Today" matches the calendar the person saw            | Must thread `today`/`timeZone` through many functions                                  |
| Zod schemas shared by forms, writes, backups | One source of truth for rules                          | Transforms (trim, dedupe) also run on restore                                          |
| Habits are ended, never deleted              | History and reviews stay intact                        | Ended habits accumulate (hidden behind a toggle)                                       |
| Merge = "keep local, add new"                | Never overwrites anything silently                     | Not a true two-way sync; newer edits in a backup are not applied                       |
| GitHub Pages + Actions                       | Free, no extra account, repo already public            | Needs base path + 404.html workaround; static only                                     |
| `registerType: 'autoUpdate'` service worker  | Updates without a prompt                               | New version applies on the next launch, not immediately                                |
| Single JS bundle                             | Simple                                                 | Over 500 kB; slower first load (code-splitting planned)                                |

---

## 5. Bugs, challenges and debugging lessons

1. **Live queries stopped updating.**
   - Cause: a read function awaited a nested native `async` helper before its other reads, and Dexie's `liveQuery` lost track of which tables it touched.
   - Fix: reads call Dexie directly, in one flat function. `tests/db/live.test.ts` guards against regressions.
2. **`Map.groupBy` isn't available everywhere** (Node 20, older Safari). I wrote my own `groupBy` in `src/lib/collections.ts`. Lesson: check feature support against the oldest runtime you target, not just your dev browser.
3. **Dexie 4 opened a database created by a newer app version** without any error. I added `openWithVersionCheck` in `src/db/database.ts`, which compares `backendDB().version / 10` (Dexie stores version × 10) and refuses to continue.
4. **A flaky test let a push through while checks were failing.**
   - Cause: topic labels and review ordering depended on IndexedDB iteration order.
   - Fix: deterministic `groupTopics` (most recent spelling wins; ties go to `localeCompare`), and explicit sort keys, plus a `position` field on review actions.
   - Process lesson: never commit or push after a failing check.
5. **`exactOptionalPropertyTypes` rejects `{ field: undefined }`.** `compact()` in `src/db/repositories/internal.ts` strips undefined values before writes.
6. **Changing a habit's status erased its notes and log.** Now `setHabitStatus` keeps the existing details unless new ones are passed. The UI asks for confirmation before clearing an entry that has details.
7. **A full disk during a restore showed a raw message** ("bulkAdd(): 1 of 2 operations failed"). Dexie wraps bulk failures in a `BulkError`. `toAppError` now looks inside `failures` to find the real cause (quota or constraint).
8. **jsdom (and Safari before 14) don't support `Blob.text()`.** `readFileText` in `src/lib/files.ts` uses `FileReader` instead.
9. **Test helpers:**
   - `setNow()` fakes only `Date`. Faking all timers would freeze IndexedDB's callbacks.
   - Each Today section loads independently, so tests use `findBy…` (which waits), not `getBy…`.
10. **Playwright `.check()` failed on the habit checkbox.** The checkbox is controlled: it only changes after the IndexedDB write lands. Fix: `click()`, then assert `toBeChecked()`.
11. **White screen after deploying.**
    - Diagnosis:
      - `curl` of the live page showed `<script src="/src/main.tsx">`, meaning the raw source had been published.
      - GitHub's public Actions API showed two workflows. A GitHub "Jekyll" starter workflow had overwritten the app, and our own workflow had failed its format check on that new YAML file, so it couldn't redeploy.
    - Fix: delete the Jekyll workflow.
    - Lesson: check what the server actually serves before debugging the app.
12. **A sub-path build returned 404s in local preview.** `vite preview` must use the same `BASE_PATH` as the build.
13. **Accessibility details caught in screenshots:**
    - The checkbox border needed 3:1 contrast as a control boundary, so it uses `--color-subtle` rather than the decorative border colour.
    - Long error messages overflowed the restore panel until it used `grid-template-columns: minmax(0, 1fr)` and `overflow-wrap: anywhere`.

---

## 6. Interview questions (with short answers)

1. **Why local-first with no backend?**
   Privacy and offline use for personal data, at zero cost. The cost is no cross-device sync, which backups cover for now. `API_CONTRACT.md` designs a future sync server.

2. **How do you decide what "today" is?**
   With a `YYYY-MM-DD` key computed in an explicit IANA time zone using `Intl.DateTimeFormat`. Records store date keys, so a later time-zone change doesn't move past days.

3. **Why aren't streaks stored?**
   They're derived from the habit's schedule and its entries on every read. Correcting a past day or editing the schedule then updates streaks automatically, with nothing to keep in sync.

4. **What are your streak rules?**
   Only scheduled occurrences count. Completed extends a run, skipped is neutral, missed breaks it, and today's unlogged occurrence is pending, so it doesn't break the streak.

5. **How do you keep last week's plan results stable after a task is reopened?**
   Task status changes are append-only events. `statusAtEndOf(date)` replays events up to that day, and plan items store title and priority snapshots.

6. **How does the UI update when data changes?**
   `useLiveData` subscribes to a Dexie `liveQuery`, which re-runs when the tables it read change, even from another tab. Read functions must call Dexie directly so the query keeps tracking them.

7. **How do you migrate IndexedDB safely?**
   Schema versions are append-only, and each upgrade only adds defaults. Tests seed data shaped like each old version and upgrade it. The app refuses to open a database created by a newer version.

8. **How do you validate data?**
   One Zod schema per record type. Repositories validate drafts before writing, and the backup restore validates every record with the same schemas.

9. **How is error handling structured?**
   Every failure becomes an `AppError` with a `kind` (`validation`, `conflict`, `quota`, `version`, and so on). `useAction` turns it into a user-facing toast.

10. **How does restore avoid corrupting data?**
    It checks the whole file first: format, version, schemas, duplicates and references. Then it writes in a single transaction across all tables, so any failure rolls everything back. A test forces a failure partway through to prove this.

11. **What does "merge" do on restore?**
    It keeps everything on the device and adds only new records. A plan, check-in or review for a day or period that already exists locally is skipped, along with its children, so nothing ends up pointing at a missing parent.

12. **How do you enforce architecture boundaries?**
    Folder layers plus an ESLint rule that forbids UI code from importing Dexie or the database directly. All data access goes through `src/db/repositories`.

13. **How do you test IndexedDB code?**
    Vitest with `fake-indexeddb`. `resetDatabase()` runs before each test, and `setNow()` fakes only `Date`. UI tests render the real router and real repositories, and Playwright runs against the production build.

14. **How does offline work?**
    `vite-plugin-pwa` generates a Workbox service worker that precaches the app shell and serves `index.html` for any page. The data is already local in IndexedDB. An e2e test turns the network off and creates and ticks a habit.

15. **How did you deploy to GitHub Pages with client-side routing?**
    The build takes a `BASE_PATH` of `/dailyos/`, and the router uses the matching `basename`. `index.html` is copied to `404.html` so deep links load. CI runs every check before deploying.

16. **Tell me about a hard bug.**
    Live queries silently stopped updating. Dexie tracks the tables a query touches, but awaiting nested native async helpers broke that tracking. I flattened the reads and added a regression test.

17. **How did you handle accessibility?**
    Native `<dialog>`, real checkbox and radio inputs with labels, `aria-current` in navigation, WCAG AA contrast tokens, 44 px touch targets, and visible focus styles. Tests query by role and name.

18. **What would break first at scale?**
    Computing everything on read: summaries and streaks scan all entries. At personal scale it's fine. At large scale I'd add date-range indexes or a cache that's invalidated on write.

---

## 7. What I'd improve and what to learn next

**Improve**

- **Code-splitting:** lazy-load routes to get the bundle under 500 kB.
- **Ask for persistent storage:** call `navigator.storage.persist()` so the browser is less likely to evict data. The app doesn't do this yet.
- **Backup reminder:** prompt when `lastBackupAt` is old.
- **Update prompt:** add a "new version available" message for the service worker instead of a silent update.
- **CI on pull requests:** today the workflow runs only on `main`, so checks happen after merge.
- **Real devices:** test on an actual iPhone and Android phone (install, offline use, file picker, download).
- **Finish the planned work:** the daily review UI, keyword suggestions and category insights.

**Learn next**

- **Sync and conflicts:** last-writer-wins vs. CRDTs, tombstones, and how local-first apps merge offline edits.
- **Service worker lifecycle:** caching strategies and update flows in depth.
- **IndexedDB performance:** compound indexes, range queries, and pagination with Dexie.
- **Accessibility testing with real screen readers** (VoiceOver, TalkBack), not just role-based tests.
- **React performance:** profiling, memoisation, and keeping live queries small.
