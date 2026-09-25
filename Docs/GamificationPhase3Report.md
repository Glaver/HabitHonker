# Gamification Phase 3 Report

## 1. Scope

Implemented the **Atomic Behavior Transaction Foundation**: normalized domain command/result/errors, narrow service/repository protocols, explicit DI, an adapter forwarding to the existing shared persistence actor, and one-context/one-save mutation of legacy completion, occurrence, event, optional grant and profile.

This is isolated infrastructure. No production completion cutover, V3/schema changes, planner, enrollment, reversal, reconciliation, weekly review, UI, notification or statistics change. The permanent operational contract is [GamificationTransactionContract.md](GamificationTransactionContract.md).

The previous interrupted attempt left implementation/tests on disk but had not run them or completed documentation. This resumed pass identified and corrected its compile blocker, completed both required documents, and passed all new and existing tests. **Phase 3 status: PASS**, verified September 24, 2026. The earlier report's preflight-blocked status is superseded by this implementation report, with the original failure retained below.

## 2. Fresh baseline

Commit: `01c4717797ad36493e068b3f7e5118a8136abcf8`.

Before Phase 3 source implementation, the user fixed the stale test initializer label in `HabitHonker/HabitHonkerTests/GamificationServiceTests.swift` from `xpRequiredForCurrentLevel` to the current source's `xpRequiredToNextLevel`. This user change was preserved; current source takes precedence over stale report naming. The earlier failed preflight had executed zero tests because of that label mismatch; it is not the comparison baseline.

**Fresh successful baseline after the user's fix and before Phase 3 production edits: 83 executed / 83 passed / 0 failed / 0 skipped**, exit 0. Log: `/private/tmp/habithonker-phase3-baseline-fixed.log`.

```sh
xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
  -destination 'platform=iOS Simulator,id=24629C99-E950-4563-BA70-118CE5D96451' \
  -derivedDataPath /private/tmp/habithonker-phase3 \
  -only-testing:HabitHonkerTests
```

Initial implementation working tree: the user's one-line test fix and the previous untracked preflight report. On September 24 resumption, partial Phase 3 files and unrelated `Docs/AppAudit-2026-09-23.md` also existed. The unrelated audit was not edited. A resumed full-target attempt then found the partial Phase 3 hook compile error; it does not replace the pre-change baseline.

Phase 1 input/result/RewardCalculationBreakdown/LevelProgress/service and all Phase 2 entities/schema/plan were inspected. Current ledger targetID/occurrenceID are optional scalars; completion supplies nonnil references without changing them. One-time streak remains zero; repeating streak must be at least one.

## 3. Architecture implemented

```text
AppDependencies.make(container)
  ├─ one HabitsRepositorySwiftData actor
  │    ├─ SwiftDataHabitRepository → existing HabitService (unchanged)
  │    └─ SwiftDataBehaviorTransactionRepository
  │          └─ BehaviorTransactionSD injected with pure GamificationService
  └─ BehaviorTransactionService exposed as BehaviorTransactionServiceProtocol

normalized command → service → repository protocol → adapter → shared actor
 → one autosave-disabled context → synchronous helper → one save → domain result
```

Only the new service is exposed; existing view models/HabitService do not consume it. No second persistence actor or global singleton is created by the new adapter.

### Files added

Under `HabitHonker/HabitHonker/`:

- `Core/Domain/BehaviorTransactionModels.swift`: frozen normalized command, snapshot, receipts/results and typed errors.
- `Core/Protocols/BehaviorTransactionServiceProtocol.swift`: domain/application operation boundary.
- `Core/Protocols/BehaviorTransactionRepositoryProtocol.swift`: atomic persistence contract with domain-only values.
- `Core/Services/BehaviorTransactionService.swift`: injected delegation.
- `Core/Repositories/SwiftDataBehaviorTransactionRepository.swift`: shared-actor forwarding adapter.
- `Repository/SwiftDataRepository/BehaviorTransactionSD.swift`: synchronous read/validate/plan/stage helper.

Under `HabitHonker/HabitHonkerTests/`: BehaviorTransactionServiceTests, BehaviorTransactionRepositoryTests, BehaviorTransactionAtomicityTests, BehaviorTransactionDITests, and BehaviorTransactionTestSupport (all `.swift`). Documentation: this report and `Docs/GamificationTransactionContract.md`.

## 4. New protocols

| Protocol | Responsibility | Consumer | Implementation |
|---|---|---|---|
| BehaviorTransactionServiceProtocol | `complete(command) async throws` returns a domain transaction result | AppDependencies exposes it for future consumers; tests exercise it | BehaviorTransactionService |
| BehaviorTransactionRepositoryProtocol | One atomic completion operation, no SwiftData leakage | BehaviorTransactionService | SwiftDataBehaviorTransactionRepository forwarding to HabitsRepositorySwiftData |

Both protocols are Sendable. There are no speculative reverse/restore/skip/purchase/weekly methods.

## 5. New domain commands/results/errors

All values are Equatable/Sendable, and the domain file imports only Foundation.

### BehaviorCompletionCommand

| Field | Reason |
|---|---|
| commandID, transitionID | Delivery identity versus accepted transition identity |
| profileKey, occurrenceID | Explicit enrollment and logical occurrence references |
| completedAt | Explicit transition/ledger/profile timestamp |
| legacyCompletionDate | Explicit compatibility-record timestamp |
| legacyDay: DateInterval | Supplied half-open local-day interval; avoids current Calendar/timezone inference |
| rewardInput: GamificationRewardInput | Frozen targetID, task type, priority, streakAfterCompletion, isOnTime, eligibility, policyVersion |
| occurrence: BehaviorOccurrenceSnapshot | Historical schedule/metadata facts |
| source | Supplied event origin |
| predecessorTransitionID | Optional event linkage |
| computed targetID | Reuses rewardInput target rather than duplicate mutable identity |
| computed initialRewardKey | Exact policy-independent initial entitlement key |

### BehaviorOccurrenceSnapshot

Fields: scheduledLocalDateKey (civil date), scheduledAt/dueAt (known instants), schedulingTimeZoneIdentifier/schedulingCalendarIdentifier (historic policy), scheduleRevisionID (scalar revision link), iconName/notificationEnabled (optional frozen presentation/reminder facts), streakBefore (supplied prior streak), provenance (history quality/origin), predecessorOrAliasOccurrenceID (optional explicit identity linkage). Nil stays unknown, not inferred from current HabitSD.

### Results

- `BehaviorCommandReceipt`: commandID, transitionID, targetID, occurrenceID, completedAt, completionCount. Contains only durable immutable event facts.
- `BehaviorTransactionResult`: `.applied(BehaviorAppliedCompletion)` or `.duplicateCommand(BehaviorCommandReceipt)`; avoids incompatible success/retry boolean combinations.
- `BehaviorAppliedCompletion`: receipt; legacyRecordID/count; wasExistingOccurrence; reward disposition; resultingTotalXP/HonkerCoins/LevelProgress. Level is returned, never persisted.
- `BehaviorRewardDisposition`: `.granted(GamificationReward)`, `.ineligible`, or `.alreadyRewarded(logicalKey:)`.

### Errors

`invalidCommand`, `targetNotFound`, `profileNotFound`, `duplicateTarget`, `duplicateProfileKey`, `duplicateOccurrenceKey`, `duplicateCommandReceipt`, `duplicateLedgerLogicalKey`, `conflictingCommandReceipt`, `conflictingTransitionID`, `conflictingOccurrenceSnapshot`, `inconsistentStoredState`, `arithmeticOverflow`, `calculationFailure(GamificationCalculationError)`, `persistenceFailure(domain:code:message:)`.

Identity-bearing errors carry the relevant identifier; invalid/inconsistent-state errors carry a specific reason. Unexpected errors retain NSError diagnostic domain/code/message without exposing managed objects.

## 6. Transaction implementation

Save owner: `HabitHonker/HabitHonker/Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift`, actor `HabitsRepositorySwiftData`, methods `completeBehavior` → private `executeBehavior`.

`executeBehavior` calls existing `makeContext()` once. That creates one context with autosave disabled. It invokes `BehaviorTransactionSD.apply(command,in:)` synchronously. For `.applied`, it saves once at `try context.save()`; for duplicate receipts, it does not save. Catch rolls back and translates errors. Result is returned only after save succeeds. No await occurs between read and commit; the actor serializes commands for different habits as well as the same habit.

Helper: `Repository/SwiftDataRepository/BehaviorTransactionSD.swift`. It owns no container, never creates a context, and never saves. It validates/fetches bounded row sets, checks uniqueness/conflicts, computes counters/balances/level, stages all mutations, and returns a domain result.

Compile issue found on resume: DEBUG-only `beforeSave` was non-escaping but forwarded into an optional closure parameter (implicitly escaping). The common implementation now takes a non-optional non-escaping closure. Production supplies a no-op; the DEBUG-only testing method supplies a synchronous injected hook. No build-setting changes or persisted-model changes were required.

## 7. Atomic write set

| Entity | Applied-command writes |
|---|---|
| HabitRecordSD / HabitSD.records | Existing record in supplied `[start,end)` day increments with UUID/date preserved; otherwise explicit timestamp/count=1 record inserted and linked. Multiple day matches fail. |
| TaskOccurrenceSD | Create with all command snapshots/count=1/status completed; subsequent count advances while first completion/metadata remain frozen. Matching scheduled zero-count rows may become completed. |
| BehaviorEventSD | Exactly one completed receipt/event for each new accepted command; explicit IDs/time/source/provenance/count/predecessor. |
| GamificationLedgerEntrySD | Exactly one initial eligible grant if logical key absent; copies complete input and scalar breakdown from injected service. Existing entries are not edited. |
| GamificationProfileSD | For a new grant only: checked XP/coins/lifetime-earned additions, supplied updatedAt, clear stale aggregateFingerprint. Lifetime spent/enrollment/week policy untouched. |

No schedule revisions, profiles, archived rows or weekly snapshots are created by the transaction. Missing profile, even for ineligible work, aborts before mutation. Level derivation failure also aborts the bundle.

## 8. Idempotency implementation

- Durable BehaviorEventSD.commandID receipts replace in-memory flags. A compatible single receipt returns its original count/time/identity with no save. Multiple receipts fail.
- Transition identity reuse is separately rejected; command ID, physical ID and entitlement are not conflated.
- Occurrence lookup permits zero/one matching row and rejects duplicates. Stored immutable snapshots must match new commands exactly; no historical rewrite from mutable HabitSD.
- Initial key: `reward:v1:<profileKey>:<occurrenceID>:initial`. Zero rows allows an eligible award, one valid row prevents a second award, multiple rows fail. A changed policy version never creates a new key or reprices an existing grant.
- Different command IDs on one occurrence can advance day/occurrence counts and add events without changing profile/ledger. One-time repetition on a later supplied day creates another legacy day record but no new initial reward.

Retry replies intentionally contain no historical balance: V2 does not persist a complete prior result. A recognized receipt is processed before current target/profile lookup, remains a no-op after unrelated state changes, and compares the identity/time/source fields available in that receipt. It is not a full serialized-command equality/hash contract; see permanent contract for this limitation.

## 9. Gamification integration

AppDependencies creates existing RewardCalculator and LevelCalculator, then GamificationService, and injects it into the adapter/helper. On eligible first grants, the helper calls `reward(for: command.rewardInput)`, validates matching input/nonnegative deltas, and copies every RewardCalculationBreakdown field to the ledger. It derives LevelProgress through the same injected protocol before committing.

Required fixture passes: repeating, important/not urgent, streak 7, on-time, eligible, policy 1 → **41 XP / 10 HC**. Persisted basis: base25/3, scale100, multipliers130/115/110, bonuses2/5. Mutable habit fields deliberately differ. A substituted calculator test supplies **9/4** and sentinel breakdown values and proves those exact outputs are persisted; no persistence formula is duplicated.

Existing initial grants skip reward calculation, allowing count-only behavior without repricing even under an unsupported newer supplied policy. Ineligible commands skip grants entirely; no zero-value ledger receipt is fabricated. Profile existence and level boundary still apply.

## 10. DI

`App/AppDependencies.swift` adds a protocol-typed `behaviorTransactionService` property. `make(container:)` creates one `swiftDataRepository` actor, passes it to both adapters, injects a pure GamificationService, and creates BehaviorTransactionService. No transaction service is passed into HabitService, view models or RootTabsView.

Tests construct two containers and independent DI graphs. A command through graph A changes only A; the same command in B applies independently. Empty-store DI construction leaves all new tables empty. A structural check confirms exactly one repository-actor construction and both adapters receiving the same variable.

## 11. Failure behavior

| Condition | Result |
|---|---|
| Missing target or supplied profile | Typed not-found; no enrollment/partial behavior |
| Duplicate target/profile/occurrence/receipt/ledger | Typed conflict; no arbitrary selection, no writes |
| Reused incompatible command/transition | Typed receipt/transition conflict; no writes |
| Immutable occurrence metadata differs | conflictingOccurrenceSnapshot; old facts untouched |
| Multiple records in supplied legacy day, missing known legacy link, unsupported state | inconsistentStoredState; no guessed merge |
| Counter/balance overflow | arithmeticOverflow before mutation |
| Reward policy or level range failure | Wrapped original GamificationCalculationError; no writes |
| Error after full staged write set | Rollback; fresh-context snapshot matches pre-call state; retry may apply |
| Actual save failure | persistenceFailure preserving diagnostics; never success; fresh context unchanged |

All failure assertions compare a complete store snapshot, including legacy fields/relationships and every scalar of the five new models. The actual save failure test opens an on-disk V2 fixture with `allowsSave: false`, calls the real operation/save path, and observes typed failure without durable writes.

## 12. Tests

**29 new tests**, grouped in four test classes plus reusable fixture/snapshot support.

| Test | Proof |
|---|---|
| Service: testExactDelegationAndIndependentServices | Exact command/result passthrough; two injected repositories independent |
| Service: testRepositoryErrorPropagates | Typed repository error unchanged |
| Repository: testEligibleWriteSetAndFrozenRewardFixture | Full committed write set, snapshot fields, 41/10 reward and profile/level; current metadata untouched |
| Repository: testRetryIsDurableNoOpAndReturnsStableReceiptAfterFurtherCounts | Recreated services recognize receipt; no mutations; original reply stable after later counts |
| Repository: testNewCommandSameOccurrenceIncrementsCountsWithoutRepricingPolicy | Count/event advance, one reward; changing policy does not re-award |
| Repository: testOnDiskRecreationRetainsCommandAndEntitlementIdempotency | Reopen same file with new container/service; retry no-op, new count no new award |
| Repository: testIneligibleWritesOnlyBehaviorAndLeavesProfileByteFactsUnchanged | Behavior evidence but no ledger/profile change |
| Repository: testOneTimeLaterDayCountDoesNotGrantAgain | Lifetime occurrence gets one reward despite later-day counts |
| Repository: testLegacyHalfOpenDayIncrementsExistingRecordAndPreservesTimestamp | Includes start/excludes end; record identity/time preserved |
| Repository: testInjectedGamificationControlsAmountsAndReceivesFrozenInput | Persistence consumes injected arithmetic, no formula duplication |
| Atomicity: testMissingProfileCommitsNothingEvenForIneligibleCompletion | No implicit enrollment, no partial writes |
| Atomicity: testMissingTargetCommitsNothing | No reward for missing active target |
| Atomicity: testDuplicateProfileCommitsNothing | No first-profile selection |
| Atomicity: testDuplicateTargetCommitsNothing | Ambiguous active target fails |
| Atomicity: testDuplicateOccurrenceCommitsNothing | No arbitrary occurrence selection |
| Atomicity: testDuplicateLedgerCommitsNothing | No third grant or balance adjustment |
| Atomicity: testDuplicateCommandReceiptCommitsNothing | Ambiguous receipt fails |
| Atomicity: testReceiptIdentityReuseAndTransitionReuseFailWithoutMutation | Conflicting identities rejected |
| Atomicity: testImmutableSnapshotConflictsCannotRewriteOccurrence | Priority/type/eligibility/date conflicts preserve history |
| Atomicity: testProfileArithmeticOverflowsAllRollBack | XP, coins, lifetime-earned overflow fail without mutations |
| Atomicity: testOccurrenceAndLegacyCountOverflowDoNotMutate | Count overflow protection |
| Atomicity: testCalculationAndLevelRangeErrorsCommitNothing | Reward policy/level errors abort bundle |
| Atomicity: testFailureAfterEntireWriteSetIsStagedRollsBackEveryField | Hook observes all five mutations then throws; no durable changes |
| Atomicity: testActualReadOnlyStoreSaveFailureNeverReturnsSuccess | Real on-disk save rejection propagates and leaves data intact |
| Atomicity: testTwoConcurrentHabitsShareActorAndAccumulateOneProfile | Concurrent commands result in 82 XP/20 HC, no lost update |
| Atomicity: testDuplicateLegacyDayRecordsFailSafely | No silent historical record merge |
| DI: testDependenciesAreScopedToEachContainerAndConstructionDoesNotEnroll | Container isolation and no construction side effects |
| DI: testCurrentHabitServiceViaNewDIStillWritesNoGamificationRows | Mandatory live-path no-cutover regression |
| DI: testOneSaveOwnerNoHiddenClockAndNoLiveConsumer | One save/context call site, rollback, no suspension/hidden clock/prohibited dependencies, shared actor |

Existing Phase 2 guard change: its source scan now permits the token GamificationService **only in AppDependencies**, because Phase 3 explicitly requires construction there. Direct persistence references remain forbidden there, and all live-consumer restrictions remain. Its existing runtime no-gamification test is unchanged; the new DI-driven test strengthens that runtime guarantee. No existing arithmetic, migration, statistics or notification expectation was weakened.

## 13. Baseline vs final

| Run | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| Fresh pre-implementation baseline | 83 | 83 | 0 | 0 |
| New Phase 3 tests | 29 | 29 | 0 | 0 |
| Final full suite | 112 | 112 | 0 | 0 |

New tests: exit 0, TEST SUCCEEDED, `/private/tmp/habithonker-phase3-new.log` and result bundle `Test-HabitHonker-2026.09.24_21-18-50--0700.xcresult` under the derived-data Logs/Test directory. Full-suite log: `/private/tmp/habithonker-phase3-final.log`. The structured result bundle `Test-HabitHonker-2026.09.24_21-21-29--0700.xcresult` confirms **112 total / 112 passed / 0 failed / 0 skipped** and result Passed. Its structured summary was used because interleaved console output split one test-result line. Every one of the 83 baseline test identities passed again; the 29 new tests passed in both targeted and full runs. No Phase-3-caused regressions. Targeted command uses the baseline flags with four `-only-testing:HabitHonkerTests/BehaviorTransaction...Tests` selections. Full command is identical to the baseline selection.

Verification uses Xcode 26.2 / iPhone 17 Pro Max simulator. It is the complete HabitHonkerTests target, not a UI-test run or a distributed CloudKit test. The interrupted draft's closure compilation failure is recorded in `/private/tmp/habithonker-phase3-resume.log`; it was fixed before successful new-test execution.

## 14. Expected vs actual

| Requirement | Expected | Actual | Status |
|---|---|---|---|
| Atomic one-save operation | All-or-nothing local bundle | One context/save site, rollback and real save failure tests | PASS |
| Eligible reward | Frozen 41 XP / 10 HC | Full scalar ledger and profile values verified | PASS |
| Ineligible completion | Behavior only | No ledger/profile changes | PASS |
| Same-command retry | Durable no-op | Stable receipt after repository/store recreation | PASS |
| Same-occurrence second count | Count advances, reward once | Two events/count2, one ledger grant | PASS |
| One-time reward | One lifetime occurrence | Later-day count, one reward | PASS |
| Duplicate profile | Conflict, no writes | Snapshot equality after failure | PASS |
| Duplicate occurrence | Conflict, no writes | Snapshot equality after failure | PASS |
| Duplicate ledger | Conflict, no writes | Snapshot equality after failure | PASS |
| Duplicate receipt/target | Conflict, no writes | Snapshot equality after failure | PASS |
| Missing target | Typed failure | No writes | PASS |
| Missing profile | Typed failure, no enrollment | No writes even for ineligible work | PASS |
| Frozen snapshot conflict | Preserve history | Priority/type/date/eligibility conflicts rejected | PASS |
| Different habits/common profile | Sum both rewards | Concurrent 82 XP/20 HC | PASS |
| DI | Shared actor, scoped container | Structural and two-container runtime tests | PASS |
| No hidden clock | Explicit normalized facts | Half-open supplied day, source checks | PASS |
| No live cutover | Current UI path unchanged | DI-driven live completion creates no new rows | PASS |
| Existing statistics/notifications/completion | No source/behavior changes | Protected source unchanged; all baseline regressions pass | PASS |

## 15. Production behavior verification

| Question | Answer |
|---|---|
| Did HabitService.completeHabit change? | NO |
| Did HabitListViewModel change? | NO |
| Did HabitModel completion change? | NO |
| Did HabitMapper change? | NO |
| Did statistics change? | NO |
| Did notifications change? | NO |
| Did current UI completion start writing gamification? | NO |
| Did schema change? | NO |

Only existing production files changed by Phase 3: AppDependencies (construction/exposure only) and HabitsRepositorySwiftData (new isolated operation; old CRUD bodies unchanged). Existing test changes: narrow Phase 2 source-guard update; user-owned test-label fix preserved. No entitlements, project settings, assets, UI, feature flags, old models or migration-plan edits.

Final audit ran git status --short, git diff, git diff --stat and git diff --check. Twenty protected files (including legacy/new persistence models, schemas, migration plan, completion, mapper, statistics, notifications, UI, project settings and entitlements) have no diff. A byte comparison confirms all existing repository code outside the inserted transaction block matches HEAD. All 13 Phase 3 added files were checked for whitespace issues; none were found. The unrelated AppAudit document and user-owned test-label fix are preserved.

## 16. Known blockers before live cutover

1. **Metadata edits/history overwrite:** current mapper/upsert can replace record arrays from stale drafts. This is an explicit blocker before live cutover; Phase 3 does not opportunistically refactor it.
2. **OccurrencePlanner/identity/calendar semantics:** not implemented. Commands must already be correct, including half-open legacy day intervals, one-time lifetime identity, eligibility and streak facts.
3. **Profile enrollment:** not implemented. No user is automatically enrolled; a single supplied-key profile must already exist. Storage/account/fallback policy needs definition.
4. **Reversal:** not implemented; no unused API methods added. Define count versus entitlement reversal semantics before enabling undo.
5. **Cloud duplicate reconciliation/authority:** not implemented. Local actor atomicity does not guarantee global uniqueness across independent offline devices or independent actor scopes. Imported duplicates are detected, not repaired.

Additional limits: V2 receipts do not hold a complete original command/result snapshot; retries return only durable receipt facts. Normalized identifier namespace/encoding belongs to future planning. Existing in-memory fallback is not durable rewards storage. Weekly review/duck/prediction remain outside scope.

## 17. Phase 4 readiness

**READY FOR PHASE 4 FOUNDATION WORK: YES. Phase 3: PASS.** The complete project/unit-test build succeeds, all 29 new transaction tests pass, and the full 112-test suite passes with every baseline case retained. One-save atomicity, real save failure, durable retries, conflict detection, overflow protection, shared-actor DI and no live cutover are proven within the documented local scope. No schema changes or unrelated repairs were needed.

**Ready to enable live rewards: NO.** Section 16 blockers must be resolved in the later authorized phase. Phase 4 has not started.
