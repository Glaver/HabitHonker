# Gamification Phase 4 Plan — Behavior Foundation Before Cutover

> **SUPERSEDED — do not use as a spec.** Authoritative: `Docs/HabitHonkerExp-v1.1.2.md` (architecture/ADRs) and `Docs/HabitHonkerExp-v1.1.2-Claude-Phase4.md` (execution prompt). Every default in this draft that differs from them is void. Only the code facts and file/line references below remain useful as background (as of commit `2e569af`).

**Status:** plan only. No production or test code changed.
**Checked against:** commit `2e569af` (Phase 3, 112/112 tests), the Phase 1–3 reports, `GamificationTransactionContract.md`, `GamificationArchitectureInvestigation.md` and `AppAudit-2026-09-23.md`.
**Roadmap reviewed:**

```text
1 Math ✅ → 2 Persistence ✅ → 3 Atomic transaction ✅
→ 4 Foundation (A metadata-safe · B revision writer · C identity · D planner · E enrollment · F storage gating · G reconciliation)
→ 5 Live cutover → 6 Reversal/restore → 7 Weekly review → 8 DuckState/UI
```

---

## 1. Verdict on the roadmap

The order is right. Moving schedule revisions, occurrence identity, the planner, enrollment and reconciliation **before** the cutover fixes the biggest flaw of the earlier 11-phase plan. There, occurrences would have gone live in Phase 5 without revisions. Their frozen `scheduleRevisionID` would have stayed `nil` forever, because the Phase 3 transaction rejects any later command whose snapshot differs from the stored one.

Five adjustments:

1. **Split Phase 4 into separate runs, 4A to 4G.** Each run gets its own fresh baseline, gate, report and commit. Phase 3 alone ran out of tokens part-way. Seven foundation items in one run would be worse.
2. **Run order: A → F → C → B → E → D → G** (dependencies in §4). F and C are small and independent, so they can share one run.
3. **G is a cutover blocker, not polish.** CloudKit has no unique constraints. Two devices will create duplicate profile, occurrence, ledger and same-day record rows. The frozen Phase 3 transaction throws on every one of these (`duplicateProfileKey`, `duplicateOccurrenceKey`, `duplicateLedgerLogicalKey`, `inconsistentStoredState("multiple legacy records in day")`). Without G, every later completion of an affected habit would fail after the cutover.
4. **Phase 5 needs a kill switch and a legacy fallback.** The old plan had "behavior live, rewards shadow" and "ledger shadow" stages. The new one goes straight to atomic rewards. That is fine, because nothing is visible until Phase 8, so Phases 5–7 *are* the shadow period. But Phase 5 must never fail a completion because of gamification (§5).
5. **Phase 7 needs schema V3.** `WeeklyGamificationSnapshotSD` is **not** in V2 (V2 added only Occurrence, ScheduleRevision, Event, Profile and Ledger). V1/V2 still point at the live model classes (audit P6), so the first schema change will break migration. Freeze V1/V2 model copies before Phase 7. **Phase 4 itself must stay schema-free.** Every field it needs already exists in V2. This was verified field by field for revisions (effectiveFrom/To, weekday mask, hour/minute, dueAt, tz/calendar, priority, icon, notification) and for the profile (trackingStartedAt, tz, calendar).

---

## 2. Starting point (what Phase 3 hands over)

| Exists (frozen) | Missing, and which sub-phase adds it |
|---|---|
| `BehaviorTransactionSD` one-context/one-save completion, durable receipts, reward dedup | Metadata writes still rewrite `records` → **4A** |
| Pure `GamificationService`, `RewardCalculator`, `LevelCalculator` | Nothing knows whether the store is durable → **4F** |
| V2 tables for occurrence/revision/event/profile/ledger (empty) | No canonical keys, day keys or profile key → **4C** |
| DI: one shared repository actor, service not consumed by live code | No revisions written anywhere → **4B** |
| | No profile; the transaction throws `profileNotFound` → **4E** |
| | Commands must be hand-built; no streak/eligibility/on-time logic → **4D** |
| | Duplicates are detected but never repaired → **4G** |

---

## 3. Decisions to approve

4A needs none of these. 4C onward depends on them. Each row has a recommended default; change any you disagree with before the run that needs it.

| ID | Question | Recommended default | Needed by |
|---|---|---|---|
| D1 | Sync guarantee | **Provisional/convergent.** Exactly-once locally; cross-device duplicates are repaired by G. No global exactly-once claim. (Investigation §9 "strict" option = separate CloudKit zone adapter, not in scope.) | G, 5 |
| D2 | Which time zone defines an occurrence day | The profile's **fixed** time zone plus the Gregorian calendar, captured at enrollment. The legacy `HabitRecord` day keeps using the **device** calendar, so Statistics stay identical. | C, D |
| D3 | Occurrence granularity | Repeating: one occurrence per local day (`day:<date>`), rewarded once. One-time: one lifetime occurrence (`once`). Extra taps only raise the count. (Phase 3 already assumes this.) | C, D |
| D4 | Off-schedule and timing | Repeating habit completed on an unscheduled day ("Not for today" swipe): an occurrence is recorded with provenance `offSchedule`, **ineligible**, and it doesn't touch the streak. One-time completed early or late: the same `once` occurrence, eligible; `isOnTime` = completed on or before the due date's local day. A repeating completion on a scheduled day is always on time, because the app can't complete a past day. | D |
| D5 | Streak | Consecutive **scheduled** days completed. Unscheduled days don't break it. A scheduled day that ended without a completion resets it to 0. Today's pending occurrence doesn't break it. It starts at 0 at enrollment (no seeding from legacy records). One-time is always 0. | D |
| D6 | Type change (repeating ↔ one-time) | Allowed. If the other namespace already has a completed occurrence on the same local day, the new occurrence is **ineligible** and linked through `predecessorOrAliasOccurrenceID`. This prevents farming rewards by toggling the type. | D |
| D7 | Enrollment | Automatic at launch on durable storage. **First called in Phase 5**, not in Phase 4. `trackingStartedAt` = enrollment instant. No retroactive rewards. | E, 5 |
| D8 | Store scope (audit P2) | V1 accepts one profile per store file and documents that toggling iCloud sync switches to a different profile. Fix P2 (two store files; "sync off" probably still syncs) as a separate privacy fix before Phase 5 ships. | F, E |
| D9 | Conflicting duplicates in G | Identical duplicates: delete the non-canonical rows. Conflicting payloads: a deterministic winner (earliest business timestamp, then smallest physical UUID string), logged. Same-day legacy records: merge by summing counts. | G |

---

## 4. Sub-phases

Dependencies: **A** (none) · **F** (none) · **C** (D2, D3) · **B** (A, C) · **E** (F, B, C) · **D** (B, C, E) · **G** (C, E, D1, D9).

Rules for every sub-phase: fresh baseline first (stop if it fails); no schema change; no user-visible change; do not weaken existing assertions; each run writes `Docs/GamificationPhase4<X>Report.md` and stops before the next letter.

### 4A — Metadata-safe persistence (ready now)

**Why this is a live bug, not just a cutover prerequisite** (all lines at `2e569af`):

- `HabitMapper.apply` (`HabitMapper.swift` L120–141) builds new `HabitRecordSD` objects for the whole history and assigns `sd.records = newRecords`. The old rows stay in the store with `habit == nil`. Every completion, priority change and edit adds N orphans.
- `HabitDetailView.savedItem()` (L53–81) returns the `record` array captured when Details opened. `HabitService.saveHabit` (L26–30) upserts it, so a completion that happened in between is overwritten.
- **Concrete in-app sequence:**
  1. Swipe-complete a habit. The completion is queued behind the per-UUID coordinator.
  2. Tap the row before it lands. Details opens with the stale `viewModel.items` value.
  3. Tap Save. The coordinator runs the completion first (count 1), then the save writes the stale array back (count 0).
  4. CloudKit imports from another device hit the same path.
- `upsert` (`HabitsRepositorySwiftData.swift` L299) **inserts** when the row is missing, so a stale save can bring back a deleted habit.
- `completeHabit` and `changePriority` (`HabitService.swift` L37–51) read and write the whole model in **two** actor hops. `PriorityMatrixViewModel` (L75–89) isn't behind the list's coordinator.
- **After cutover this gets worse.** A stale save that drops the record referenced by `TaskOccurrenceSD.legacyRecordID` makes the *next* completion of that occurrence throw `inconsistentStoredState("missing occurrence legacy projection")` (`BehaviorTransactionSD.swift` L60). Completion would break, not just lose a count.

**Target API**

- `HabitMetadata` value type: every `HabitModel` field **except** `record`.
- Repository actor methods, one context and one save each, placed below `// MARK: - CRUD`:
  - `createHabit(id:metadata:)` throws `alreadyExists`.
  - `updateMetadata(id:metadata:) -> HabitModel` throws `notFound` and never inserts.
  - `updatePriority(id:priority:) -> HabitModel`.
  - `recordLegacyCompletion(id:at:calendar:) -> HabitModel`: find or insert the day record and increment it, in one call.
- None of these touch `records` except `recordLegacyCompletion`.
- `upsert` leaves the protocol and all production paths. `HabitMapper.apply` becomes `applyMetadata`.
- `HabitService`: `createHabit`, `updateHabit` (ignores `record`), `completeHabit` → `recordLegacyCompletion`, `changePriority` → `updatePriority`. The clock and calendar are injected, with defaults.
- `HabitListView` routes `.addNewHabit` → `createItem` and `.detailHabit` → `saveItem`. The view models store the **returned** fresh model, not the submitted draft.
- If an update fails with `notFound`, cancel that habit's notifications. Otherwise a save queued after a delete leaves orphan alarms, since notifications are rescheduled before persistence (audit L4).

**Gate:** see the prompt in §6. Its core test fails on the baseline and passes afterwards: *complete, then save a stale draft, and the count must stay 1.*

**Out of scope:** cleaning existing orphan rows (unsafe during a CloudKit import; needs its own rule), restore/purge record moves (no restore UI), one-time "done" semantics (audit L1), showing errors in Details (L2), Details dismiss-before-save.

### 4F — Durable-storage gating

- Add a `StorageMode` enum (`cloudKit`, `local`, `inMemoryFallback`). Decide it in `HabitHonkerApp.rebuildContainerIfNeeded` (L49–96), where the container is chosen, and pass it into `AppDependencies.make(container:storageMode:)`.
- Replace the bare `try?` with do/catch that **logs** the error. Keep the fallback behavior identical (the blocking error screen is audit P3, a separate UX change).
- Add a gate that enrollment and the Phase 5 cutover consult. It refuses on `inMemoryFallback`, and on the `RootTabsView` path where `dependencies == nil`, which builds services without DI.
- **Gate tests:** the mode reaches DI; the fallback reports non-durable; the gate refuses; nothing else changes.

### 4C — OccurrenceIdentity (pure)

- Canonical strings (freeze the format in tests):
  - Profile: `profile:v1:default`
  - Repeating occurrence: `occ:v1:<UUID>:day:YYYY-MM-DD`
  - One-time occurrence: `occ:v1:<UUID>:once`
  - Revision: `rev:v1:<UUID>:<UUID>`
  - Command / transition: `cmd:v1:<UUID>` / `tr:v1:<UUID>`
- UUIDs use the uppercase `uuidString` form.
- **Transition IDs must be random per action.** Never derive them from a count: two devices would both produce "count 2", and the next local command would hit `conflictingTransitionID`.
- `LocalDay` holds a key plus a half-open `DateInterval`, computed from a **supplied** Gregorian calendar and time zone. Digits are built from date components, not a `DateFormatter`, so the user's locale can't change them.
- **Gate tests:**
  - DST days of 23 h and 25 h.
  - Midnight boundaries.
  - Year change.
  - A Buddhist or Japanese device calendar doesn't change the key.
  - The same instant in two time zones.
  - Round trip.
  - Source guard: no `Date()`, `Calendar.current`, `TimeZone.current`, `Locale.current` or `Hasher`.

### 4B — ScheduleRevision writer

- Write revisions **inside the same actor call and save** as `createHabit`, `updateMetadata` and `updatePriority` (from 4A) and the existing `delete` and `restoreDeletedHabit`. Put the logic in a synchronous helper, `ScheduleRevisionWriterSD`, the same pattern as `BehaviorTransactionSD`.
- **Fields that trigger a revision:** type, weekday mask, hour/minute (repeating, taken from `dueDate`), `dueAt` (one-time), priority, icon, notification enabled, time zone and calendar. Changes to title, description, tags or color write none.
- **On a relevant change:** close the open revision (`effectiveTo = now`) and open a new one. Create opens the first revision. Delete closes it. Restore opens a new one.
- `now` and the time zone are injected. Use the profile's time zone if enrolled, otherwise the device's. Store both identifiers.
- Written regardless of enrollment, so history collection starts early. Existing habits get their baseline revision in 4E.
- **Guard change.** The Phase 2 guard (`GamificationPersistenceTests` L164–173) forbids `BehaviorScheduleRevisionSD` in `HabitsRepositorySwiftData.swift`. Narrow it **deliberately and document it**, the way Phase 3 did for `GamificationService`. Keep the guards for Occurrence, Event, Ledger and Profile. Tests that assert "all new tables empty" after a *metadata* write narrow to "no rows except revisions". Completion-only tests stay as they are.
- **Gate tests:**
  - Revision on create.
  - None on a title-only edit.
  - Close and open on each relevant field.
  - Exactly one open revision per target after any sequence.
  - Delete closes it.
  - Failure injected before save: neither the metadata nor the revision persists.

### 4E — Profile enrollment

- `enrollIfNeeded(now:timeZone:storageMode:) -> EnrollmentResult`: one context, one save.
  - `.notDurable` on fallback storage.
  - `.alreadyEnrolled` when one profile exists.
  - `.duplicateProfiles` with no write when there is more than one (G repairs).
  - Otherwise create `profile:v1:default` (`trackingStartedAt = now`, the time zone, Gregorian, zero balances) plus **baseline revisions** for every active habit without an open one.
- No occurrence, event or ledger rows. No retroactive rewards. Existing habits and records untouched.
- **Not called by the live app in Phase 4** (D7).
- **Gate tests:**
  - Idempotent across an on-disk reopen.
  - Fallback refuses.
  - Duplicates refuse.
  - Baselines exist for active habits, none for deleted ones.
  - Rollback on an injected failure.

### 4D — OccurrencePlanner

- A pure function: `plan(intent, facts) throws -> BehaviorCompletionCommand`.
  - `intent`: target, `commandID`, `completedAt`, device calendar, source.
  - `facts`: habit metadata, profile policy, the revision in effect, the **existing occurrence row** for the computed ID, the previous scheduled day's occurrence, and any same-day alias.
- **Critical rule:** if the occurrence row already exists, copy its frozen snapshot and reward input **verbatim**: priority, type, streaks, eligibility, revision ID, `scheduledAt`/`dueAt`, icon, notification, provenance and alias.
  - Failing sequence without this rule: complete Gym at 9:00 (priority P1); change the priority to P2 at 10:00; complete again at 11:00. The planner rebuilds from the new revision, and `validateSnapshot` (`BehaviorTransactionSD.swift` L146–158) throws `conflictingOccurrenceSnapshot`, so the second tap fails.
  - Changing the reminder time breaks it too (`scheduledAt`).
- New occurrence: facts come from the **revision**, never from mutable `HabitSD`.
- The occurrence key uses the profile's time zone. `legacyDay` and `legacyCompletionDate` use the **device** calendar, so Statistics don't change.
- **Streak in O(1):** `streakBefore` = the `streakAfter` of the occurrence on the previous scheduled local day (per the revision in effect then) if that one was completed; otherwise 0. Off-schedule occurrences are skipped.
- `PlanningFactsReaderSD` is a synchronous reader over a supplied `ModelContext`. In Phase 5, reader, planner and transaction run in **one actor call with no await between read and commit**. That rules out a gap between planning and applying. The Phase 3 contract stays untouched.
- **Gate tests (table-driven):**
  - Scheduled day, unscheduled day.
  - One-time early, on time, late.
  - Second tap after a priority edit is **accepted by the real Phase 3 transaction**.
  - Streak runs across unscheduled days, and breaks.
  - DST.
  - Profile time zone ≠ device time zone.
  - Same-day type change → ineligible alias.
  - A later schedule edit leaves existing occurrences unchanged (the old plan's Phase 8 gate).

### 4G — Reconciliation foundation

- `BehaviorReconciler` actor operation, one context, one save, idempotent. A second run makes no writes.
  - Canonical row per logical key (D9).
  - Delete identical duplicates of profile, occurrence, event, ledger and revision rows.
  - Recount `completionCount` from distinct `transitionID`s.
  - Merge same-day legacy records **attached to a habit** and re-point `legacyRecordID`. Never touch orphans.
  - Close overlapping open revisions, keeping the latest `effectiveFrom`.
  - **Rebuild profile balances from distinct ledger logical keys.** CloudKit resolves the profile row last-writer-wins, so stored balances drift.
  - Return a report.
- Not called live in Phase 4. Phase 5 calls it at launch, and once more on a duplicate or inconsistent-state error before retrying.
- **Gate tests:** two-device simulations built by inserting rows directly, in shuffled order, with conflicting payloads.
  - After reconciling, the Phase 3 transaction succeeds.
  - Balances equal the sum over distinct ledger keys.
  - Orphans stay untouched.
- **Documented limit:** this gives convergence, not global exactly-once (D1).

---

## 5. Phase 5 entry checklist (for later)

- All 4A–4G gates passed and committed. D1–D9 approved.
- Launch order: container → storage mode → `enrollIfNeeded` → reconcile → UI.
- `completeHabit` = one actor call {read facts → plan → apply}.
  - Non-durable storage or not enrolled → `recordLegacyCompletion`.
  - Duplicate or inconsistent-state error → reconcile, retry once, then fall back to legacy and log.
  - **A completion must never fail because of gamification.**
- A feature flag (`enableGamificationCutover`) as the kill switch, plus a DEBUG-only inspector for profile and ledger.
- Statistics identical: the transaction writes the legacy projection.
- Existing orphan-row cleanup and audit P2 decided.

---

## 6. Paste-ready Codex prompt — 4A

```text
We are implementing PHASE 4A of the HabitHonker Gamification architecture: METADATA-SAFE PERSISTENCE.
Phases 1–3 are FROZEN (commit 2e569af, 112/112 tests). Read first:
- Docs/GamificationPhase4Plan.md (§4A is the spec for this run; §1–2 for context)
- Docs/GamificationPhase3Report.md §16 and Docs/GamificationTransactionContract.md
- Docs/AppAudit-2026-09-23.md, items P1 and P4 only

GOAL
Metadata writes (Details Save, Priority Matrix) can never rewrite, drop or duplicate completion
records and can never resurrect a deleted habit. Legacy completion becomes one actor call.
User-visible behavior stays the same.

PREFLIGHT — stop and report if any step fails
1. git status clean; record HEAD.
2. Fresh baseline, expect 112/112:
   xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
     -destination 'platform=iOS Simulator,id=24629C99-E950-4563-BA70-118CE5D96451' \
     -derivedDataPath /private/tmp/habithonker-phase4a -only-testing:HabitHonkerTests
3. Before changing production code, add test R1 (below) and run it on the baseline.
   It MUST fail (today's count 0 instead of 1). Record the failure. If it passes, STOP:
   the premise is wrong.

IMPLEMENTATION
1. Add HabitMetadata: every HabitModel field except `record`; init(_ habit: HabitModel).
2. HabitsRepositorySwiftData — add these BELOW `// MARK: - CRUD`. The Phase 3 structural test
   (BehaviorTransactionDITests) inspects the window between `private func executeBehavior` and
   `// MARK: - CRUD`; put nothing new in that window. Each method: one makeContext(), one save.
   - createHabit(id:metadata:) throws -> HabitModel — zero records; throws alreadyExists if id exists.
   - updateMetadata(id:metadata:) throws -> HabitModel — throws notFound if missing, NEVER inserts;
     assigns metadata fields only; never reads, assigns or recreates `records`; returns the
     fresh model including current records.
   - updatePriority(id:priority:) throws -> HabitModel — same rules, priority only.
   - recordLegacyCompletion(id:at:calendar:) throws -> HabitModel — notFound if missing; record on
     the same `calendar` day → count += 1, keep its id and date; none → insert
     HabitRecordSD(date: at, count: 1, habit:). If several match the day, increment the one with
     the earliest date, then smallest UUID string. Do not merge.
   - HabitMapper: replace apply(_:to:) with applyMetadata(_:to:) that never touches records.
     makeSD/makeDeletedSD/deletedToDomain unchanged.
   Add HabitRepositoryError { notFound(UUID), alreadyExists(UUID) }.
3. Remove upsert from HabitRepositoryProtocol and SwiftDataHabitRepository. Remove the actor's
   upsert/save/update from production. If tests need seeding, add a test-target helper that
   inserts HabitSD via ModelContext, or keep the old methods under #if DEBUG marked
   "test seeding only".
4. HabitService: createHabit(_:) -> HabitModel (.created); updateHabit(_:) -> HabitModel
   (.updated; builds HabitMetadata, ignores `record`); completeHabit(id:) uses
   recordLegacyCompletion with injected `now: () -> Date` and `calendar: () -> Calendar`
   (defaults Date() / Calendar.current), and returns nil on notFound to keep its contract;
   changePriority uses updatePriority. Events are sent only after success, same kinds as today.
   Update HabitServiceProtocol and every spy.
5. HabitListViewModel: add createItem(_:) and keep saveItem(_:) for updates. Both keep the per-UUID
   coordinator and today's order (notification reconcile, then persist). Store the RETURNED model
   in memory, not the submitted draft. If updateHabit throws notFound, call
   notifier.cancel(for: id) so no alarm survives for a deleted habit.
   HabitListView: the .addNewHabit route calls createItem; .detailHabit calls saveItem.
   No other UI change.
6. PriorityMatrixViewModel: no logic change; it receives the fresh model.

RULES
- No schema/model changes: every *SD file, HabitSchemaMigration, the migration plan and
  HabitHonkerApp are untouched. AppDependencies should need no change.
- No changes to notification semantics, statistics, BehaviorTransaction*, Gamification*,
  Details dismissal or error UX.
- Do not weaken any assertion. NotificationInvestigationTests (AuditRepository spy) and
  HabitListViewModelNotificationTests (HabitServiceSpy) use upsert or saveHabit: migrate the
  spies and call-count assertions to the new methods; keep every behavioral assertion (titles,
  counts, pending notifications, ordering, no resurrection).
- The Phase 2 and Phase 3 source guards must pass UNCHANGED.
- Out of scope: cleaning existing orphan HabitRecordSD rows; restore/purge record handling;
  one-time "done" semantics (audit L1); showing errors (L2); the mock fallback in the detail
  route (L8), except that updating a missing id now fails instead of inserting. Record that
  as a behavior change.

NEW TESTS — HabitHonkerTests/MetadataSafePersistenceTests.swift (real in-memory V2 store; reuse
TxStore / Phase2TestStore helpers)
R1 Stale draft: seed; draft = fetched model; completeHabit; updateHabit(draft, new title)
   → stored title is new AND today's count is 1.
R2 Same through HabitListViewModel: completion finishes, then saveItem(stale draft) → count 1 in
   the store and in vm.items.
R3 Record identity: seed 3 records; 5 metadata updates → record ids, dates and counts unchanged
   AND the total HabitRecordSD row count in the store (orphans included) is unchanged.
R4 No resurrection: delete; updateHabit(old draft) throws notFound; no HabitSD row; archive
   unchanged; notifier.cancel called for that id through the VM path.
R5 Priority vs completion without the list coordinator: two HabitService instances on one
   repository, many concurrent changePriority + completeHabit calls → today's count equals the
   number of completions.
R6 recordLegacyCompletion: same day increments and keeps id/date; next day inserts; a supplied
   calendar in a non-device time zone decides the day boundary.
R7 createHabit with an existing id throws alreadyExists and writes nothing.
R8 Source guard: no production file contains ".upsert(" or "HabitMapper.apply("; only
   makeSD/makeDeletedSD assign `records` in HabitMapper.

VERIFY
- Full suite: executed/passed/failed/skipped. Every baseline test identity passes.
- git diff --check. List every changed production file. Confirm the protected files above have
  no diff.

REPORT — Docs/GamificationPhase4AReport.md
Baseline; R1 failing-first evidence; API before/after table; behavior changes; tests;
protected-file audit; remaining known issues (existing orphans, restore path, L1, L2);
"READY FOR 4F: YES/NO". Stop after 4A. Do not start 4F.
```

---

## 7. Template for 4F … 4G

Reuse the 4A frame: *read list → goal → preflight (fresh baseline; a failing-first test where a bug exists) → implementation from this plan's §4 section → rules (no schema change, frozen Phases 1–3, named guard changes only) → tests from the §4 gate list → verify → report → stop.* Name the decisions (D1–D9) that apply in each prompt, so Codex doesn't choose policy on its own.
