# Gamification Transaction Contract

## Purpose

Provide an isolated, local atomic completion operation for an already-normalized command. This is the Phase 3 foundation; the running app's HabitService completion path does not call it. Constructing the dependency graph does not enroll a profile or write reward data.

## Responsibility boundaries

- **BehaviorTransactionService:** accepts a domain command and forwards it to one injected repository protocol; returns its result/error. No storage, scheduling, clock or UI work.
- **BehaviorTransactionRepositoryProtocol:** exposes only asynchronous `complete`; inputs/results/errors contain no SwiftData objects.
- **SwiftDataBehaviorTransactionRepository:** forwards to the same HabitsRepositorySwiftData actor used by the existing habit adapter. Holds the injected pure gamification dependency through a synchronous helper.
- **HabitsRepositorySwiftData:** creates the operation's context, disables autosave, serializes the entire operation, owns the sole save and rollback/error mapping.
- **BehaviorTransactionSD:** synchronous query/validation/calculation/mutation helper using the supplied actor-owned context. Creates no context/container, never saves, never awaits. It must only be invoked through the actor operation in production.
- **GamificationServiceProtocol:** calculates the reward and resulting level synchronously. The transaction copies the returned frozen reward basis; it contains no reward formula.
- **Future OccurrencePlanner:** must supply correct occurrence IDs, frozen facts, eligibility, streaks, scheduling policy, explicit timestamps and legacy local-day boundaries. Phase 3 does not infer these from the current habit or the device clock.

## Dependency graph

```text
AppDependencies.make(container)
  ├─ shared HabitsRepositorySwiftData(container)
  │    ├─ SwiftDataHabitRepository → existing HabitService (unchanged live path)
  │    └─ SwiftDataBehaviorTransactionRepository
  │          ↑ injected GamificationService(RewardCalculator, LevelCalculator)
  │          ↑ BehaviorTransactionService → exposed protocol, no live consumer
  └─ each rebuild receives its own container-scoped graph

BehaviorTransactionService.complete(command)
  → BehaviorTransactionRepositoryProtocol
  → adapter → shared actor.completeBehavior
  → one context → synchronous BehaviorTransactionSD.apply
  → one save for an applied command → domain result
```

## Atomicity invariant

**Habit compatibility projection + occurrence + behavior event + optional ledger grant + optional profile update commit together or not at all.**

`HabitsRepositorySwiftData.executeBehavior` calls `makeContext()` once (autosave false), calls the helper synchronously, and calls `context.save()` exactly once for `.applied`. It returns success only after save succeeds. A duplicate command does not mutate or save. Any thrown error invokes `context.rollback()` before returning a typed error. The context is not retained for subsequent operations.

This is one local store transaction under one shared actor. Separate actors/processes or CloudKit imports are not globally serialized by this guarantee. Multiple independently created container scopes must not be treated as a distributed lock.

## Identity model

| Identity | Meaning |
|---|---|
| Physical row UUID | SwiftData row's stored identity; distinct from business deduplication. Random physical IDs are allowed. |
| commandID | Caller-assigned delivery/retry identity, searched in durable BehaviorEventSD.commandID. |
| transitionID | Caller-assigned stable accepted-transition identity; reuse by another command is rejected. |
| occurrenceID | Supplied logical behavior occurrence; the transaction never generates it. One-time callers must use one lifetime identity. |
| profileKey | Explicit logical enrolled profile reference. No default profile is created. |
| Initial reward key | Exactly `reward:v1:<profileKey>:<occurrenceID>:initial`; policy version is payload, never a new entitlement namespace. |

Logical key strings are caller-owned normalized identifiers. The transaction verifies nonempty identities and stored references; it does not parse, generate, canonicalize or globally reconcile them. Future planners must define their canonical encoding.

## Idempotency rules

1. **Same command:** zero receipts means new; one compatible receipt returns `.duplicateCommand` with immutable stored receipt facts; multiple receipts produce a conflict. Reused transition IDs or mismatching durable receipt identity/time/source fields fail safely. Retry performs no save and no reward/level calculation.
2. **Same occurrence, new command:** increments the supplied legacy day's count and occurrence count and writes a new event. It does not change the occurrence's first-completion snapshot. Exactly one existing initial ledger grant suppresses any new award, even when the caller's policy version changes.
3. **Ineligible completion:** behavior evidence is persisted but no ledger entry (including no misleading zero grant) is inserted and profile fields remain unchanged. A profile must still exist so missing enrollment cannot partially commit behavior.
4. **Duplicates:** for new commands, multiple matching targets, profiles, occurrences or ledger rows cause typed errors. No arbitrary first-row choice, summation or reconciliation occurs. Fetch limit two is enough to detect ambiguity.
5. **Repeat replies:** a retry returns the original immutable receipt/count, not a reconstructed historical account balance. Other commands may have changed the current balance since the first delivery.

A valid receipt takes precedence over loading current target/profile/occurrence state: replaying an accepted command remains a no-op, even after later unrelated state changes. V2 receipts do not archive the entire original command or profile key. The command ID is authoritative for retries; fields absent from that receipt are not a full-payload equality guarantee. No new work is applied for any recognized retry. Introducing full payload hashes is not part of Phase 3 and would need a separately reviewed persistence contract.

## Frozen historical facts

The reward input comes entirely from `command.rewardInput`. The habit's current priority/type/schedule/icon are not used for reward calculation. Tests intentionally make mutable habit metadata disagree with the frozen command.

Stored occurrence target/type/priority, scheduled date/start/deadline, calendar/timezone, revision, icon/reminder snapshot, streaks, eligibility, provenance and alias must agree with a subsequent new command for that occurrence. A mismatch returns `conflictingOccurrenceSnapshot`. Unknown/nil facts are not silently filled from the current habit.

The supported existing occurrence states are a fully matching scheduled row (zero count/no completion time) or completed row (positive count/completion time). Other states fail safely. The first completedAt and first legacyRecordID remain frozen; later counts on other days can have different compatibility records. `isOnTime` and policyVersion are original grant facts in the ledger, not fields on V2 occurrences; existing grants are never repriced.

## Legacy day projection

The caller supplies `legacyCompletionDate` and a `DateInterval` representing the local day. Comparison is explicitly half-open: `start <= record.date < end`. The supplied completion timestamp must lie inside it. No Calendar.current, TimeZone.current or Date() participates in transaction business logic.

One matching record increments with checked arithmetic and retains its UUID/date. Zero matches inserts a record at the supplied timestamp. More than one match fails rather than merging uncertain legacy data. A known occurrence legacy link must still exist among the target's records. The caller is responsible for truthful day boundaries, including DST; this layer does not invent scheduling policy.

## Profile semantics

The profile is a rebuildable cache/projection; ledger rows are frozen reward history. A new positive/zero nonnegative eligible calculator result is copied exactly to a new initial grant, and its XP/coins are added with checked arithmetic. Lifetime coins earned increases by nonnegative granted coins; lifetime spent and enrollment policy remain untouched. updatedAt uses the command's completedAt. An old aggregateFingerprint is cleared because it no longer describes the projection.

Level is derived through the injected pure service and is not persisted. Calculator/range errors abort the whole operation. Existing grants and ineligible commands do not update the profile, including updatedAt. Phase 3 neither automatically enrolls nor rebuilds/reconciles profiles; existence of exactly one supplied-key row is its enrollment prerequisite.

## Failure semantics

No partial success result is returned. Domain errors distinguish missing target/profile, duplicate logical identities, conflicting receipts/transitions/snapshots, invalid normalized commands, inconsistent stored state and overflow. GamificationCalculationError is preserved inside calculationFailure. Unexpected storage/hook errors are converted to persistenceFailure retaining NSError domain, code and localized description, rather than exposing SwiftData objects or suppressing the failure.

Tests throw after all entities have been staged and also exercise save on a read-only on-disk store. A DEBUG-only test entry point accepts a synchronous non-escaping pre-save hook; release builds omit that entry point. The production path supplies a no-op hook and uses the identical save/rollback owner.

## Container scope / DI

AppDependencies.make(container:) constructs one existing repository actor. Both habit and transaction adapters share that exact actor. The transaction service is exposed as BehaviorTransactionServiceProtocol. No singleton retains a previous container; rebuilding dependencies scopes them to the new supplied container. RootTabsView/HabitService do not consume the new service yet.

## Current limitations

No live cutover, occurrence planner/key generation, automatic enrollment, reversal/restoration, cloud duplicate reconciliation, weekly review/snapshot, UI, duck state or prediction changes. V2 models/migration remain unchanged. Local atomicity does not establish globally exclusive offline multi-device rewards. Source guards complement tests; they are not a formal proof or a distributed concurrency test.

## Preconditions before Phase 4 live integration

- Resolve metadata-edit/history overwrite risk: current HabitMapper/upsert paths can replace records from stale drafts. This is a **blocker before live cutover**, deliberately not repaired in Phase 3.
- Implement and validate OccurrencePlanner/identity/calendar/timezone/legacy-day semantics, including one-time lifetime identity and off-schedule actions.
- Define explicit profile enrollment, trackingStartedAt, storage/account scope and safe behavior under the existing in-memory fallback.
- Define reversal semantics and implement the required operation before promising undo consistency.
- Define cloud duplicate reconciliation/authority and projection rebuilding; detect conflicts safely until then.
- Define product/error handling for conflicts and failed completion; connect HabitService only in the later authorized cutover phase.
- Preserve existing statistics/notification behavior and rerun the complete regression suite at cutover.
