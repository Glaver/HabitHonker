# Gamification Phase 4E Report

Gamification profile enrollment (HabitHonker Exp v1.1.2).

## 1. Status

**PHASE 4E STATUS: PASS**

`.phase4e/verify.sh` ran on 2026-09-29, 15:13:44–15:16:02 PDT (Xcode 26.2, build 17C52; iPhone 17 Pro Max simulator, iOS 26.0, `24629C99-E950-4563-BA70-118CE5D96451`):

| Run | Exit | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|---:|
| Baseline (`6c0db26`, temporary worktree) | **0** | 299 | 299 | 0 | 0 |
| Targeted (6 Phase 4E classes) | **0** | 59 | 59 | 0 | 0 |
| Final (full `HabitHonkerTests`) | **0** | 358 | 357 | 0 | 1 |
| `git diff --check` (tracked; and including new files) | | | | | **clean** |
| Scope and schema audit | | | | | **ok** |

**Targeted per-test matrix:** 59 declared, 59 PASS, 0 missing (from xcresult).

**The one final-run skip is not a Phase 4E test and not a failure.** `NotificationInvestigationTests.testRealSchedulerCurrentMinuteOneTimeTrigger` is a wall-clock probe. By design it throws `XCTSkip("Too close to a minute boundary …")` when 10 s or less remain in the current minute. Its file is unchanged since HEAD.

- **Rerun alone, started at the top of a minute:** 1 passed, 0 skipped, 0 failed (`.phase4e/logs/skip-rerun/`).
- **Earlier full-suite run on identical production and test code:** 358/358 passed, 0 skipped (`skip-rerun/dev-full-run.summary.json`).

**READY FOR PHASE 4D: YES**

## 2. Starting Commit

- **HEAD:** `6c0db26` (`6c0db260c42bd1221189c9f7d25cfdb9942cf1ba`), "feat: add behavior schedule revision foundation" (Phase 4B, committed).
- **Branch:** `experience-layer/initial`.
- **Working tree before 4E:** `git status --short` printed only `?? .phase4b/` and `?? .phase4c/`, the uncommitted tooling of earlier phases. No tracked file was modified.
- **Working tree after 4E:**
  - 2 tracked production files modified (§16);
  - 8 new production files;
  - 7 new test files;
  - this report;
  - `.phase4e/` tooling, which is not to be committed.

## 3. Fresh Baseline

The baseline was run fresh from the committed HEAD in a temporary `git worktree`, before any 4E change existed. It was not taken from the 4B report.

```sh
xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
  -destination 'platform=iOS Simulator,id=24629C99-E950-4563-BA70-118CE5D96451' \
  -derivedDataPath <fresh temp dir> -resultBundlePath <bundle> -only-testing:HabitHonkerTests
```

| Run | Xcode | Destination | Executed | Passed | Failed | Skipped | Exit |
|---|---|---|---:|---:|---:|---:|---:|
| Pre-implementation baseline, 2026-09-29 (`.phase4e/prebaseline/`) | 26.2 (17C52) | iPhone 17 Pro Max, iOS 26.0 | 299 | 299 | 0 | 0 | **0** |
| `verify.sh` baseline, 2026-09-29 15:13 (`.phase4e/logs/`) | 26.2 (17C52) | iPhone 17 Pro Max, iOS 26.0 | 299 | 299 | 0 | 0 | **0** |

Counts come from the xcresult bundles (`xcresulttool get test-results summary`), not from console text.

## 4. Enrollment Architecture

```text
caller (a future product flow; nothing calls it today)
    GamificationEnrollmentRequest(enrolledAt:, schedulingTimeZoneIdentifier:, schedulingCalendarIdentifier: "gregorian")
        ↓
GamificationEnrollmentServicing  →  GamificationEnrollmentService
    1. durability gate  (injected StorageDurabilityState; ephemeralFallback → storageNotDurable, nothing reaches the store)
    2. request.schedulingPolicy()  (the 4B BehaviorScheduleEnrollment.resolve; no fallback)
        ↓
GamificationEnrollmentRepositoryProtocol  →  SwiftDataGamificationEnrollmentRepository  (adapter, holds the shared actor)
        ↓
HabitsRepositorySwiftData.enrollGamification(_:)   (the one container-scoped actor; no await inside)
    ctx = makeContext()
    stageGamificationEnrollment(request, in: ctx)      [HabitsRepositorySwiftData+Enrollment.swift]
        read profile:v1:default rows + all revision rows
        BehaviorScheduleEnrollment.resolve(...)        → enrolled | notEnrolled | unavailable(conflict)
        enrolled    → health check, policy freeze → .alreadyEnrolled   (nothing staged)
        unavailable → throw requiresReconciliation                   (nothing staged)
        notEnrolled → no ledger/occurrence/event rows; the profile row, if any, must be clean
                      stage the profile (create, or initialize the clean row in place)
                      for each current HabitSD: 4B source → 4B normalized snapshot → baseline row
    if .enrolled: commit(ctx)                           → exactly one ctx.save() (the existing 4B seam)
    → GamificationEnrollmentResult
```

- **Service:** `GamificationEnrollmentService` (`Core/Services`). It owns the gate and the fail-fast validation, and nothing else. It has no reward, level, occurrence or reconciliation dependency.
- **Repository protocol:** `GamificationEnrollmentRepositoryProtocol` (`Core/Protocols`), one method: `enroll(_:) async throws -> GamificationEnrollmentResult`.
- **Adapter:** `SwiftDataGamificationEnrollmentRepository` (`Core/Repositories`), a struct holding the existing `HabitsRepositorySwiftData`. This is the same pattern as `SwiftDataBehaviorTransactionRepository`. It creates no container, context or actor.
- **Shared actor:** enrollment runs on the same `HabitsRepositorySwiftData` instance as Habit CRUD, the 4B schedule history and the Phase 3 transaction.
  - **Why an entry point plus a staging file.** The frozen Phase 2 guard forbids gamification model names in `HabitsRepositorySwiftData.swift`. The 4B guard also requires `private func commit(` to stay private. So the entry point (`enrollGamification`: one `makeContext()`, one staging call, one `try commit(ctx)`) is a same-file extension that can use the private `makeContext`/`commit`. The row-level staging is a separate extension file of the same actor, exactly like 4B's `+ScheduleHistory.swift`.
- **DI:** §15.

## 5. Storage Durability Gate

| `StorageDurabilityState` | `supportsDurableGamification` | Enrollment | Test |
|---|---|---|---|
| `durableLocal` | true | allowed | E1, E70 (a real on-disk store opened by `PersistentStoreFactory`, then reopened), E86–E88 |
| `durableCloud` | true | allowed (eligible) | E2, E86–E89. The gate decides on the injected classification. No test opens a CloudKit container or needs an iCloud account; the classification itself is covered by the 4F tests. |
| `ephemeralFallback` | false | **refused**: `GamificationEnrollmentError.storageNotDurable(.ephemeralFallback)` | E3, E86. Zero profile, revision, occurrence, event and ledger rows; every field of every table is unchanged (`TxStore.state`). The recording test double shows the request never reaches the repository, even when it is also invalid (the gate runs first). |

The service reads the durability that `AppDependencies` was built with. It never inspects `ModelConfiguration` or CloudKit settings (guarded).

## 6. Profile Contract

A fresh enrollment writes exactly one `GamificationProfileSD`:

| Field | Value |
|---|---|
| `logicalProfileKey` | `profile:v1:default` (`BehaviorLogicalIdentity.defaultProfileKey`) |
| `totalXP`, `honkerCoins`, `lifetimeCoinsEarned`, `lifetimeCoinsSpent` | `0` |
| `trackingStartedAt` | `request.enrolledAt`, exactly (sub-second precision round-trips; E6) |
| `schedulingTimeZoneIdentifier` | the requested identifier, exactly as given and validated |
| `schedulingCalendarIdentifier` | `"gregorian"` (`BehaviorSchedulingPolicy.gregorianCalendarIdentifier`) |
| `lastProcessedWeekKey`, `aggregateFingerprint` | `nil` |
| `schemaVersion` | `1` (the existing V2 payload version Phase 3 requires) |
| `updatedAt` | `enrolledAt` (Phase 3 maintains this field) |
| `id` | SwiftData's random physical UUID; no logic depends on it |

- **Level** is not persisted; it stays derived by `LevelCalculator`.
- **The profile is a zero projection:** the ledger remains the reward authority, and nothing is awarded.
- **Validation:**
  - the time zone must satisfy `TimeZone(identifier:) != nil`; the calendar must equal `"gregorian"` exactly;
  - both checks are the 4B resolution itself (`BehaviorScheduleEnrollment.resolve` on the proposed facts), so there is no second vocabulary, and a policy accepted at enrollment always resolves again from the stored row;
  - there is no fallback to `TimeZone.current`, UTC, GMT or `Calendar.current`;
  - failures: `invalidSchedulingTimeZone(id)` and `unsupportedSchedulingCalendar(id)` (E4, E5; `"Gregorian"` and `"gregorian "` are rejected).

## 7. Baseline Revision Contract

- **Identity:** `rev:v1:<lowercase target uuid>:baseline` through `BehaviorLogicalIdentity.baselineRevisionID(targetID:)` (4C, unchanged). There is no random component, physical ID, `Hasher` or `hashValue`. The physical row ID is SwiftData's own.
- **`effectiveFrom`:** `policy.trackingStartedAt` for every baseline: one value computed once per operation, not a per-row `Date` (E12, E6, DST test).
- **`effectiveTo`:** `nil` (E13).
- **`schemaVersion`:** `1`, through the unchanged 4B `BehaviorScheduleRevisionMapper.makeOpenRow`.
- **Snapshot semantics:** exactly those of a 4B normal revision:

  ```text
  BehaviorScheduleRevisionMapper.source(from: HabitSD) → BehaviorScheduleSnapshot.normalized(source, policy:) → makeOpenRow(...)
  ```

  | Case | Stored payload |
  |---|---|
  | Repeating | weekday mask (Sun = bit 0 … Sat = bit 6); `dueAt = nil`; hour/minute in the **profile** zone when reminders are on, otherwise `nil` |
  | One-time | mask `0`; no hour/minute; `dueAt = dueDate`, kept even with reminders off |

  Priority, icon and notification state are copied; profile time zone and Gregorian calendar on every row.

  E24–E34 assert every field against literal expected payloads for five representative Habits: repeating with reminder on and off, one-time with reminder on and off (including stale weekdays), and every day at 23:05. The same test also decodes each stored row and compares it to `normalized(source(habit), policy)`.
- **Active Habits only:** one baseline per current `HabitSD` row. Archived Habits (`DeletedHabitSD`) get none (E11). A Habit restored later receives a normal 4B revision, never a baseline (E79–E82).
- **No retroactive history:** creation dates, completions, due dates and archive timestamps are never used as `effectiveFrom` (the same-day test; E12).
- **Zero Habits** is a valid enrollment: one profile and zero baselines (E8, E76).

## 8. Atomicity

- **One actor, one context, at most one save.** `enrollGamification` contains exactly one `makeContext()`, one `stageGamificationEnrollment(` and one `try commit(ctx)`. It has no other `.save()`, no `await`, no `Task` and no `Date()` (guarded). The staging file never saves, rolls back, deletes or creates a context (guarded).
- **Nothing is saved early.** E69's before-commit hook sees the profile and all 12 baselines in the staging context, while a fresh context on the same store still sees 0 profiles and 0 revisions. The hook runs exactly once per enrollment, and never for `.alreadyEnrolled` or a refusal.

| Scenario | Test | Failure | After |
|---|---|---|---|
| Profile + N baselines staged | E65 | injected before the single save (existing 4B DEBUG seam) | every field of every table equals the pre-enrollment state; the retry then enrolls |
| Real save failure | E66 | on-disk store reopened with `allowsSave: false` | the persistence error is rethrown (not a `GamificationEnrollmentError`); store unchanged |
| Snapshot derivation fails mid-staging | E67 | a second physical `HabitSD` row for one target, after the profile and earlier baselines were staged | `requiresReconciliation(.duplicateActiveHabit(target))`; the save is never reached; no profile, no baseline |
| Clean unenrolled profile initialized in place | E68 (seam) + E68 (real save) | after the in-place staging | the row keeps its physical id and is still unenrolled; 0 baselines |

No partial "best effort" enrollment exists: one un-normalizable Habit fails the whole operation.

## 9. Idempotency

- **First enrollment:** `.enrolled(summary)`.
- **Repeat, same time zone and calendar:** `.alreadyEnrolled(existing summary)` with zero writes (E48–E53). This holds whether the request carries the same instant, a later one or an earlier one: the existing `trackingStartedAt` wins, and enrollment is not "refresh".
  - Unchanged: profile physical ID, baseline physical IDs and row counts, and every field of every table.
  - Progress recorded after enrollment is never reset (XP 180, coins 12, lifetime totals, week key, ledger row).
  - Habits created after enrollment keep their normal revision and receive no baseline.
- **Different policy on a later call:** `conflictingExistingEnrollment(existing:)` (E54). Asia/Tokyo, Europe/London and America/New_York against a Los Angeles enrollment all change nothing. A non-Gregorian calendar is `unsupportedSchedulingCalendar` before the store is read.
- **Concurrency (E85):** 12 simultaneous calls on one actor give exactly one `.enrolled` and 11 `.alreadyEnrolled` with the winner's summary. The store has one profile and one baseline per Habit. This is **local actor serialization only**; there is no global Cloud exactly-once claim.

## 10. Existing Unenrolled Profile

One `profile:v1:default` row with `trackingStartedAt == nil` is **initialized in place** (E55, E56; physical ID kept) only when all of the following hold:

- it is the only physical row of that key;
- no revision, ledger, occurrence or behavior-event row exists;
- balances and lifetime totals are `0`, with no processed week and no aggregate fingerprint;
- it holds no partial policy (time zone and calendar are `nil`);
- its payload version is `1`.

Otherwise enrollment refuses and nothing is written:

| Stored state | Refusal |
|---|---|
| nonzero XP, coins, lifetime earned or spent (including negative), week key or fingerprint | `nonEmptyUnenrolledProfile` (never zeroed) |
| time zone and/or calendar without `trackingStartedAt` | `incompleteExistingEnrollment` |
| unknown `schemaVersion` | `unsupportedProfileSchemaVersion(n)` |

## 11. Conflict Handling

Every refusal is `GamificationEnrollmentError.requiresReconciliation(GamificationEnrollmentConflict)`. It is asserted with `TxStore.state` byte-equality: nothing is deleted, merged, adopted or repaired. The 4B conflict vocabulary is reused for profile/history resolution (`.scheduleEnrollment(BehaviorScheduleHistoryConflict)`).

| Stored state | Conflict | Test |
|---|---|---|
| 2 or 3 physical `profile:v1:default` rows (unenrolled pair, identical healthy pair, 10:00/10:04 offline pair, mixed) | `.scheduleEnrollment(.multipleProfiles(count:))`: no `fetch.first`, no earliest-wins, no baseline from an arbitrary row | E61, E62 (+ regex guard: no `.first`/`.last` in the staging file) |
| revision rows, no enrolled profile (baseline key or normal key) | `.scheduleEnrollment(.orphanRevisionHistory)`: no profile created to adopt them | E60, E63 |
| ledger rows without enrollment | `.financialHistoryWithoutEnrollment(ledgerEntryCount:)` | E59 |
| occurrence or behavior-event rows without enrollment | `.behaviorHistoryWithoutEnrollment(occurrenceCount:eventCount:)` | occurrence/event test |
| enrolled profile, invalid or missing zone / non-Gregorian calendar | `.scheduleEnrollment(.invalidSchedulingTimeZone / .unsupportedSchedulingCalendar)` | E64 |
| enrolled profile, unknown payload version | `.unsupportedProfileSchemaVersion(n)` | E64 |
| enrolled profile, revision rows older than `trackingStartedAt` | `.scheduleHistoryPredatesEnrollment(revisionCount:)` | E64 |
| enrolled profile, baseline rows not starting at `trackingStartedAt` | `.baselineBoundaryMismatch(revisionCount:)` | E64 |
| two physical current rows for one Habit ID | `.duplicateActiveHabit(target)` | E67 |
| V1-only schema (no gamification models) | `gamificationStorageUnavailable` | V1-only store test |

There is no `unknown` case. A failing save is rethrown as the underlying persistence error.

**Already-enrolled health check (§31):** exactly one profile row, a valid zone, the Gregorian calendar, payload version 1, no revision older than `trackingStartedAt`, and every baseline exactly at `trackingStartedAt`. Per-target coverage and open-revision health are not judged here: 4B defers per target, and 4G derives cutover safety.

**Frozen Hybrid B+C policy (ADR 4.1).** Two offline devices can each enroll and write the same deterministic baseline keys. After sync the physical duplicates are expected. 4E recognizes the resulting multiplicity and refuses to guess; 4G applies earliest-valid-enrollment-wins and groups baselines by logical ID. There is no `@Attribute(.unique)` (guarded).

## 12. Phase 4B Activation

The real production mutation paths are used throughout: `HabitService` → `SwiftDataHabitRepository` → the shared actor, with the production planner and the V1 revision ID provider.

| Step | Result | Test |
|---|---|---|
| Before enrollment: priority change | `ScheduleHistoryOutcome.notEnrolled`; 0 revisions; no revision ID minted | E71 |
| Enroll | baseline `[T, nil)` with the exact 4B payload | E72 |
| Priority change after enrollment | baseline closed at the change instant; normal revision `rev:v1:<t>:change:<uuid>` opened there; the next change returns `revisionApplied` | E73 |
| Title/description/tags/color-only edit | no new revision; baseline stays open | E74 |
| Weekday edit | normal revision opens | E75 |
| Create after enrollment (from a zero-Habit enrollment) | one normal revision, no baseline, `effectiveFrom` = creation instant | E76–E78 |
| Delete | baseline closes, no replacement | E79, E80 |
| Restore | new normal revision; the baseline stays closed | E81, E82 |
| Production graph with real clock and UUIDs | `AppDependencies` enrollment, then `habitService.createHabit` writes a `rev:v1:<id>:change:<uuid>` revision | production-graph test |

No 4B code was modified to achieve this: the stored enrollment is simply what `BehaviorScheduleEnrollment.resolve` now finds.

## 13. Existing Data Integrity

E35–E41 use the §53 world:

- Habit A with 200 old completion rows, B with none, and C (one-time) completed earlier on the enrollment day;
- two archived Habits with their own records;
- one statistics preset.

After enrollment, `Phase2TestStore.legacySnapshot` (every field of every `HabitSD`, `DeletedHabitSD`, `HabitRecordSD` and `StatisticsPresetSD` row, including record-to-parent links) is identical. Record row count, IDs, dates and counts are unchanged. The only new rows are 1 profile and 3 baselines. The staging file cannot name records, archives or presets and assigns no Habit field (guarded).

## 14. No Retroactive Gamification

| After enrollment | Value |
|---|---|
| `TaskOccurrenceSD` rows | 0 |
| `BehaviorEventSD` rows | 0 |
| `GamificationLedgerEntrySD` rows | 0 |
| XP / coins / lifetime totals | 0 / 0 / 0 / 0 |
| Reward calculator or `GamificationService` invoked | no. The enrollment graph has no such dependency, and the guards forbid the names in enrollment code. |
| Legacy completion before enrollment (10:00, enrolled 15:00) | stays a `HabitRecordSD` only; the baseline starts at 15:00 |
| Completion after enrollment | still `HabitService.completeHabit` → `recordLegacyCompletion`. Record +1, no occurrence/event/ledger, profile and revisions unchanged. |

## 15. Protocols / DI

| Protocol | Implementation | Consumer | Dependencies |
|---|---|---|---|
| `GamificationEnrollmentServicing` (`Core/Protocols`) | `GamificationEnrollmentService` | future product flow (none today); exposed as `AppDependencies.gamificationEnrollmentService` | `GamificationEnrollmentRepositoryProtocol`, `StorageDurabilityState` |
| `GamificationEnrollmentRepositoryProtocol` (`Core/Protocols`) | `SwiftDataGamificationEnrollmentRepository` | `GamificationEnrollmentService` | the shared `HabitsRepositorySwiftData` |
| reused: `BehaviorScheduleEnrollment.resolve`, `BehaviorScheduleSnapshot.normalized`, `BehaviorScheduleRevisionMapper`, `BehaviorLogicalIdentity` | 4B / 4C | the actor's enrollment staging | none new |

```text
AppDependencies.make(container:, storageDurability:)
    swiftDataRepository = HabitsRepositorySwiftData(container:, planner:, revisionIDs:)   ← still the only one
    ├─ SwiftDataHabitRepository(repository: swiftDataRepository)             → HabitService
    ├─ SwiftDataBehaviorTransactionRepository(repository: swiftDataRepository) → BehaviorTransactionService
    └─ SwiftDataGamificationEnrollmentRepository(repository: swiftDataRepository)
           → GamificationEnrollmentService(repository:, storageDurability: storageDurability)
```

- **No automatic enrollment, no singletons.** There is no singleton, `static var` or service locator. `make` never calls `enroll` (guarded).
- **Construction and use of the graph create no profile and no baseline, in every durability state (E86, E87).**
- **The only call edges:**
  - `GamificationEnrollmentService` is the only production `.enroll(` caller;
  - the adapter is the only `enrollGamification(` caller;
  - `gamificationEnrollmentService` appears only in `AppDependencies`;
  - no view, view model, app entry point or Habit service mentions enrollment.
- **Container scope (E89):** two containers get independent enrollment services. Enrolling store A leaves store B byte-identical; B enrolls independently in its own zone. Rebuilding the graph for a new store never reaches the old one.

## 16. Files

**New production (8):**

| Path | Responsibility |
|---|---|
| `Core/Domain/GamificationEnrollmentRequest.swift` | explicit request; validation through 4B `resolve` → `BehaviorSchedulingPolicy` |
| `Core/Domain/GamificationEnrollmentResult.swift` | `GamificationEnrollmentSummary`, `.enrolled` / `.alreadyEnrolled` |
| `Core/Domain/GamificationEnrollmentError.swift` | `GamificationEnrollmentError`, `GamificationEnrollmentConflict` |
| `Core/Protocols/GamificationEnrollmentServicing.swift` | service protocol |
| `Core/Protocols/GamificationEnrollmentRepositoryProtocol.swift` | repository protocol |
| `Core/Services/GamificationEnrollmentService.swift` | durability gate + validation + delegation |
| `Core/Repositories/SwiftDataGamificationEnrollmentRepository.swift` | adapter over the shared actor |
| `Repository/SwiftDataRepository/HabitsRepositorySwiftData+Enrollment.swift` | actor extension: `stageGamificationEnrollment` (reads, refusals, staging; never saves) |

**Modified production (2):**

| Path | Change |
|---|---|
| `Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift` | appended extension `enrollGamification(_:)`: one context, the staging call, `commit` only for `.enrolled`. No existing line changed. |
| `App/AppDependencies.swift` | `gamificationEnrollmentService` property and construction on the shared actor; `storageDurability` doc comment updated |

**Tests (7 new files, 59 tests; no existing test changed):** `GamificationEnrollmentTestSupport` (fixtures), plus `GamificationEnrollmentServiceTests` (10), `…PersistenceTests` (10), `…ConflictTests` (15), `…AtomicityTests` (7), `…IntegrationTests` (11) and `…ArchitectureTests` (6).

**Docs:** this report. **Tooling (not committed):** `.phase4e/verify.sh`, `.phase4e/logs/`, `.phase4e/prebaseline/`.

**Not modified** (enforced by `verify.sh`):

- every `@Model` file, `HabitSchemaMigration` and `HabitMapper`;
- all 4B production types and the 4B mapper/staging;
- 4C identity;
- 4F `PersistentStoreFactory`, `StorageDurabilityState` and `HabitHonkerApp`;
- Phase 1 `Core/Gamification`, and the Phase 3 service/repository/`BehaviorTransactionSD`;
- `HabitService`, `HabitServiceProtocol`, `HabitRepositoryProtocol` and `SwiftDataHabitRepository`;
- all of `Screens/` and `Servise/`, and the Xcode project (synchronized folders pick up new files).

## 17. Schema Audit

| Question | Answer |
|---|---|
| Schema V2 changed? | **NO** (entity set and `GamificationProfileSD` property set asserted; no model file touched) |
| Migration changed? | **NO** (2 schemas, 1 stage) |
| `@Model` added? | **NO** (only the five frozen model files contain `@Model`; no `SchemaV3`) |
| `@Attribute(.unique)` added? | **NO** |

## 18. Live Behavior

| Question | Answer |
|---|---|
| Automatic enrollment enabled? | **NO** (no caller outside the service; DI builds but never calls it) |
| Live gamification cutover? | **NO** (`completeHabit` still records legacy completions only) |
| XP live? | **NO** |
| Coins live? | **NO** |

## 19. Tests

| Run | Exit | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|---:|
| Baseline (committed `6c0db26`) | 0 | 299 | 299 | 0 | 0 |
| Targeted (6 Phase 4E classes) | 0 | 59 | 59 | 0 | 0 |
| Final (full suite) | 0 | 358 | 357 | 0 | 1 (pre-existing wall-clock self-skip; passes on rerun, §1) |
| `git diff --check` (tracked, and with new files) | | | | | clean |

Source: `.phase4e/logs/summary.txt` (xcresult counts and the per-test matrix for all 59 declared 4E tests).

| Contract | Tests |
|---|---|
| E1–E7 | `GamificationEnrollmentServiceTests.testE1…`–`testE7…`, `testRequestDefaultsToTheV1GregorianRepresentation`, `testValidatedRequestPolicyIsTheOneResolvedFromTheStoredProfile`, `testV1OnlyStoreCannotHoldAnEnrollment` |
| E8–E34 | `GamificationEnrollmentPersistenceTests.testE8…`, `testE9…`, `testE10…`, `testE11…`, `testE12To14…`, `testE15To23…`, `testE24To34…` |
| E35–E47 | `GamificationEnrollmentIntegrationTests.testE35To41…`, `testE42To47…`, `testSameDayCompletionBeforeEnrollmentStaysLegacyHistoryOnly` |
| E48–E64 | `GamificationEnrollmentConflictTests` (15 tests) |
| E65–E69, E85 | `GamificationEnrollmentAtomicityTests` (7 tests) |
| E70, E83–E84, DST | `GamificationEnrollmentPersistenceTests.testE70…`, `testE83E84…`, `testEnrollmentNearDSTKeepsTheExactInstantAndReadsClocksInTheProfileZone` |
| E71–E82, §75 | `GamificationEnrollmentIntegrationTests.testE71To73…`, `testE74E75…`, `testE76To78…`, `testE79To82…`, `testCompletionAfterEnrollmentStaysOnTheLegacyPath` |
| E86–E89 | `testE86To88…`, `testProductionGraphEnrollmentActivatesRevisionHistoryForItsHabitService`, `testE89…` |
| §82 guards | `GamificationEnrollmentArchitectureTests` (6 tests) |

**Notes on the fixtures:**

- **Device zone (E83/E84):** switched with the same `TZ` + `resetSystemTimeZone()` + `NSTimeZone.default` technique as the 4B B82 fix. The test proves that the device clock really differed (+9 h in Tokyo, 0 in London) and asserts the stored behavior, not `TimeZone.current`.
- **DST:**
  - spring-forward enrollment at 01:59:30 PST;
  - reminders at 03:30 PDT and 07:30 PST read as 3:30 and 7:30;
  - fall-back enrollment during the second 01:30;
  - `effectiveFrom` is the absolute instant in every case.

## 20. Known Limitations

- **Per-target coverage is not judged.** `.alreadyEnrolled` does not check whether each current Habit has an open revision. A missing or deferred per-target history is a 4B per-target state that 4G derives as not cutover-safe, not an enrollment failure. For example, baselines may not have synced yet on a second device.
- **The time zone is stored as given.** Any identifier Foundation accepts is stored exactly as supplied, as 4B already does; it is not canonicalized. For example, an alias accepted by `TimeZone(identifier:)` is stored as the alias.
- **Unknown stored Habit values follow the 4B mapper.** An unknown stored type or priority is read the way the app reads it (repeating / Important-Urgent), exactly as 4B normal revisions do. Only structural anomalies (duplicate current rows) make snapshot derivation fail.
- **Cloud behavior is verified only through the gate.** No real CloudKit sync was exercised (by design: no test touches an iCloud account).

Expected future work, not failures: OccurrencePlanner (4D), multi-device reconciliation (4G), live routing (Phase 5), and the product decision of when to call `enroll`.

## 21. Final Gate

Every item of the §111 definition of done holds:

- fresh baseline green (299/299);
- 59/59 targeted tests pass;
- the final suite has 0 failures (357 passed, plus 1 unrelated wall-clock self-skip that passes on rerun);
- `git diff --check` is clean;
- the scope audit is ok: Schema V2, the migration plan and every frozen layer are unchanged;
- no automatic enrollment and no live cutover.

**READY FOR PHASE 4D: YES**
