# Gamification Phase 4A Report — Metadata-safe persistence

**Contract:** `Docs/HabitHonkerExp-v1.1.2.md` (§4A) and `Docs/HabitHonkerExp-v1.1.2-Claude-Phase4.md` (4A section).
**Base commit:** `2e569af` (Phase 3).
**Status:** **IMPLEMENTED — VERIFICATION PENDING.** The code and tests are written, but they have not been compiled or run yet. This run executed on a Linux machine without Xcode, so no `xcodebuild` was possible. Verification is one command on the Mac (§9). Until its results are recorded here, the gate below stays **NO**.

---

## 1. Fresh baseline

**Not yet executed** (no Xcode in this environment).

The working tree still contains the untouched pre-4A code at commit `2e569af`. So the baseline is taken from a temporary **git worktree of `2e569af`**; this is byte-identical to the code that existed before this run. `.phase4a/verify.sh` does this automatically:

| Run | What | Expected |
|---|---|---|
| `baseline` | full `HabitHonkerTests` on `2e569af` | 112 / 112 / 0 / 0 (Phase 3 historical number, to be confirmed fresh) |
| `characterization` | `Phase4ABaselineCharacterizationTests` on `2e569af` | failures = failing-first evidence (§3) |
| `final` | full `HabitHonkerTests` on the working tree | all pass |

Deviation from the contract, stated plainly: the baseline did not run *before* the code changes. It runs on an identical copy of the pre-change code instead. It is still a fresh run, not a historical number.

## 2. Root cause (verified by reading the code at `2e569af`)

- `HabitMapper.apply(_:to:)` (L120–141) copied **every** field of a `HabitModel`, including the whole `record` array. It built brand-new `HabitRecordSD` objects and assigned `sd.records = newRecords`.
- `HabitsRepositorySwiftData.upsert` (L298–320) used that apply for every write, and **inserted** a new row when the id was missing.
- `HabitService.saveHabit`, `completeHabit` and `changePriority` (L26–51) all wrote through this whole-model `upsert`. Completion and priority read the model in one actor call, mutated it in memory, and wrote it back in a second call.
- `HabitDetailView.savedItem()` (L53–81) returns the draft's `record` array as it was when Details opened.

**Consequences:**

1. **Stale draft wipes completions.** Any completion between opening Details and pressing Save is overwritten by the draft's older record array. Examples: a queued swipe, or a CloudKit import.
2. **Stale save resurrects deleted habits.** A save for a habit that has been deleted re-inserts it.
3. **Lost updates across screens.** Priority Matrix (outside the list's per-UUID queue) and completion can overwrite each other between their read and their write.
4. **Orphan rows (hypothesis).** Each metadata save replaces the relationship with new objects and may leave the previous `HabitRecordSD` rows orphaned (`habit == nil`). Proven or disproven by `testMetadataSavesDoNotCreateOrphanRecordRows` (§3).

## 3. Failing-first characterization (pre-4A code)

File: `.phase4a/BaselineCharacterizationTests.swift`. It uses the pre-4A API and is compiled **only** into the baseline worktree, never into the app's test target. Each test asserts the 4A invariant; on the old code a failure is the evidence, and its message carries the measured values (`PRE-4A EVIDENCE: …`).

| Test | Pre-4A expectation | Result |
|---|---|---|
| `testStaleDraftSaveKeepsLaterCompletion` | FAIL (count 0) | _pending_ |
| `testMetadataSavesDoNotCreateOrphanRecordRows` | orphan hypothesis: FAIL if rows grow beyond 3 | _pending_ |
| `testStaleSaveAfterDeleteDoesNotResurrect` | FAIL (row re-inserted) | _pending_ |
| `testPriorityChangeAfterCompletionKeepsCompletion` | PASS (control: sequential priority change after completion was safe) | _pending_ |

**Orphan hypothesis:** _pending_ — record "confirmed" or "disproven" with the measured row counts.

## 4. API before / after

| Layer | Before | After |
|---|---|---|
| Domain | `HabitModel` (metadata + `record`) for every write | New `HabitMetadata`: every editable field **except** `record`. New `HabitRepositoryError { alreadyExists, notFound, completionCountOverflow }` |
| `HabitRepositoryProtocol` | `upsert(_ HabitModel)` | `createHabit(id:metadata:)`, `updateMetadata(id:metadata:)`, `updatePriority(id:priority:)`, `recordLegacyCompletion(id:at:calendar:)`. All return the fresh persisted `HabitModel`. `upsert` removed. |
| Repository actor | `save`, `update`, `upsert` (whole model, records rebuilt; upsert inserts when missing) | Same four operations, **one context + one save each**, placed below `// MARK: - CRUD` (outside the Phase 3 structural-test window). `save`/`update`/`upsert` removed. |
| `HabitMapper` | `apply(_ HabitModel, to:)` rebuilt `records` | `applyMetadata(_:to:)` never touches `records`. `makeSD(id:metadata:)` creates a row with no history. `makeSD(from:)` kept for archive restore only. `makeDeletedSD`/`deletedToDomain`/`toDomain` unchanged. |
| `HabitServiceProtocol` | `saveHabit(_:)` (create-or-update by pre-fetch) | `createHabit(_:) -> HabitModel` (`.created`), `updateHabit(_:) -> HabitModel` (`.updated`, throws `notFound`). `completeHabit`/`changePriority` keep their signatures and return `nil` on `notFound`. |
| `HabitService` | fetch → mutate (`completeHabitNow`: `Date()`, `Calendar.current`) → upsert | One repository call per operation. Clock and calendar are injected (`now`, `calendar`) with defaults `Date()` / `Calendar.current`, so live behavior is unchanged. |
| `HabitListViewModel` | `saveItem` for both create and edit; kept the submitted draft in memory | `createItem` (add-new route) and `saveItem` (Details edit). Both keep the per-UUID coordinator and today's order (notification reconcile, then persist). Both store the **returned** persisted model. |
| `HabitListView` | both routes → `saveItem` | `.addNewHabit` → `createItem`; `.detailHabit` → `saveItem` |

### Semantics

- **Create:** an existing id throws `alreadyExists`; the existing row is untouched. Draft records are ignored, so a new habit starts with no history.
- **Update metadata:** a missing id throws `notFound` and **never inserts**. `records` are never read, assigned or recreated. It returns the persisted model with its current records.
- **Update priority:** priority only.
- **Legacy completion:** one actor operation. It finds the record on the supplied calendar's day for the supplied instant.
  - One match: checked increment, keeping the record's UUID and original timestamp.
  - No match: insert a record at the supplied instant.
  - Several matches (a legacy/sync anomaly): increment the earliest one (then the smallest UUID string); nothing is merged or deleted. The old code incremented whichever came first in unstable array order.
- **No-resurrection notification fix:** today, notifications are rescheduled *before* persistence. `saveItem` keeps that order. If the update is rejected with `notFound` (the habit was deleted meanwhile), it now calls `notifier.cancel(for:)`, so no alarm survives for a missing habit. No other notification behavior changed.

## 5. Production files changed

| File | Change |
|---|---|
| `Core/Models/HabitMetadata.swift` (new) | `HabitMetadata`, `HabitRepositoryError` |
| `Core/Protocols/HabitRepositoryProtocol.swift` | `upsert` → four explicit operations |
| `Core/Protocols/HabitServiceProtocol.swift` | `saveHabit` → `createHabit` / `updateHabit` |
| `Core/Repositories/SwiftDataHabitRepository.swift` | forwards the four operations to the shared actor |
| `Core/Services/HabitService.swift` | narrow operations; injected `now` / `calendar` |
| `Repository/SwiftDataRepository/HabitMapper.swift` | `apply` → `applyMetadata`; new `makeSD(id:metadata:)` |
| `Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift` | removed `save` / `update` / `upsert`; added the four operations (Phase 3 code and window untouched) |
| `Screens/TaskList/HabitListViewModel.swift` | `createItem`; `saveItem` = metadata update + `notFound` alarm cleanup; stores returned models |
| `Screens/TaskList/HabitListView.swift` | add-new route → `createItem` (1 line) |

**Protected, unchanged:**
- every `*SD` model file, `HabitSchemaMigration`, the migration plan (schema V2 untouched, no new `@Model`);
- `BehaviorTransaction*`, `Gamification*`, `AppDependencies`, `HabitHonkerApp`, `RootTabsView`;
- `HabitNotificationService`, `Statistics*`, `PriorityMatrixViewModel`, `HabitDetailView`, `HabitModel`;
- project settings, entitlements.

## 6. Tests

### Added — `HabitHonkerTests/MetadataSafePersistenceTests.swift`

These run on a real in-memory V2 store through the production service, repository and actor.

| Contract | Test |
|---|---|
| A1 | `testStaleDraftSaveKeepsCompletionMadeAfterDraftWasLoaded`, `testListViewModelStaleDetailsSaveKeepsCompletion` |
| A2 | `testPriorityChangeAfterCompletionPreservesCompletion` |
| A3 / A4 | `testRepeatedMetadataEditsKeepRecordIDsDatesCountsAndRowCount`: title, icon, color, notification, weekdays + time, type, description/tags and two priority changes. The draft carries a deliberately wrong `record` array. Record ids, dates and counts, total row count and orphan count must be unchanged. |
| A5 | same test (row count stays 3, orphans 0) + pre-4A characterization (§3) |
| A6 | `testUpdateAfterDeleteThrowsNotFoundAndDoesNotResurrect` (also covers `changePriority`/`completeHabit` returning nil and the archive staying intact) |
| A7 | `testCreateWithExistingIDThrowsAlreadyExistsAndDoesNotOverwrite`, `testCreateIgnoresDraftRecordsAndStartsWithoutHistory` |
| A8 | `testLegacyCompletionSameDayIncrementsAndKeepsRecordIDAndDate` |
| A9 | `testLegacyCompletionNextLocalDayInsertsNewRecord` |
| A10 | `testSuppliedCalendarTimeZoneDecidesLegacyDayGrouping`: the same two instants form one day in UTC and two days in Los Angeles |
| A11 | `testConcurrentPriorityAndMetadataEditsNeverLoseCommittedCompletions`: two services on one repository, 20 completions interleaved with 20 priority changes and 10 stale-draft metadata saves → count 20, 1 row, 0 orphans |
| — | `testLegacyCompletionOnMissingHabitThrowsNotFoundAndInsertsNothing`, `testLegacyCompletionWithSeveralSameDayRecordsIncrementsOnlyTheEarliest` |
| — | `testMetadataWritePathsDoNotTouchRecordsAndBroadUpsertIsGone` (source guard) |

### Added to `HabitListViewModelNotificationTests`

- `testSaveItemForHabitDeletedMeanwhileCancelsTheAlarmItJustScheduled`: the no-resurrection alarm cleanup.
- `testCreateItemReschedulesAndCreatesHabit`.

### Migrated (no behavioral assertion removed; test names kept so baseline identities match)

- **`NotificationInvestigationTests`:**
  - The first persistence of a brand-new habit now calls `createItem`, edits still call `saveItem`, and seeding uses `repository.seed` (explicit create) instead of `upsert`.
  - The `AuditRepository` spy now implements the four operations. `failUpsert`/`nextUpsertGate`/`upsertArguments` became `failWrites`/`nextWriteGate`/`writeAttempts`, applying to every write, plus a new `committedWrites`.
  - "Last upsert was the edited habit" now checks the last **committed** write, which is stronger.
  - In `testCompletionQueuedAfterDeleteDoesNotRecreateHabit`, the final check becomes: 1 committed write, and 2 attempts, because the queued completion now reaches the repository and is rejected with `notFound`. All row, alarm and in-memory assertions are unchanged.
- **`HabitListViewModelNotificationTests.HabitServiceSpy`:** `saveHabit` became `createHabit` / `updateHabit`, with an optional `updateError`.

### Unchanged and expected to pass

- All Phase 1–3 suites.
- `GamificationPersistenceTests.testLiveCompletionInV2LeavesAllNewTablesEmpty` and `BehaviorTransactionDITests.testCurrentHabitServiceViaNewDIStillWritesNoGamificationRows`: completion still writes no gamification rows.
- Both source guards: no gamification tokens were added to guarded files, and the `executeBehavior … // MARK: - CRUD` window is untouched.
- Statistics tests.

## 7. Behavior changes

1. **A stale Details save no longer erases completions.** This is the fix.
2. **Updating a habit that no longer exists fails with `notFound` instead of silently re-inserting it.** The error goes to `viewModel.error`, which the UI still doesn't show (audit L2, out of scope), and the alarm scheduled for it is cancelled. This also affects the Details mock-fallback route (audit L8): saving a habit that was never persisted now fails instead of creating a new one.
3. **Metadata saves no longer create new `HabitRecordSD` rows.** If the orphan hypothesis is confirmed, this also stops the growth.
4. **Same-day completion with several same-day records increments the earliest one deterministically.** Before, it was array order. Only matters for legacy/sync anomalies.
5. **The list shows the persisted habit returned by the repository.** For colors, this is the stored hex round trip, the same value a reload already showed.

No change to schema, Statistics, notification semantics beyond item 2, gamification, or UI.

## 8. Remaining risks / out of scope

- **Existing orphan rows** (if confirmed) are not cleaned. Deleting them during a CloudKit import could delete real data, so that needs its own rule later.
- **`restoreDeletedHabit` still copies archived records** into new rows, leaving the archive's rows orphaned. There is no restore UI today. Revisit with 4B's restore handling.
- **Duplicate `HabitSD` rows with the same id** (possible under CloudKit): the lookup keeps the existing first-match rule of `fetch(id:)`. Multiplicity is 4G's scope.
- **Errors are still not shown in the UI** (audit L2). The notification-before-persistence order is unchanged except for the `notFound` cleanup (audit L4).
- **Not compiled yet.** Compile errors are possible; they will show in `.phase4a/logs/summary.txt`.

## 9. How to verify (Mac)

```sh
bash ~/Development/habitHonker/.phase4a/verify.sh
```

It creates a temporary worktree of `2e569af` and runs baseline → characterization → final. It writes logs, `.xcresult` bundles and JSON summaries (including per-test identities) to `.phase4a/logs/`, removes the worktree, and prints `.phase4a/logs/summary.txt`. The working tree is not modified. After it finishes, fill in §1, §3 and the gate below from `summary.txt` and the JSON summaries.

## 10. Gate

| Item | Result |
|---|---|
| Fresh baseline (2e569af) | _pending_ |
| Characterization (failing-first) | _pending_ |
| Targeted 4A tests | _pending_ |
| Final full suite | _pending_ |
| `git diff --check` | clean |
| Schema changed | NO |
| Live gamification enabled | NO |
| Known deviations | baseline taken from an identical worktree of 2e569af after the edits were written (no Xcode in the implementing environment) |

**READY FOR 4F: NO — pending the verification run.** Flip to YES only if the baseline and final suites are green and the targeted 4A tests pass.
