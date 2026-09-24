# Gamification Phase 2 Report

## 1. Scope

Requested: versioned persistence foundation, five new storage entities, additive on-disk migration and persistence verification, with no live gamification. The pre-implementation audit found Phase 1 inconsistencies. The user explicitly approved repairing those first, then continuing Phase 2. The persistence foundation is complete and verified: **Phase 2 PASS** (September 23, 2026). No live integration or Phase 3 work is included.

## 2. Baseline

Commit: `7d55176abae6433a7557d37da8a2e7ad9006deb3`. Initial `git status --short` was empty (clean working tree).

Fresh command, run before any Phase 2 source edits:

```sh
xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
  -destination 'platform=iOS Simulator,id=24629C99-E950-4563-BA70-118CE5D96451' \
  -derivedDataPath /private/tmp/habithonker-phase2 \
  -only-testing:HabitHonkerTests
```

Result: build failed, exit 65. Tests executed **0**, passed **0**, test failures **0**, skipped **0**; the suite could not start. This is not a passing baseline. Log: `/private/tmp/habithonker-phase2-baseline.log`. Result bundle: `/private/tmp/habithonker-phase2/Logs/Test/Test-HabitHonker-2026.09.23_20-53-15--0700.xcresult`.

Compiler-reported blocker: `Core/Gamification/LevelCalculator.swift:42–44` initializes `LevelProgress` using `xpRequiredToNextLevel`, but `Core/Domain/GamificationModels.swift` declares `xpRequiredForCurrentLevel`.

Additional source-confirmed inconsistencies before implementation:

- `LevelCalculatorTests.swift:29,43` also accesses `xpRequiredToNextLevel`.
- `GamificationServiceTests.swift:67` supplies Bool `true` for the domain's `RewardEligibility` enum.
- The current domain comment and Phase 2 contract require one-time streak == 0, while RewardCalculator still accepts positive one-time streaks and RewardCalculatorTests explicitly tests that older behavior.
- The current breakdown type is `RewardCalculationBreakdown`, preserving the cleanup rename; the older Phase 1 report still calls it `RewardBreakdown`.

These are pre-existing at the clean commit, not caused by Phase 2. The user explicitly answered “Repair Phase 1, then continue Phase 2.” Repairs retain `xpRequiredForCurrentLevel`, `RewardEligibility`, and `RewardCalculationBreakdown`, enforce one-time streak == 0, and update affected tests without weakening the requested invariant.

**Fresh repaired baseline, still BEFORE Phase 2 source changes:** 70 executed / 70 passed / 0 failed / 0 skipped. Same command, log `/private/tmp/habithonker-phase2-repaired-baseline.log`, exit 0. All five named Phase 1 value types compile. This repaired baseline is the regression comparison point; it does not erase the original failed build.

## 3. Existing Persistence Inventory

Inventoried before schema work. Source root: `HabitHonker/HabitHonker/Repository/SwiftDataRepository/`. Exactly four deployed model classes; no VersionedSchema or SchemaMigrationPlan.

| Model | Existing persisted properties (type / default) |
|---|---|
| HabitSD | id UUID/UUID(); icon String?/nil; iconColorHex String?/nil; title String/empty; descriptionText String/empty; tags [String]/[]; priorityRaw Int/1; typeRaw Int/1; repeatingWeekdays [Int]/[]; dueDate Date/Date(); notificationActivated Bool/false; records [HabitRecordSD]? |
| HabitRecordSD | id UUID/UUID(); date Date/Date(); count Int/0; habit HabitSD?/nil; deletedHabit DeletedHabitSD?/nil |
| DeletedHabitSD | id UUID/UUID(); icon String?/nil; iconColorHex String/empty; title String/empty; descriptionText String/empty; tags [String]/[]; priorityRaw Int/0; typeRaw Int/1; repeatingWeekdays [Int]/[]; dueDate Date/Date(); notificationActivated Bool/false; deletedAt Date/Date(); records [HabitRecordSD]? |
| StatisticsPresetSD | id UUID/UUID(); name String/empty; isActive Bool/false; habitIDs [UUID]/[] |

Relationships: HabitSD.records has cascade deletion; HabitRecordSD.habit nullifies with inverse HabitSD.records. DeletedHabitSD.records nullifies; HabitRecordSD.deletedHabit nullifies with inverse DeletedHabitSD.records. StatisticsPresetSD uses scalar habit UUID references, no relationships. No unique attributes are present in the four models. Existing defaults, including wall-clock defaults, must remain intact in V1.

Weekdays are persisted as [Int], with Sunday=1 through Saturday=7. The domain uses a Set of the same weekday raw values. `dueDate` also supplies repeating reminder time, not a known historical activation date. Old rows do not capture historic schedule/priority/eligibility facts.

`App/HabitHonkerApp.swift` owns `Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self])` and container reconstruction:

- Cloud selection: `sync.isOn && sync.iCloudAvailable`; named configuration **Cloud**, schema nil, on-disk, allowsSave true, groupContainer automatic, `.private("iCloud.com.flyingwhale.habithonker")`.
- Local/default branch: `ModelContainer(for: schema)` with implicit configuration; it does **not** explicitly disable CloudKit.
- Failure fallback: named **FallbackInMemory**, schema supplied, in-memory, allowsSave true. Current `try?` failures are swallowed; this is an existing risk, not a newly introduced destructive migration/reset. The fallback does not remove the on-disk store.
- Before rebuilding, container and coordinator are released, followed by Task.yield; resulting dependencies are built only after a container exists.
- No explicit store URLs are supplied. Exact device/sandbox URLs are runtime-dependent. The configuration test verifies V1/V2 URL equality for both default and named Cloud configurations. It prints the runtime paths, but this simulator result bundle provides no exportable console log, so no exact sandbox prefix is asserted in this report. Preserve configuration names/defaults rather than inventing a new URL or assuming local/cloud share one store.
- Entitlements declare the same private iCloud identifier and CloudKit service; no entitlement/server changes are authorized.

`HabitsRepositorySwiftData.makeContext()` creates a fresh context per operation, disables autosave, and mutating operations explicitly call `ctx.save()`. Save/upsert map current HabitModel fields and records. Delete copies an archive then deletes the active entity in the same context/save. Statistics presets keep scalar selection IDs. No future behavior/reward storage is involved.

## 4. Versioned Schema

`HabitHonkerSchemaV1`, version **1.0.0**, enumerates exactly HabitSD, HabitRecordSD, DeletedHabitSD, StatisticsPresetSD. Their source files are unchanged, preserving entity names, scalar fields and inverse/delete rules. `HabitHonkerSchemaV2`, version **2.0.0**, includes those same types plus the five new Phase 2 models. `HabitHonkerMigrationPlan` declares one **lightweight V1 → V2** stage, with no callbacks or data backfill.

The current unchanged legacy definitions are shared by both versions for this additive step. These definitions must now be treated as frozen historical schema: a later change to their persisted fields requires separate historical definitions and another tested schema version. No renaming/typealias restructuring was necessary here.

The new rows have their own `schemaVersion = 1` payload version; it is distinct from container schema version 2. All new string enum/source/provenance payloads are interpreted within that row version. Task and eligibility strings reuse the current Phase 1 raw values; priority integers reuse BehaviorPriority's 0…3 mapping. No logical key is generated by these models.

## 5. New Persistent Models

Every new model has a structural UUID `id` identifying its physical row. Business/logical keys are supplied explicitly to initializers and have no unique constraint. Required stored fields have safe structural defaults for SwiftData/CloudKit; constructors require logical IDs, target UUIDs, required raw categories and business timestamps. Epoch timestamp/zero UUID/empty-string storage defaults are not event/enrollment generation. Optional historical facts stay nil. None of the five models has a relationship, so none cascades on habit deletion.

### TaskOccurrenceSD

Historical occurrence state; no XP, coins or level.

| Fields | Purpose |
|---|---|
| id UUID | Physical row identity |
| logicalOccurrenceID String | Caller-supplied logical occurrence key |
| targetID UUID | Scalar BehaviorTargetID-compatible reference; active HabitSD not required |
| scheduledLocalDateKey String?, scheduledAt Date?, dueAt Date? | Known civil date and planned start/deadline instants |
| schedulingTimeZoneIdentifier String?, schedulingCalendarIdentifier String? | Historical scheduling interpretation |
| taskTypeRawValue String, statusRawValue String | Frozen task category and occurrence state, versioned by schemaVersion |
| completedAt Date?, completionCount Int (0) | Completion state/count, independent of reward grants |
| scheduleRevisionID String? | Scalar historical revision link |
| priorityRawValue Int?, iconName String?, notificationEnabled Bool? | Only required frozen metadata; nil distinguishes unknown from false |
| streakBefore Int?, streakAfter Int?, rewardEligibilityRawValue String? | Supplied future reward-planning facts, no inference |
| legacyRecordID UUID? | Optional old record link |
| provenanceRawValue String | Supplied evidence quality/origin |
| predecessorOrAliasOccurrenceID String? | Optional explicit identity-conversion link |
| schemaVersion Int (1) | Row interpretation version |

### BehaviorScheduleRevisionSD

Historical schedule metadata, separate from current HabitSD and occurrence state.

| Fields | Purpose |
|---|---|
| id UUID, logicalRevisionID String, targetID UUID | Physical identity, logical revision identity, scalar target reference |
| effectiveFrom Date, effectiveTo Date? | Caller-supplied validity interval |
| taskTypeRawValue String | Frozen repeating/one-time category |
| selectedWeekdaysMask Int (0) | Seven-bit scalar representation: bit 0 Sunday/raw 1 through bit 6 Saturday/raw 7; 42 means Monday/Wednesday/Friday |
| scheduledHour Int?, scheduledMinute Int?, dueAt Date? | Repeating civil clock components and/or one-time deadline |
| schedulingTimeZoneIdentifier String?, schedulingCalendarIdentifier String? | Historical time policy |
| priorityRawValue Int?, iconName String?, notificationEnabled Bool? | Frozen metadata affecting interpretation |
| schemaVersion Int (1) | Row interpretation version |

The existing models keep their [Int] weekday storage unchanged. The new revision uses a scalar bitmask to avoid a new transformable collection, eliminate ordering ambiguity, and retain the existing Sunday=1 semantics. This is representation only; no planner or live revision writer is added.

### BehaviorEventSD

Durable normalized transitions/command receipts, not HabitEventCenter.

| Fields | Purpose |
|---|---|
| id UUID, transitionID String | Physical row versus stable logical transition identity |
| commandID String?, targetID UUID, occurrenceID String? | Command receipt and scalar behavior/occurrence references |
| timestamp Date | Explicit business transition instant |
| kindRawValue String, completionCount Int? | V1 uses completed/archived/deleted, matching BehaviorEventKind; count preserves completed(count:) payload |
| predecessorTransitionID String? | Causal transition link |
| sourceRawValue String, provenanceRawValue String? | Supplied source/evidence quality; no inference |
| schemaVersion Int (1) | Row interpretation version |

No competing event vocabulary or new live publisher is introduced. Strings preserve unknown future values without an opaque enum archive; validation/command semantics belong to later operations.

### GamificationProfileSD

Rebuildable aggregate/cache, not the authoritative ledger.

| Fields | Purpose |
|---|---|
| id UUID, logicalProfileKey String | Physical identity versus caller-supplied profile identity |
| totalXP Int (0) | Net progression XP; level/progress are not stored |
| honkerCoins Int (0), lifetimeCoinsEarned Int (0), lifetimeCoinsSpent Int (0) | Balance and lifetime aggregate counters |
| trackingStartedAt Date? | Explicit future enrollment instant; remains nil by default |
| schedulingTimeZoneIdentifier String?, schedulingCalendarIdentifier String? | Future enrolled scheduling policy |
| lastProcessedWeekKey String? | Future optimization hint only |
| aggregateFingerprint String? | Future projection provenance/checkpoint |
| schemaVersion Int (1), updatedAt Date? | Payload version and supplied projection timestamp |

No profile instance is constructed automatically anywhere in production.

### GamificationLedgerEntrySD

Append-only audit storage with `private(set)` persisted fields: constructors accept supplied facts; application callers cannot mutate those properties. There is no update method. SwiftData contexts can still delete rows or mutate backing data, so this is an application access boundary, not a tamper-proof database or reconciliation guarantee.

| Fields | Purpose |
|---|---|
| id UUID, logicalKey String | Physical row versus logical grant/compensation key |
| profileKey String, targetID UUID, occurrenceID String, transitionID String? | Scalar audit references; no active task/profile object required |
| xpDelta Int (0), coinDelta Int (0) | Signed historical amounts, stored exactly without recalculation |
| reasonRawValue String | Supplied entry reason, interpreted with row version |
| predecessorLogicalKey String? | Exact original/predecessor linkage for compensation |
| createdAt Date, schemaVersion Int (1), policyVersion Int | Explicit business instant, payload version, reward policy version |
| taskTypeRawValue String?, priorityRawValue Int?, streakAfterCompletion Int?, isOnTime Bool?, rewardEligibilityRawValue String? | Frozen Phase 1 input basis |
| baseXP Int?, baseCoins Int?, multiplierScale Int?, priorityMultiplier Int?, streakMultiplier Int?, timingMultiplier Int?, priorityCoinBonus Int?, streakCoinBonus Int? | Explicit scalar RewardCalculationBreakdown snapshot |

Original grant fixtures preserve all input/breakdown fields. Linked compensation fixtures omit snapshots and retain signed deltas plus the predecessor key; they do not fabricate new calculations. No reward writer, reversal operation or calculator call exists in persistence.

## 6. Existing Files Modified

All paths below are relative to the repository.

| File / symbol | Exact reason and behavior impact |
|---|---|
| HabitHonker/HabitHonker/App/HabitHonkerApp.swift — schema, rebuildContainerIfNeeded | Use V2 schema and migration plan in cloud/default/fallback constructors. Configuration names, URLs/defaults, cloud identifier, fallback and rebuild logic unchanged. |
| HabitHonker/HabitHonker/Core/Gamification/LevelCalculator.swift — progress | User-approved prerequisite repair: initializer label matches existing LevelProgress field. No arithmetic change. |
| HabitHonker/HabitHonker/Core/Gamification/RewardCalculator.swift — reward | User-approved prerequisite repair: reject nonzero one-time streak as required by current domain comment/Phase 2 contract. No live caller exists. |
| HabitHonker/HabitHonkerTests/LevelCalculatorTests.swift | Use the current domain property name in two assertions. |
| HabitHonker/HabitHonkerTests/GamificationServiceTests.swift | Supply .eligible rather than Bool true. |
| HabitHonker/HabitHonkerTests/RewardCalculatorTests.swift | Strengthen one-time validation coverage for eligible/ineligible inputs; supply 0 by default for one-time fixtures and 1 for repeating. Replaces the explicitly outdated permissive test. |

No legacy persisted model, mapper, repository, completion service/view-model, statistics, notification, DI, feature flag, entitlement, asset or project setting changed. The earlier Phase 1 report is retained as historical documentation; its stale names/permissive one-time wording are identified in section 2 rather than silently rewriting that record.

## 7. New Files

| Path | Responsibility |
|---|---|
| HabitHonker/HabitHonker/Repository/SwiftDataRepository/HabitSchemaMigration.swift | V1/V2 schemas and additive migration plan |
| HabitHonker/HabitHonker/Repository/SwiftDataRepository/BehaviorSD.swift | Occurrence, schedule revision, normalized event storage |
| HabitHonker/HabitHonker/Repository/SwiftDataRepository/GamificationSD.swift | Profile and append-only ledger storage |
| HabitHonker/HabitHonkerTests/GamificationMigrationTests.swift | Schema metadata, on-disk legacy migration and local cloud-equivalent construction checks; shared test-store fixtures |
| HabitHonker/HabitHonkerTests/GamificationPersistenceTests.swift | Full scalar round trips, nils, duplicate keys, deletion independence, live-completion/source boundaries |
| Docs/GamificationPhase2Report.md | This implementation/evidence report |

Synchronized groups register files without project edits. No empty repository/service abstractions are added.

## 8. Migration Strategy

An existing four-model store is matched to V1, then SwiftData's lightweight stage adds the five entities. The four original definitions are unchanged. Tests explicitly distinguish deployed **unversioned** Schema construction from explicit versioned V1 creation, reopening the same physical file under V2 plus the plan. Containers/contexts are released in autoreleasepool scopes before reopening.

There are no will/did-migrate callbacks, inserts, backfill, calendar inference, enrollment, balances or awards. New tables must be empty after migration and remain empty on a second V2 reopen. Production configuration names/defaults are preserved; no store deletion or new persistent fallback is introduced. The existing in-memory fallback remains a documented failure-visibility risk.

## 9. Migration Test

Both on-disk fixtures contain:

- Repeating habit UUID suffix 1, icon biceps-flexed, color #123456, title Repeating, description Legacy repeat, tags a/b, priority 2, repeating type 1, weekdays [2,4,6], due timestamp 1800000001, notifications true. Two records UUID suffixes 11/12, dates 1800000002/3, counts 3/2.
- One-time habit UUID suffix 2, nil icon/color, title One time, description Legacy due, no tags/weekdays, priority 0, due-date type 0, due timestamp 1800000004, notifications false. Record UUID suffix 13/date 1800000005/count 1.
- Archive UUID suffix 3, icon bed, color #ABCDEF, title Archived, description Legacy archive, tag rest, priority 3, repeating type 1, weekdays [1,7], due timestamp 1800000006, notifications true, deletedAt 1800000007. Record UUID suffix 14/date 1800000008/count 4.
- Statistics preset UUID suffix 4, name My statistics, active true, ordered IDs of both active habits and the archive.

All UUIDs use fixed `00000000-0000-0000-0000-` prefixes with 12-digit suffixes. Snapshots compare every legacy scalar listed in the inventory, sorted record relationship UUIDs, both record inverse identities, and preset ID order. Counts after upgrade must be 2 active habits / 4 records / 1 archive / 1 preset. Every new collection must be empty. Each migrated store is reopened a second time to check durable preservation and absence of repeated migration side effects.

PASS in the targeted Phase 2 run and again in the final full suite.

## 10. CloudKit Compatibility

New logical keys have no unique constraints. Schema tests inspect all nine entities for uniqueness and optional/default attribute requirements; all five new entities must have zero relationships. New UUID defaults are structural physical identifiers or fixed zero target sentinels; logical key constructors require explicit values. Required business timestamps have epoch schema defaults and explicit initializer arguments; no Date() is used in new persistence. Optional metadata preserves unknown values.

The production private identifier remains `iCloud.com.flyingwhale.habithonker`. Tests inspect the original cloud configuration shape and compare default/named configuration URLs before/after versioning. They construct the full V2 model set plus migration plan using an on-disk **Cloud** configuration with `.none` and an isolated temporary URL: the local equivalent, without network/account requirements.

A real private CloudKit-backed container/import/export/server schema is not validated in this task. It would involve account/entitlement/service state and potentially network synchronization; no CloudKit server deployment or entitlement change is performed. Metadata/local-store checks do not prove multi-device delivery or global uniqueness.

## 11. Persistence Round-Trip Tests

Five model-specific tests create populated and nil/default rows in isolated on-disk V2 stores, release the original containers and fetch using fresh containers. Each snapshot's property-name set is checked against schema attributes, so every stored scalar is included in the equality assertion, including physical/logical IDs, versions and optional values.

The ledger original grant preserves repeating, important/not urgent, streak 7, on-time true, eligible, policy 1, base 25/3, scale 100, multipliers 130/115/110, bonuses 2/5, final 41 XP/10 HC. A linked -41/-10 compensation row has nil calculation fields. Persistence code does not call RewardCalculator.

Additional tests prove scalar history can exist without any HabitSD and survive insertion/deletion of its referenced habit; duplicate logical keys produce two physical rows for each new entity; normal HabitService completion twice persists count 2 and creates zero new rows; source guards prevent live integration or prohibited dependencies.

PASS in the targeted Phase 2 run and again in the final full suite.

## 12. Full Test Results

Original checkout: build failed before test execution (section 2). Approved prerequisite repairs: **70/70 passed, 0 failed/skipped** before Phase 2 source changes.

| Verification | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| Original checkout | 0 | 0 | 0 test failures; build failed | 0 |
| Approved repaired baseline, before Phase 2 | 70 | 70 | 0 | 0 |
| New Phase 2 tests | 13 | 13 | 0 | 0 |
| Final full HabitHonkerTests target | 83 | 83 | 0 | 0 |

Targeted and full runs exited 0 with TEST SUCCEEDED. Comparing passed test identities confirms all 70 repaired-baseline cases passed again, plus 13 new cases. No Phase-2-caused regressions; no unrelated test expectations weakened. This is the complete unit-test target, not a separate UI-test suite or a multi-device cloud test.

Commands use the baseline project/scheme/destination/derived-data flags; targeted run selects `HabitHonkerTests/GamificationMigrationTests` and `HabitHonkerTests/GamificationPersistenceTests`. Logs are `/private/tmp/habithonker-phase2-new.log` and `/private/tmp/habithonker-phase2-final.log`.

The first new-test build exposed a Swift compiler crash lowering a metatype key-path map in the schema test. Replacing it with the equivalent explicit closure resolved compilation without changing production settings or assertions.

## 13. Expected vs Actual

| Requirement | Expected | Actual | Status |
|---|---|---|---|
| Existing Habit data preserved | Exact preservation | Both unversioned and V1 on-disk fixtures preserve all fields/relationships | PASS |
| Existing completion behavior | Unchanged | Existing tests plus two real V2 completion calls; count 2, new tables empty | PASS |
| Existing statistics | Unchanged | Presets/record history preserved, existing statistics tests pass | PASS |
| Existing notifications | Unchanged | Source untouched, characterization/regression tests pass | PASS |
| Phase 1 reward behavior | Current final contract | Approved repairs made first; repaired baseline and final tests pass | PASS |
| Versioned schema | V1 + V2 with plan | Versions 1.0.0 / 2.0.0, exact 4/9 model sets | PASS |
| V1 → V2 migration | Proven on disk | Lightweight upgrade and repeated V2 reopen pass | PASS |
| TaskOccurrence persistence | All scalars survive | Populated + unknown/nil fixture round-trip | PASS |
| ScheduleRevision persistence | Deterministic historical storage | Mask/clock/deadline/metadata round-trip | PASS |
| BehaviorEvent persistence | Durable normalized transitions | completed(count)/archived/deleted storage round-trip | PASS |
| Profile persistence | Rebuildable cache, optional enrollment | Populated + unenrolled defaults round-trip | PASS |
| Ledger persistence | Frozen audit and scalar linkage | Grant/compensation round-trip; independent of habit deletion | PASS |
| Retroactive XP | NO | NO | PASS |
| Live XP integration | NO | NO | PASS |
| Live completion integration | NO | NO | PASS |
| Weekly snapshot implementation | NOT IMPLEMENTED BY DESIGN | NOT IMPLEMENTED BY DESIGN | PASS |

## 14. Production Behavior Verification

| Question | Answer |
|---|---|
| Did HabitService.completeHabit change? | NO |
| Did HabitListViewModel completion flow change? | NO |
| Did HabitModel completion semantics change? | NO |
| Did HabitMapper behavior change? | NO |
| Did HabitRepositoryProtocol change? | NO |
| Did repository completion writes change? | NO |
| Did statistics behavior change? | NO |
| Did notification behavior change? | NO |
| Did AppDependencies change? | NO |
| Was GamificationService connected to production flow? | NO |
| Are any gamification rows automatically created? | NO |

Final audit ran `git status --short`, `git diff`, `git diff --stat` and `git diff --check`, reviewed all new files, and checked the explicitly protected paths against HEAD. Only the six listed existing files differ, plus the six new files. No whitespace errors were found. Production reference search finds new entities only in their definitions and schema registration; GamificationService remains confined to its existing pure implementation/protocol.

App changes are only schema/plan registration. Prerequisite Phase 1 repairs affect the otherwise unused pure domain, explicitly approved by the user. No UI or user-action meaning changes. No Phase 3 implementation.

## 15. Risks / Limitations

- The existing try?/in-memory fallback can mask persistent-container failure and show a temporary empty session. It is unchanged, does not delete the old file, and is not a durable gamification store. No destructive recovery/fresh persistent replacement is introduced.
- Default/local and named Cloud stores are not assumed identical or merged; existing selection semantics remain unchanged.
- Local migration and metadata validation do not establish real CloudKit server compatibility/delivery. Deployment and two-device/account tests remain external release verification.
- Shared historical legacy definitions must not be edited in a future schema revision without preserving the old version definitions.
- Logical duplicate rows are intentionally permitted; future deduplication/transactions and authoritative profile rebuilding are deferred. No claim of global exactly-once awards.
- Ledger private setters prevent normal application edits but cannot prevent a future context from deleting data. Full append-only write/reconciliation enforcement belongs to the future operation boundary.
- Occurrence identity generation, validation/planning, enrollment, transactions, reconciliation, reward reversal/restoration operations and weekly snapshots are intentionally deferred, not defects. In particular WeeklyGamificationSnapshotSD is omitted until finality/late-sync semantics are settled.

## 16. Phase 3 Readiness

**READY FOR PHASE 3: YES.** V2 schema metadata/local-equivalent construction pass; both mandatory migration paths preserve old data on disk; all five storage entities round-trip; new tables stay empty during migration and real completion; all 83 tests pass with every repaired-baseline case retained. No live gamification or Phase 3 implementation has started.

The approved Phase 1 prerequisite repairs are the only expansion beyond the original persistence-only scope. Existing live behavior remains unchanged. Phase 3 can define operation/transaction contracts against this storage; it must still address the explicitly deferred authority, idempotency and enrollment semantics before enabling awards.
