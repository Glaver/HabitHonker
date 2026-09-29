# Gamification Phase 4B Report

Behavior schedule revision foundation (HabitHonker Exp v1.1.2).

## 1. Status

**PHASE 4B STATUS: PENDING VERIFICATION** (one test-only fix awaiting its rerun)

**First Mac run.** `.phase4b/verify.sh` ran on 2026-09-29, 13:53:38–13:56:23 PDT (Xcode 26.2, build 17C52; iPhone 17 Pro Max simulator, iOS 26.0, `24629C99-E950-4563-BA70-118CE5D96451`):

| Run | Exit | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|---:|
| Baseline (`907b377`, worktree) | **0** | 175 | 175 | 0 | 0 |
| Targeted (7 Phase 4B classes) | 65 | 124 | 123 | 1 | 0 |
| Final (full `HabitHonkerTests`) | 65 | 299 | 298 | 1 | 0 |
| `git diff --check` (tracked; and including new files) | | | | | **clean** |
| Scope audit (expected files only; frozen paths, models, writers, live completion) | | | | | **ok** |

**The one failure was a test-environment precondition, not a production invariance failure.**

The failing test was `BehaviorScheduleRevisionPersistenceTests.testB82DeviceTimeZoneDoesNotChangeTheRevisionSnapshot`. Its xcresult holds exactly two failure messages, both at line 281:

- `XCTAssertEqual failed: ("America/Los_Angeles") is not equal to ("Asia/Tokyo")`
- `XCTAssertEqual failed: ("America/Los_Angeles") is not equal to ("Europe/London")`

Line 281 was `XCTAssertEqual(TimeZone.current.identifier, deviceZone)`. Every behavioral assertion of B82 passed:

- the Tokyo and London payloads were identical;
- the logical revision ID and `effectiveFrom` were identical;
- the hour was 18 and the minute 45;
- the stored scheduling time zone was `America/Los_Angeles`.

The persisted revision did not differ, so no production code was changed.

**Cause.** In current Foundation (swift-foundation), `NSTimeZone.default` is a separate value. Setting it does not change `TimeZone.current`, which is the system zone: it is read from `TZFILE`/`TZ` and cached until `NSTimeZone.resetSystemTimeZone()`. The test therefore never actually ran with a different `TimeZone.current`.

**Test-only fix.** A helper, `withDeviceTimeZone(_:_:)`, switches both zones for the duration of each run and restores both afterwards: it sets `TZ` (clearing `TZFILE`), calls `resetSystemTimeZone()`, and sets `NSTimeZone.default`. The test now:

- keeps the `TimeZone.current == deviceZone` precondition and adds `NSTimeZone.default == deviceZone`;
- proves the two runs really had different device clocks: the offset at the reminder instant is +9 h in Tokyo and 0 in London;
- checks that the original zone is restored for later tests.

Every behavioral assertion is unchanged.

**Rerun:**

```sh
bash ~/Development/habitHonker/.phase4b/rerun.sh
```

It runs B82 alone, the 124 targeted tests, the full suite and both `git diff --check` passes, and writes `.phase4b/logs-rerun/summary.txt`. The baseline is not repeated because HEAD is unchanged.

**READY FOR PHASE 4E: NO** (pending the rerun).

## 2. Starting Commit

- `HEAD` = `907b377` (`907b37757257502e3d1e58763369b800342aa6fb`), "feat: add deterministic behavior identities", branch `experience-layer/initial`. This is Phase 4C, committed.
- **Working tree before this run:** `git status --short` printed only `?? .phase4c/`, the uncommitted 4C tooling. Nothing tracked was modified.
- **Working tree after this run:**
  - 7 tracked files modified: 5 production files and 2 test call-site migrations (§12).
  - 12 new production files (§13).
  - 8 new test files.
  - This report.
  - `.phase4b/` tooling, which is not to be committed. `.phase4b/src-snapshot.tar` is a read-only copy of the tree used for reading in this run; it can be deleted with the folder.

## 3. Fresh Baseline

**Not yet executed** (no Xcode here). `verify.sh` runs the complete `HabitHonkerTests` suite on a temporary `git worktree` of `HEAD`. None of the 4B changes are in that worktree, so this is exactly the committed pre-4B code. If the baseline fails, the script stops and skips the 4B runs, as §49 requires.

```sh
xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
  -destination '<discovered>' -derivedDataPath <fresh temp dir> \
  -resultBundlePath .phase4b/logs/baseline.xcresult -only-testing:HabitHonkerTests
```

- **Destination:** the scheme's eligible simulators. The script prefers the one used for 4F and 4C (`24629C99-E950-4563-BA70-118CE5D96451`, iPhone 17 Pro Max, iOS 26.0). Otherwise it takes the newest-iOS iPhone. `DEST=` overrides it.
- **Counts** come from the xcresult bundle (`xcresulttool … summary`, read with `plutil`), not from console text.

| Run | Xcode | Destination | Executed | Passed | Failed | Skipped | Exit |
|---|---|---|---:|---:|---:|---:|---:|
| Baseline (`907b377`) | 26.2 (17C52) | iPhone 17 Pro Max, iOS 26.0 (`24629C99-…`) | 175 | 175 | 0 | 0 | **0** |

This is a fresh run of the committed HEAD in a temporary worktree. It was not taken from the earlier 4C report.

## 4. Architecture Implemented

```text
HabitService (application boundary)
    effectiveAt = now()                      ← injected clock, read once per mutation
        ↓
HabitRepositoryProtocol / SwiftDataHabitRepository   (returns HabitModel, as before)
        ↓
HabitsRepositorySwiftData  (the one container-scoped actor)
    one synchronous actor operation:
        makeContext()
        read current HabitSD            → BehaviorScheduleSource "before"
        stage Habit mutation
        stageScheduleHistory(change, effectiveAt, ctx)       [+ScheduleHistory extension]
            read GamificationProfileSD rows (read-only) → BehaviorScheduleEnrollment
            read target's BehaviorScheduleRevisionSD rows → [BehaviorScheduleRevisionFacts]
            BehaviorScheduleRevisionPlanning.plan(...)     ← pure
            stage close/insert; mint ID only for an insert  ← BehaviorScheduleRevisionIDProviding
        commit(ctx)  → exactly one ctx.save()
    → HabitMutationResult { habit, scheduleHistory: ScheduleHistoryOutcome }
```

**Pure values** (`import Foundation` only):

- **`BehaviorScheduleSource`:** the revision-relevant facts of the current Habit row. It has no title, description, tags, color or completion records.
- **`BehaviorScheduleSnapshot`:** the normalized historical planning payload of one revision. It is `Equatable` and `Sendable`, and equality covers the planning payload only (§6).
- **`BehaviorScheduleSourceChange` / `BehaviorScheduleMutation`:** created, updated(before, after), deleted and restored, first in source terms and then in snapshot terms.
- **`BehaviorSchedulingPolicy`:** the enrolled profile's fixed `trackingStartedAt`, time zone and Gregorian calendar. Only `BehaviorScheduleEnrollment.resolve` can create one (`fileprivate init`).
- **`BehaviorScheduleEnrollment`:** `notEnrolled`, `enrolled(policy)` or `unavailable(conflict)`, resolved from stored profile facts only.
- **`BehaviorScheduleRevisionFacts`:** one stored revision row as the planner sees it. Its snapshot is nil when the payload is not a complete V1 payload.
- **`BehaviorScheduleRevisionPlan`:** `noRevisionRequired`, `replaceOpenRevision`, `openRevision`, `closeOpenRevision` or `deferHistory(conflict)`.
- **`ScheduleHistoryOutcome`:** `notEnrolled`, `revisionNotRequired`, `revisionApplied(ScheduleRevisionChange)` or `revisionDeferred(BehaviorScheduleHistoryConflict)`.

**Revision planner** (`BehaviorScheduleRevisionPlanner`). Its rules:

1. **Update or delete** needs exactly one open revision (`effectiveTo == nil`), and that revision's payload must equal the Habit's definition just before the mutation. Otherwise it defers.
2. **Update with an unchanged payload** returns `noRevisionRequired`.
3. **Create and restore** need zero open revisions.
4. **Any write** at `effectiveAt` must not predate `trackingStartedAt`, and must not be earlier than any boundary (`effectiveFrom` or `effectiveTo`) already recorded for the target. An equal boundary is allowed.
5. **Several physical open revisions** are never resolved by picking one.

It reads no clock, mints no identifier, touches no persistence and computes no reward.

**Revision ID provider** (`BehaviorScheduleRevisionIDProviderV1`). It uses an injected `@Sendable () -> UUID`, which defaults to a fresh `UUID()`. It is called only from the one insert helper (§5).

**History outcome.** The actor returns it in `HabitMutationResult` (create, metadata and priority) or as `ScheduleHistoryOutcome?` (delete and restore; nil means no row existed and nothing was written). It is also logged. The repository protocol and `HabitServiceProtocol` keep their `HabitModel` return values, so the UI and view models are untouched (§40).

**Atomic mutation path:** see §8. The before-save test seam, `setBeforeCommitForTesting`, is `#if DEBUG` only.

## 5. Revision Identity

| Identity | Format | Produced by |
|---|---|---|
| Enrollment baseline (existing 4C) | `rev:v1:<target uuid>:baseline` | `BehaviorLogicalIdentity.baselineRevisionID`. 4B never calls it in production and never creates a baseline. |
| Normal revision (frozen by 4B) | `rev:v1:<target uuid>:change:<revision uuid>` | `BehaviorScheduleRevisionIDProviderV1` |

- **UUID normalization:** both UUIDs go through the 4C `BehaviorLogicalIdentity.canonicalUUIDText` (standard 8-4-4-4-12 form, lowercase).
- **Frozen example:** target `123e4567-e89b-12d3-a456-426614174000` and revision `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` give `rev:v1:123e4567-e89b-12d3-a456-426614174000:change:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee`, asserted exactly in B26.
- **What the ID is not:** it is never the SwiftData row `id` (the row gets its own physical UUID from the model initializer, and the mapper never passes one). It is never derived from `Hasher` or `hashValue`, and never generated in a model property default.
- **When an ID is minted:** once, in the one insert helper, and only for a planned insert. No-op, deferred and not-enrolled mutations mint nothing (B30, B31).

## 6. Schedule Snapshot Semantics

`BehaviorScheduleSnapshot.normalized(source, policy:)`:

| Field | Repeating | One-time |
|---|---|---|
| `taskTypeRawValue` | `"repeating"` (`GamificationTaskType.rawValue`, the Phase 1/2 vocabulary) | `"oneTime"` |
| `selectedWeekdaysMask` | OR of `1 << (raw - 1)`: Sun = bit 0 … Sat = bit 6 | `0`, even if the row still lists weekdays |
| `scheduledHour` / `scheduledMinute` | hour and minute of `dueDate` in the **policy** time zone, Gregorian, when notifications are on; otherwise `nil`/`nil` | `nil`/`nil` |
| `dueAt` | `nil` | the Habit's `dueDate`, kept even with notifications off; timing reward is decided in 4D, not here |
| `schedulingTimeZoneIdentifier` | the profile's identifier, exactly as stored | same |
| `schedulingCalendarIdentifier` | `"gregorian"`, the Phase 2 persisted text (`BehaviorSchedulingPolicy.gregorianCalendarIdentifier`) | same |
| `priorityRawValue` | `BehaviorPriority` raw 0…3 via the existing `HabitShadowMapper.behaviorPriority` | same |
| `iconName` | the Habit's `icon`, exactly | same |
| `notificationEnabled` | exactly | same |

- **Reading the current row.** `BehaviorScheduleRevisionMapper.source(from: HabitSD)` reads the row the way the app reads it today (`HabitMapper.toDomain`):
  - an unknown type reads as repeating;
  - an unknown priority reads as Important / Urgent;
  - weekday values outside 1…7 are ignored.
- **Never in the snapshot:** title, description, tags, icon color, records, XP, coins, streak, level, duck state or prediction state.
- **Weekday mask:** a bitwise OR, so it is independent of order, duplicates and locale (B17–B25).
- **Calendar:** built only in `BehaviorSchedulingPolicy.calendar`, as `Calendar(identifier: .gregorian)` with the policy `TimeZone` and the `en_US_POSIX` locale. There is no device calendar, time zone or locale anywhere in the planning layer (guarded; B82).
- **Comparison:** planning payload only. The physical id, logical ID, `effectiveFrom`, `effectiveTo` and row `schemaVersion` are not part of the snapshot.
- **Decoding a stored row.** It decodes only when:
  - `schemaVersion == 1`;
  - the task type and priority are known values;
  - notification state, time zone and calendar are present.

  Otherwise its snapshot is nil. A nil snapshot, or a stored payload that breaks normalization (for example a clock stored while notifications were off, or a time zone other than the profile's), compares unequal. The result is `currentRevisionDoesNotMatchCurrentHabit`, and the row is never repaired.

## 7. Enrollment Boundary

- **4B does not enroll.** It never creates, normalizes, merges or deletes a `GamificationProfileSD`, and never creates a baseline revision; both belong to 4E. Production has no profile today, so every live mutation reports `notEnrolled` and writes no revision.
- **Resolution** (`BehaviorScheduleEnrollment.resolve`) covers the physical rows with `logicalProfileKey == "profile:v1:default"`:

  | Rows | State | Result |
  |---|---|---|
  | 0 | no revision rows in the store | `notEnrolled` |
  | 0 | revision rows exist | `unavailable(.orphanRevisionHistory)` |
  | more than 1 | any (enrolled or not) | `unavailable(.multipleProfiles(count:))`: no `fetch.first`, no earliest-wins (§19) |
  | 1 | `trackingStartedAt == nil`, no revision rows | `notEnrolled` |
  | 1 | `trackingStartedAt == nil`, revision rows exist | `orphanRevisionHistory` |
  | 1 | invalid or missing time zone | `invalidSchedulingTimeZone(id)` (no device fallback) |
  | 1 | calendar not `"gregorian"`, or missing | `unsupportedSchedulingCalendar(id)` (no `Calendar.current` fallback) |
  | 1 | otherwise | `enrolled(policy)` |

- **A store without the V2 gamification models** (for example the V1-only container used by `NotificationInvestigationTests`) cannot hold an enrollment, so it is `notEnrolled`. The schema is checked with `ctx.container.schema.entity(for:)` before any gamification fetch.
- **Post-enrollment:** the writer is active for create, metadata, priority, delete and restore. Legacy completion has no schedule-history effect.
- **Mutation before `trackingStartedAt`:** `mutationPredatesEnrollment(trackingStartedAt:effectiveAt:)`. Enrollment is never moved and history never fabricated. At exactly `trackingStartedAt` the change is representable: the baseline becomes `[T, T)` and the new revision starts at T (B63).
- **A no-op edit** writes nothing, so it is not checked against enrollment time or chronology. Trustworthy history stays trustworthy.

## 8. Healthy Mutation Flow

```text
HabitsRepositorySwiftData.updateMetadata(id:metadata:effectiveAt:)     (no await anywhere inside)
  ctx = makeContext()
  sd  = activeHabit(id)                       ─ throws notFound, never inserts
  before = source(sd)
  HabitMapper.applyMetadata(metadata, to: sd) ─ never touches records (4A)
  stageScheduleHistory(.updated(before, source(sd)), effectiveAt, ctx)
      open.effectiveTo = effectiveAt          ─ close:  [from, T)
      insert new row, effectiveFrom = T, effectiveTo = nil, logical ID minted now
  commit(ctx)                                 ─ the one ctx.save()
```

- **Intervals:** half-open `[effectiveFrom, effectiveTo)`. T belongs to the new revision. There is no `T - 1s`, no epsilon, no gap and no overlap.
- **Same shape everywhere:** `updatePriority` (priority only), `createHabit` (insert plus the first normal revision), `delete` (archive plus delete plus close) and `restoreDeletedHabit` (restore plus new revision).
- **Source guards:** each of the five mutation windows contains exactly one `makeContext()`, one `stageScheduleHistory(`, one `try commit(ctx)`, no other `.save()`, no `await` and no `Date()`.

## 9. Deferred History Flow

```text
same actor operation, same context
  stage the Habit mutation (the user's edit)
  stageScheduleHistory → plan .deferHistory(conflict)   → no revision row read-for-write, closed or inserted
  commit(ctx)                                            → the Habit mutation is saved
  → ScheduleHistoryOutcome.revisionDeferred(conflict)
```

- **What is saved:** the user's metadata, priority, create, delete or restore is saved in every case. Gamification history never holds the current task hostage (ADR 4.9).
- **What stays untouched:** revision rows are byte-for-byte unchanged (asserted with `TxStore.state` in every deferral test). No revision ID is minted, nothing is fabricated or picked, and nothing is persisted as a flag. Schema V2 is unchanged and there is no `isCutoverSafe`.
- **Afterwards:** the target is derivably `notCutoverSafe`. 4G can detect it from stored state: profile multiplicity, open-revision multiplicity, missing history, or an open revision that no longer matches the Habit.
- **A later edit does not paper over the gap.** It still finds the mismatch and defers (`testDeferredEditLeavesHistoryBehindAndLaterEditsStayDeferredUntilReconciled`).
- **Conflict cases** (`BehaviorScheduleHistoryConflict`), each tied to a concrete stored state:
  - `multipleProfiles(count:)`
  - `invalidSchedulingTimeZone(_)`
  - `unsupportedSchedulingCalendar(_)`
  - `orphanRevisionHistory`
  - `mutationPredatesEnrollment(trackingStartedAt:effectiveAt:)`
  - `missingOpenRevision`
  - `multipleOpenRevisions(count:)`
  - `openRevisionAlreadyExists`
  - `currentRevisionDoesNotMatchCurrentHabit`
  - `revisionChronologyConflict(latestBoundary:effectiveAt:)`

  There is no `unknownError`. Persistence failures are thrown errors.

## 10. Create/Delete/Restore Semantics

| Operation | Not enrolled | Enrolled, healthy | Enrolled, unsafe |
|---|---|---|---|
| **Create** | Habit created; `notEnrolled` | Habit plus first **normal** revision `rev:v1:<t>:change:<u>`, `[effectiveAt, nil)`, never the baseline key; one save (B47–B49) | Habit still created; `openRevisionAlreadyExists` / `multipleOpenRevisions` / profile or chronology reasons. `alreadyExists` still throws and writes nothing. |
| **Metadata / priority** | Saved; `notEnrolled` | Relevant change: close plus open. Non-relevant or identical: `revisionNotRequired`, rows untouched. | Saved; deferred, rows untouched (B50–B62) |
| **Delete** (archive plus delete, 4A semantics unchanged) | Archived; `notEnrolled` | Open revision closed at `effectiveAt`; no revision opened (B64) | Deleted anyway; rows untouched (B65; also when the open revision no longer matches) |
| **Restore** | Restored; `notEnrolled` | New normal revision `[effectiveAt, nil)` from the restored metadata; the old closed revision is never reopened (B67, B68). A Habit archived before enrollment gets its first revision on restore. | Restored anyway; `multipleOpenRevisions` or `openRevisionAlreadyExists` (a delete that could not close history); nothing fabricated (B69) |

- **Delete and restore still return nothing through the protocol.** A missing row still writes nothing (the actor returns nil).
- **4A no-resurrection is unchanged:** metadata and priority updates on a deleted Habit still throw `notFound` and never insert.
- **Record handling is unchanged:** delete and restore copy completion records exactly as before (B78).

## 11. Protocols / DI

| Protocol | Responsibility | Implementation | Consumer | Dependencies |
|---|---|---|---|---|
| `BehaviorScheduleRevisionPlanning` (`Core/Protocols`) | Decide the revision-row effect of a mutation from snapshots plus stored revision facts: no-op, replace, open, close or defer | `BehaviorScheduleRevisionPlanner` (`Core/Services`) | `HabitsRepositorySwiftData.stageScheduleHistory`, called synchronously inside the actor operation | None; pure Foundation values |
| `BehaviorScheduleRevisionIDProviding` (`Core/Protocols`) | Mint the logical ID of a normal revision, only for an insert | `BehaviorScheduleRevisionIDProviderV1` (`Core/Services`) | `HabitsRepositorySwiftData` (the insert helper) | An injected `@Sendable () -> UUID`; `BehaviorLogicalIdentity.canonicalUUIDText` (4C) |

**DI:**

- **`AppDependencies.make`** constructs both and injects them into the single `HabitsRepositorySwiftData(container:scheduleRevisionPlanner:scheduleRevisionIDs:)`. It is still the only `HabitsRepositorySwiftData(container:` in the DI file.
- **The actor's init defaults** to the same V1 implementations, so every existing construction site keeps compiling unchanged: tests, and the `RootTabsView` fallback, which is not touched.
- **Existing boundaries are reused:** `HabitRepositoryProtocol` remains the persistence abstraction, and `HabitService.now` remains the clock.
- **Not added:** no second actor, no profile enrollment service, no 4D planner.

## 12. Existing Production Files Modified

| Path | Symbol | Reason |
|---|---|---|
| `Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift` | `init(container:scheduleRevisionPlanner:scheduleRevisionIDs:)`, `createHabit`, `updateMetadata`, `updatePriority`, `delete`, `restoreDeletedHabit`, new `commit(_:)` + `#if DEBUG setBeforeCommitForTesting` | Take `effectiveAt`, stage schedule history in the same context, save once through `commit`; return `HabitMutationResult` / `ScheduleHistoryOutcome?`. Phase 3 `executeBehavior` window and `recordLegacyCompletion` untouched. |
| `Core/Protocols/HabitRepositoryProtocol.swift` | `createHabit`, `updateMetadata`, `updatePriority`, `delete`, `restoreDeletedHabit` | New `effectiveAt: Date` parameter; return types unchanged |
| `Core/Repositories/SwiftDataHabitRepository.swift` | same five | Forward `effectiveAt`; return `.habit` / discard outcome |
| `Core/Services/HabitService.swift` | `createHabit`, `updateHabit`, `deleteHabit`, `changePriority`, `restoreDeletedHabit` | Pass `effectiveAt: now()` (the existing injected clock). `completeHabit` unchanged. `HabitServiceProtocol` unchanged. |
| `App/AppDependencies.swift` | `make(container:storageDurability:featureFlags:)` | Construct and inject planner + ID provider |

**Test call-site migrations** (no assertion changed):

- `NotificationInvestigationTests.AuditRepository`: the five protocol signatures, plus a fixed `effectiveAt` for `seed`.
- `MetadataSafePersistenceTests.testSuppliedCalendarTimeZoneDecidesLegacyDayGrouping`: two direct `createHabit` calls now pass `effectiveAt`.

**Not modified** (enforced by `verify.sh`, which fails if any of these change):

- every `*SD` model file, `HabitSchemaMigration`, `HabitMapper`;
- 4C `LocalDay`, `OccurrenceIdentityV1`, `BehaviorLogicalIdentity` and their protocols;
- 4F `PersistentStoreFactory`, `StorageDurabilityState`, `HabitHonkerApp`;
- Phase 1 `Core/Gamification`, and the Phase 3 transaction service, repository, `BehaviorTransactionSD` and models;
- `HabitServiceProtocol`, every file under `Screens/` and `Servise/`, and the Xcode project.

## 13. New Production Files

| Path | Responsibility |
|---|---|
| `Core/Domain/BehaviorScheduleSnapshot.swift` | `BehaviorScheduleSource`, `BehaviorScheduleSnapshot`, weekday mask, V1 normalization, `BehaviorScheduleSourceChange` |
| `Core/Domain/BehaviorSchedulingPolicy.swift` | `BehaviorSchedulingPolicy` (fixed Gregorian + profile zone), `BehaviorScheduleProfileFacts`, `BehaviorScheduleEnrollment.resolve` |
| `Core/Domain/ScheduleHistoryOutcome.swift` | `ScheduleHistoryOutcome`, `ScheduleRevisionChange`, `BehaviorScheduleHistoryConflict` |
| `Core/Domain/BehaviorScheduleRevisionPlan.swift` | `BehaviorScheduleMutation`, `BehaviorScheduleRevisionFacts`, `BehaviorScheduleRevisionPlan` |
| `Core/Protocols/BehaviorScheduleRevisionPlanning.swift` | Planner protocol |
| `Core/Protocols/BehaviorScheduleRevisionIDProviding.swift` | ID provider protocol |
| `Core/Services/BehaviorScheduleRevisionPlanner.swift` | V1 pure planner |
| `Core/Services/BehaviorScheduleRevisionIDProviderV1.swift` | V1 normal revision identity |
| `Core/Models/HabitMutationResult.swift` | `habit` + `scheduleHistory` returned by the actor |
| `Repository/SwiftDataRepository/BehaviorScheduleRevisionMapper.swift` | `HabitSD` → source, profile → facts, revision row ↔ snapshot, new open row |
| `Repository/SwiftDataRepository/HabitsRepositorySwiftData+ScheduleHistory.swift` | Actor extension: `stageScheduleHistory` (read profile/revisions, plan, stage; never saves) |

**Why a separate extension file for the history staging.** The frozen Phase 2 guard `GamificationPersistenceTests.testSourceBoundariesKeepStorageOutOfLiveCompletion` forbids the names `GamificationProfileSD` and `BehaviorScheduleRevisionSD` (among others) in `HabitsRepositorySwiftData.swift`. The staging therefore lives in an extension of the **same actor** in its own file. It still runs on the same actor, the same context and the same save, so there is no second actor and no suspension. The guard's intent, keeping live completion free of gamification storage, is now also asserted directly by 4B: the `recordLegacyCompletion` window contains no schedule-history code.

## 14. Tests

124 new tests in 7 classes, plus the shared fixtures in `ScheduleHistoryTestSupport.swift` (`Sched`). They use real V2 SwiftData stores, the production actor, planner and V1 provider, deterministic UUIDs, and Los Angeles wall-clock fixtures built on an explicit Gregorian calendar.

| Contract | Test |
|---|---|
| B1 | `BehaviorScheduleRevisionPlannerTests.testB1IdenticalSnapshotsNeedNoRevision` |
| B2–B5 | `testB2TitleOnly…`, `testB3DescriptionOnly…`, `testB4TagsOnly…`, `testB5IconColorOnly…` (through the real `HabitSD` → source mapping) |
| B6–B16 | `testB6Priority…` … `testB16SchedulingCalendarChange…` |
| normalization | `testRepeatingSnapshotIsNormalizedExactly`, `testOneTimeSnapshotKeepsDueAtWithoutMaskOrClockEvenWithNotificationOff`, `testClockIsReadInThePolicyTimeZone`, `testPersistedRowMapsExactlyLikeTheAppReadsIt` |
| B17–B25 | `testB17SundayIsBit0` … `testB23SaturdayIsBit6`, `testB24MondayWednesdayFridayMaskIsExact`, `testB25IterationOrderAndDuplicatesCannotChangeTheMask` |
| planner rules | `testUpdateWithoutOpenRevisionIsDeferred`, `testSeveralOpenRevisionsAreNeverResolvedEvenWhenIdentical`, `testOpenRevisionThatNoLongerDescribesTheHabitIsDeferredEvenIfTheEditMatchesIt`, `testUndecodableOpenRevisionIsNotTrusted`, `testRelevantUpdateReplacesTheOpenRevisionAtEffectiveAt`, `testMutationBeforeEnrollmentIsDeferredOnlyWhenItWouldWrite`, `testBoundaryEarlierThanRecordedHistoryIsDeferredAndEqualBoundaryIsAllowed`, `testDeleteClosesTheTrustedOpenRevision`, `testCreateAndRestoreOpenOnlyWithoutAnOpenRevisionAndAfterRecordedHistory`, `testPlanIsDeterministic` |
| enrollment resolution | `testEnrollmentResolutionFollowsStoredProfileFactsOnly`, `testEnrolledResolutionDoesNotQueryRevisionHistory` |
| B26–B29 | `BehaviorScheduleRevisionIdentityTests.testB26…` … `testB29FixedProviderIsDeterministic`, `testProductionProviderMintsAFreshCanonicalRevisionUUIDEachTime` |
| B30–B31 | `testB30NoOpAndNotEnrolledMutationsMintNoRevisionID`, `testB31DeferredMutationsMintNoRevisionID` |
| B32–B37 | `BehaviorScheduleRevisionPersistenceTests.testB32…` … `testB37…`, `testMissingHabitOrArchiveWritesNothingAndReportsNoOutcome` |
| B38–B46 | `testB38TitleUpdateKeepsBaselineOpen` … `testB46SubmittingTheSameRelevantValuesAgainAddsNoRevision`, `testHiddenClockChangeWithRemindersOffWritesNoRevision` (B13 end to end), `testRevisionChainAcrossSeveralEditsIsContiguous` |
| B47–B49 | `BehaviorScheduleLifecycleTests.testB47…`, `testB48…`, `testB49CreateWritesHabitAndFirstRevisionInOneAtomicSave`, `testCreateWhenHistoryIsUnsafeStillCreatesTheHabit`, `testCreateWithAnExistingIDStillThrowsAndWritesNothing` |
| B50–B53 | `BehaviorScheduleHistoryConflictTests.testB50…` … `testB53…`, `testDeferredEditLeavesHistoryBehindAndLaterEditsStayDeferredUntilReconciled` |
| B54–B58 | `testB54TwoPhysicalEnrolledProfilesDeferHistory` … `testB58ProfileWithoutTrackingStartButWithRevisionRowsReportsOrphanHistory` |
| B59–B62 | `testB59…` … `testB62MutationEarlierThanTheOpenRevisionDefersHistory`, `testMutationBeforeTrackingStartedAtDefersHistory` |
| stored facts 4B cannot trust | `testOpenRevisionWithAnotherTimeZoneThanTheProfileIsDeferred` (§46), `testOpenRevisionWithAnIncompletePayloadIsDeferred`, `testStoreWithoutTheGamificationSchemaIsNotEnrolled` |
| B63 | `BehaviorScheduleRevisionPersistenceTests.testB63ChangeExactlyAtTrackingStartedAtLeavesAZeroDurationBaseline` |
| B64–B66 | `BehaviorScheduleLifecycleTests.testB64…`, `testB65…`, `testDeleteWhoseOpenRevisionNoLongerMatchesStillDeletes`, `testB66DeleteFailureRollsBack…` |
| B67–B70 | `testB67…`, `testB68RestoreNeverReopensAnOldRevision`, `testB69…`, `testRestoreOfAHabitArchivedBeforeEnrollmentOpensItsFirstRevision`, `testB70RestoreFailureRollsBack…` |
| B71–B75 | `BehaviorScheduleMutationIntegrationTests.testB71…`, `testB71bActualFailingSaveOfAnEdit…`, `testB72…`, `testB73…`, `testB74ActualFailingSaveOfADelete…`, `testB75ActualFailingSaveOfARestore…` |
| B76–B79 | `testB76…`, `testB77…`, `testB78DeleteRestoreRevisionLifecyclePreservesArchiveRecordSemantics`, `testB79StaleDetailsSaveAfterEnrollmentKeepsTheCompletion`, `testLegacyCompletionHasNoScheduleHistoryEffect`; plus the unchanged 4A suite `MetadataSafePersistenceTests` in the full run |
| B80–B81, §68 | `testB80ScheduleHistoryNeverChangesTheProfileOrWritesOtherGamificationRows`, `testB81ScheduleHistoryNeverCreatesAProfile`; every deferral test also asserts profile rows and occurrence/event/ledger counts unchanged |
| B82 | `BehaviorScheduleRevisionPersistenceTests.testB82DeviceTimeZoneDoesNotChangeTheRevisionSnapshot` (`NSTimeZone.default` = Asia/Tokyo, then Europe/London, restored after) |
| B83 | `testB83RevisionsWrittenByTheProductionPathSurviveReopeningTheStore` (on-disk store, production update and create paths, reopened) |
| B84 | `BehaviorScheduleMutationIntegrationTests.testB84ConcurrentCompletionsAndRevisionEditsKeepCountsAndAValidChain` (20 completions, 20 priority changes, 10 stale Details saves; two services, one actor) |
| wiring | `testServiceCapturesEffectiveAtFromItsInjectedClock`, `testAppDependenciesWireThePlannerAndTheV1RevisionIDProvider` |
| §72–§75 guards | `BehaviorScheduleRevisionArchitectureTests` (7 tests: pure layer, identity minting, staging scope, single context/save per mutation, application boundary and DI, frozen 4C/4F/Phase 3, Schema V2 and migration plan unchanged, no new `@Model`, no V3) |

**Targeted counts:**

- **First run:** 124 executed, 123 passed, 1 failed (B82's `TimeZone.current` precondition; see §1), 0 missing from xcresult.
- **After the B82 test-only fix:** _pending rerun_.

**Final count:** 299 executed (175 + 124), 298 passed in the first run; _pending rerun_.

## 15. Atomicity Verification

Each case is _pending execution_. Two failure modes are covered:

- **Injected (DEBUG seam):** a failure injected after the whole write set is staged, with the staging itself asserted inside the hook.
- **Real SQLite save failure:** the store is reopened with `allowsSave: false`.

After every failure, `TxStore.state` (every field of every table) must equal the state before.

| Scenario | Test | Staged before the failure | After |
|---|---|---|---|
| Metadata + close + insert | B71 | Title changed, baseline `effectiveTo = T`, new row from T | Old metadata, baseline open, no new row; the same edit then succeeds |
| Metadata edit, real failing save | B71b | — | Nothing persisted |
| Priority + revision | B72 | Priority changed, 2 revision rows | Unchanged |
| Create + first revision (one-time) | B49 (repeating), B73 (one-time) | Habit + `oneTime` revision | Neither persists |
| Delete + close | B66 (seam), B74 (real) | Habit delete, archive insert, revision close | Habit present, no archive, revision open |
| Restore + new revision | B70 (seam), B75 (real) | Habit insert, archive delete, revision insert | Archive present, no Habit, no new revision |

## 16. Completion History Verification

**Did HabitRecord IDs, counts or dates change? NO** (expected, _pending execution_).

- **B76 and B77:** revision-relevant edits and priority revisions keep every record's id, date and count, and the row count, unchanged.
- **B78:** delete/restore through revision history restores exactly the original ids, dates and counts. The record-row count equals that of the same flow in an unenrolled store, so schedule history adds, removes and copies no record row.
- **B79:** a stale Details save after enrollment keeps the completion.
- **B84:** 20 concurrent completions are all counted.
- **Guards:**
  - The staging file never mentions `records` or `HabitRecordSD`.
  - The 4A windows for create, update and priority still contain no `records`.

## 17. Gamification Side Effects

| Question | Answer |
|---|---|
| Did 4B create a profile automatically? | **NO** (B81; guard: no `GamificationProfileSD(` outside Phase 2/3 files) |
| Did 4B create an occurrence? | **NO** |
| A BehaviorEvent? | **NO** |
| A ledger entry? | **NO** |
| Award XP? | **NO** |
| Award coins? | **NO** (B80: `trackingStartedAt`, zone, calendar, `totalXP`, `honkerCoins`, `lifetimeCoinsEarned`, `lifetimeCoinsSpent` byte-identical) |

## 18. Schema Verification

| Question | Answer |
|---|---|
| V2 changed? | **NO** (no model file touched; entity/property inventory asserted) |
| Migration plan changed? | **NO** (2 schemas, 1 lightweight stage) |
| `@Model` added? | **NO** (guard: `@Model` only in the five frozen model files; no `SchemaV3`) |
| New persisted flag (`isCutoverSafe`, `historyDeferred`, …)? | **NO** |

## 19. Production Behavior Verification

| Question | Answer |
|---|---|
| Did live completion change? | **NO** (`completeHabit` → `recordLegacyCompletion` untouched; guarded) |
| Did the UI show gamification? | **NO** (no view, view model or `HabitServiceProtocol` change) |
| Did storage mode change? | **NO** (4F files untouched) |
| Does any production mutation write a revision today? | **NO**: there is no enrolled profile before 4E, so every mutation reports `notEnrolled` |

## 20. Baseline vs Targeted vs Final Tests

| Run | Executed | Passed | Failed | Skipped | Exit |
|---|---:|---:|---:|---:|---:|
| Baseline (`907b377`) | 175 | 175 | 0 | 0 | **0** |
| Targeted, first run | 124 | 123 | 1 | 0 | 65 |
| Final, first run | 299 | 298 | 1 | 0 | 65 |
| `git diff --check`, first run (tracked, and with new files) | | | | | clean |
| B82 alone, after the test-only fix | _pending_ | | | | |
| Targeted, after the fix | _pending_ | | | | |
| Final, after the fix | _pending_ | | | | |
| `git diff --check`, after the fix | | | | | _pending_ (checked locally: clean) |

## 21. Known Limitations

Expected future work, not 4B failures:

- There is no automatic enrollment and no baseline creation yet (4E).
- There is no occurrence planner (4D) and no reconciliation (4G). Deferred targets stay derivably `notCutoverSafe` until 4G.

Actual remaining limitations of this implementation:

1. **The B82 test-only fix has not been executed yet** (no Xcode in this environment). Everything else compiled, and 298 of 299 tests passed.
2. **`effectiveAt` is captured at the application boundary, before the actor hop** (contract §21).
   - The risk: two concurrent revision-relevant edits of the same Habit, from two screens, may reach the actor in the opposite order to their clock reads. The later-arriving edit then reports `revisionChronologyConflict` (history deferred, never corrupted; the target becomes not cutover-safe).
   - Where it cannot happen: the list screen serializes its own edits per UUID. What remains is a cross-screen race inside the actor-hop latency.
3. **Orphan-history detection is store-wide.** With no enrolled profile, any revision row in the store reports `orphanRevisionHistory` for every mutation.
4. **Only rows keyed `profile:v1:default` are profiles.** Rows with any other key are not V1 profiles and are ignored. More than one row with the V1 key defers history even when none is enrolled (§19, taken literally).
5. **A no-op edit is not checked** against `trackingStartedAt` or revision chronology, because it writes nothing.
6. **The archive's `deletedAt`** still comes from `HabitMapper.makeDeletedSD`'s own clock read (unchanged 4A/legacy behavior). It can differ by milliseconds from the revision's close instant. The revision `effectiveTo` is the schedule-history boundary.
7. **Pre-existing, unchanged:** a Details save rewrites every editable field (4A semantics), so a stale draft can revert a concurrent priority change. 4B records such a revert faithfully as a revision. `restoreDeletedHabit` still recreates record rows and leaves the archive's rows orphaned (4A §8), and B78 pins that nothing about it changed.

## 22. Final Gate

| Definition of done (§78) | Status |
|---|---|
| Fresh baseline green | **yes** (175/175, exit 0) |
| Pure snapshot; pure, protocol-backed planner; injectable ID provider; frozen normal ID format | **verified** (first run; all related tests passed) |
| Pre-enrollment: zero revisions, zero profiles | **verified** (first run; all related tests passed) |
| Healthy relevant edits create revisions; non-relevant edits and hidden clock noise do not | **verified** (first run; all related tests passed) |
| One-time `dueAt` persisted; mask deterministic; profile zone/calendar drive the snapshot; device zone does not | tests passed, except B82 (persisted payload was identical; only its device-zone precondition failed; rerun pending) |
| Current Habit must match the open revision; mismatch, multiple profiles, multiple or missing open revisions defer; metadata still saves | **verified** (first run; all related tests passed) |
| Create opens a first normal revision; delete closes; restore opens new, never reopens | **verified** (first run; all related tests passed) |
| One actor, one context, one save; rollback leaves no partial state | **verified** (first run; all related tests passed) |
| HabitRecord history unchanged; no occurrence/event/ledger/profile-balance writes; no live cutover; Schema V2 unchanged | **verified** (first run; all related tests passed) |
| Phase 1–4C regressions, targeted 4B, final suite, `git diff --check` | first run: every Phase 1–4C regression green, 123/124 targeted, 298/299 final, diff-check clean. The only failure is the B82 precondition, fixed in the test; rerun _pending_. |
| Phase 4B report complete | yes |

**READY FOR PHASE 4E: NO**: pending `rerun.sh` (expected 124/124 targeted, 299/299 final, diff-check clean).

STOP.
