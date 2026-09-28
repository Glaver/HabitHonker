> **SUPERSEDED by HabitHonker Exp v1.1.2.** Use `Docs/HabitHonkerExp-v1.1.2.md` (architecture/ADRs) and `Docs/HabitHonkerExp-v1.1.2-Claude-Phase4.md` (execution prompt). Where this file differs, v1.1.2 wins.

# HabitHonker Exp v1.1.1
## Architecture & Behavior Foundation Contract

**Status:** architecture revision approved; no Phase 4 production implementation has been executed by this document.

**Purpose:** freeze the HabitHonker Exp v1.1.1 engineering model after review of Phases 1–3 and the Phase 4 audit, including the approved multi-device, reconciliation, timing, and local-storage decisions.

---

# 1. Current system status

## Phase 1 — Gamification Math
**Status: COMPLETE / FROZEN**

Implemented responsibilities:

- `GamificationPolicy`
- `RewardCalculator`
- `LevelCalculator`
- `GamificationService`
- XP calculation
- HonkerCoin calculation
- priority multipliers
- streak multipliers
- streak milestone coin bonuses
- timing bonus
- cumulative level curve
- deterministic rounding
- protocol-based pure domain boundaries

Phase 1 owns gameplay arithmetic only.

It does not own persistence, scheduling interpretation, CloudKit reconciliation, UI, or task mutation.

### V1 reward balance

Repeating occurrence:

- Base XP: `25`
- Base HonkerCoins: `3`

One-time occurrence:

- Base XP: `40`
- Base HonkerCoins: `5`

Priority XP:

- Important / Not Urgent: `×1.30`
- Important / Urgent: `×1.20`
- Not Important / Urgent: `×1.10`
- Not Important / Not Urgent: `×1.00`

Priority coin bonuses:

- Important / Not Urgent: `+2 HC`
- Important / Urgent: `+1 HC`
- other priorities: `+0 HC`

Repeating streak XP:

- 1: `×1.00`
- 2–3: `×1.05`
- 4–6: `×1.10`
- 7–13: `×1.15`
- 14–29: `×1.20`
- 30+: `×1.25`

Streak coin milestones:

- 3: `+2 HC`
- 7: `+5 HC`
- 14: `+8 HC`
- 30: `+15 HC`
- 60: `+25 HC`
- 100: `+50 HC`

Timing bonus:

- completed by the explicit planning deadline timestamp: `×1.10`
- completed after the timestamp: `×1.00`
- no penalty is ever applied for lateness
- no XP or coins are subtracted merely because work was completed late

The `×1.10` timing multiplier remains the V1 balance.

A proposed `×1.25` timing multiplier is intentionally NOT adopted in v1.1.1 because it would make timing as powerful as the maximum streak multiplier and materially overweight punctuality relative to the existing priority/streak economy.

Examples:

Maximum repeating XP multiplier under v1.1.1:

`1.30 priority × 1.25 streak × 1.10 timing = 1.7875`

This keeps timing meaningful but secondary to sustained behavior.

---

## Phase 2 — Versioned Persistence
**Status: COMPLETE / FROZEN**

Existing V2 gamification/behavior persistence:

- `TaskOccurrenceSD`
- `BehaviorScheduleRevisionSD`
- `BehaviorEventSD`
- `GamificationProfileSD`
- `GamificationLedgerEntrySD`

Legacy compatibility remains:

- `HabitSD`
- `HabitRecordSD`
- `DeletedHabitSD`
- `StatisticsPresetSD`

Existing migration path:

`V1 -> V2`

Phase 4 must not create Schema V3.

---

## Phase 3 — Atomic Behavior Transaction
**Status: COMPLETE / FROZEN, with one approved Phase 4G compatibility extension described later**

Current conceptual path:

```text
BehaviorCompletionCommand
        ↓
BehaviorTransactionServiceProtocol
        ↓
BehaviorTransactionService
        ↓
BehaviorTransactionRepositoryProtocol
        ↓
SwiftDataBehaviorTransactionRepository
        ↓
shared HabitsRepositorySwiftData actor
        ↓
ONE ModelContext
        ↓
ONE save()
```

Atomic bundle:

```text
HabitRecord compatibility projection
+
TaskOccurrenceSD
+
BehaviorEventSD
+
optional GamificationLedgerEntrySD
+
optional GamificationProfileSD update
```

Guarantees:

- local atomicity
- rollback
- durable command receipts
- occurrence idempotency
- initial reward entitlement idempotency
- frozen reward inputs
- checked arithmetic
- shared actor serialization
- protocol-based DI

Phase 3 still does NOT:

- generate occurrence identity
- determine schedule semantics
- enroll a gamification profile
- reconcile CloudKit duplicates
- route current `HabitService.completeHabit` through gamification

---

# 2. HabitHonker Exp v1.1.1 core responsibility model

```text
HabitSD
    mutable current task definition

BehaviorScheduleRevisionSD
    historical schedule/planning definition

TaskOccurrenceSD
    logical occurrence history

BehaviorEventSD
    durable transition / command evidence

GamificationLedgerEntrySD
    append-only reward history

GamificationProfileSD
    rebuildable balance projection/cache
```

Rules:

- Habit/task state is NOT rebuilt by replaying events.
- Gamification ledger is append-only reward evidence.
- Profile is a cache, not financial truth.
- Occurrence and schedule history preserve historical meaning.
- UI does not own reward/scheduling logic.
- Prediction never derives truth from duck/UI state.
- Persistent logical identity is never based on Swift `Hasher`.

---

# 3. Approved Architecture Decision Records

## ADR 4.1 — Multi-device enrollment: Hybrid B+C

### Problem

Two devices may independently enroll the same CloudKit-backed store before sync.

Example:

```text
Device A:
profile:v1:default
trackingStartedAt = 10:00

Device B:
profile:v1:default
trackingStartedAt = 10:07
```

Both represent the same logical gamification profile but have separate physical rows.

### Decision

Use both:

1. **earliest enrollment wins for enrollment metadata**
2. **deterministic baseline revision identities**

Canonical tracking boundary:

```text
canonicalTrackingStartedAt =
earliest valid trackingStartedAt
among compatible physical profile rows
```

Canonical scheduling timezone/calendar:

- taken from the physical enrollment row that owns the earliest valid enrollment instant
- V1 calendar must be Gregorian
- if multiple earliest rows have the exact same earliest instant but incompatible timezone/calendar metadata, the profile group is a conflict

This earliest-wins rule is an explicit exception for enrollment metadata only.

It does NOT apply to:

- XP
- coins
- conflicting reward payloads
- conflicting occurrence planning data
- general CloudKit conflicts

### Baseline revision identity

For enrollment baselines:

```text
rev:v1:<targetUUID>:baseline
```

All devices use the same logical baseline revision identity for the same target.

If physical baseline rows have compatible planning metadata, reconciliation treats them as one logical revision and normalizes the enrollment boundary.

If the baseline planning payload differs, the affected target becomes:

```text
notCutoverSafe
```

No schedule winner is guessed.

---

## ADR 4.2 — Compatible duplicate profiles are one logical profile

### Decision

Do NOT delete compatible physical `GamificationProfileSD` rows merely because CloudKit produced duplicates.

All compatible physical rows with the same logical profile key are treated as projections of one logical profile.

Reconciliation:

1. determines the canonical enrollment policy
2. rebuilds logical balances from the canonical ledger projection
3. writes the same canonical projection values into every compatible physical profile row

The profile is a cache, so these values may be normalized:

- `trackingStartedAt` according to ADR 4.1
- scheduling timezone/calendar according to ADR 4.1
- `totalXP`
- `honkerCoins`
- `lifetimeCoinsEarned`
- supported `lifetimeCoinsSpent`
- `aggregateFingerprint`
- projection maintenance metadata

Do not apply this rule to immutable ledger rows.

### Phase 3 compatibility extension

Because Phase 3 currently treats multiple physical profile rows as an error, Phase 4G is authorized to introduce a narrow logical-profile-group resolver.

After 4G:

```text
multiple compatible physical profile rows
→ one logical profile group
→ all compatible projections updated identically
```

But:

```text
incompatible profile rows
→ conflict
→ no gamified transaction
```

This is NOT a weakening of financial conflict detection.

---

## ADR 4.3 — Explicit per-entity semantic comparators

Physical equality is not logical equality.

Each persistent entity gets an explicit comparator.

### GamificationProfileSD

Logical key:

`logicalProfileKey`

Logical compatibility is determined by:

- same logical key
- supported schema
- enrollment metadata canonicalizable under ADR 4.1
- supported calendar

The following are projection/cache values and do NOT independently create a semantic conflict:

- `totalXP`
- `honkerCoins`
- `lifetimeCoinsEarned`
- `lifetimeCoinsSpent`
- `aggregateFingerprint`
- `updatedAt`
- `lastProcessedWeekKey`

They are rebuilt/normalized from authoritative evidence where supported.

### GamificationLedgerEntrySD

Logical key:

`logicalKey`

Semantic payload MUST compare:

- `profileKey`
- `targetID`
- `occurrenceID`
- `xpDelta`
- `coinDelta`
- `reasonRawValue`
- `predecessorLogicalKey`
- `schemaVersion`
- `policyVersion`
- `taskTypeRawValue`
- `priorityRawValue`
- `streakAfterCompletion`
- `isOnTime`
- `rewardEligibilityRawValue`
- `baseXP`
- `baseCoins`
- `multiplierScale`
- `priorityMultiplier`
- `streakMultiplier`
- `timingMultiplier`
- `priorityCoinBonus`
- `streakCoinBonus`

The following are NOT financial entitlement identity by themselves:

- physical row UUID
- `transitionID`
- physical `createdAt`

Therefore two physical reward rows may be logically identical even if they came from different device transitions.

Rule:

```text
same logicalKey + same semantic reward payload
→ one logical ledger entry

same logicalKey + different semantic reward payload
→ financial conflict
```

No winner is guessed.

### TaskOccurrenceSD

Logical key:

`logicalOccurrenceID`

Immutable/planning payload includes, when known:

- target identity
- scheduled civil day
- scheduled timestamp
- due timestamp
- scheduling timezone/calendar
- task type
- schedule revision
- priority snapshot
- icon snapshot
- notification snapshot
- streak planning facts
- reward eligibility
- provenance
- predecessor/alias

Unknown (`nil`) remains distinct from an invented value.

Conflicting non-nil planning facts are a conflict.

Observation/projection state does not independently define reward entitlement:

- physical row UUID
- `completionCount`
- `legacyRecordID`
- completion projection details

Where duplicates are otherwise compatible:

- completed state may monotonically dominate scheduled state
- earliest valid completion evidence may be retained as the logical first completion
- completion count should ultimately be derived from distinct accepted behavior transitions, not by summing duplicate physical occurrence counters
- ambiguous legacy-record linkage makes the target `notCutoverSafe`

Phase 4G may add a narrow logical occurrence-group resolver so Phase 3 can tolerate identical physical duplicates.

Conflicting occurrence planning payload remains a hard error.

### BehaviorEventSD

Logical transition key:

`transitionID`

Compare semantic receipt payload:

- `commandID`
- `targetID`
- `occurrenceID`
- timestamp
- event kind
- completion count where defined
- predecessor transition
- source
- provenance
- schema version

Ignore only physical row identity.

Same transition ID with different semantic receipt data is a conflict.

### BehaviorScheduleRevisionSD

Logical key:

`logicalRevisionID`

Planning payload includes:

- target
- task type
- selected weekdays
- scheduled hour/minute
- dueAt
- scheduling timezone/calendar
- priority
- icon
- notification state
- schema version

Baseline uses deterministic key:

`rev:v1:<targetUUID>:baseline`

For the same logical revision:

- identical planning payload is compatible
- `effectiveTo == nil` versus a valid closure timestamp may be treated as monotonic closure if the remainder of the revision is identical
- different non-nil closure timestamps are a conflict unless later evidence makes one strictly derivable

Different revision keys may coexist as a revision chain.

Two incompatible simultaneously-open revision histories after offline edits make that target `notCutoverSafe`.

No automatic "latest wins" merge is performed.

### Legacy HabitRecordSD

Legacy daily records do not contain enough durable command identity to distinguish:

- two deliberate completions
from
- two physical/sync duplicates

Therefore V1.1.1 does NOT blindly sum same-day physical legacy rows.

If several legacy rows represent the same required day and their meaning is ambiguous:

```text
target = notCutoverSafe
```

Do not destructively merge them.

Do not delete them automatically.

---

## ADR 4.4 — Explicit timestamp timing verification

### Goal

Timing is a positive gamification signal.

Lateness never creates a penalty.

### Planning timestamps

OccurrencePlanner must preserve/derive an explicit planning deadline timestamp where available.

Repeating:

```text
deadlineAt = occurrence.scheduledAt
```

constructed from:

- scheduled local civil day
- schedule revision hour/minute
- profile scheduling timezone
- Gregorian calendar

One-time:

```text
deadlineAt = dueAt
```

### Evaluation

Introduce a pure planning result concept equivalent to:

```text
TimingEvaluation
- onTime
- late
- unavailable
```

This does not require a new persisted SwiftData model.

Mapping to Phase 1 reward input:

```text
onTime      → isOnTime = true
late        → isOnTime = false
unavailable → isOnTime = false
```

`unavailable` means "timing bonus not earned", not "user is penalized."

### Reward

V1.1.1 keeps the existing:

```text
timing multiplier = ×1.10
```

Reason:

- `×1.25` would make punctuality as powerful as the maximum long-term streak multiplier
- this would make time-of-day precision dominate the existing behavior economy
- `×1.10` is meaningful but modest
- balance can be tuned later with real product data through a future policy version

### No penalties

Late completion:

- still completes the task
- still receives normal eligible base reward
- receives priority reward
- receives applicable streak reward where policy permits
- timing multiplier becomes `×1.00`
- no negative XP
- no negative coins
- no streak punishment merely because the completion crossed the timestamp

Miss semantics remain separate from late completion semantics.

### Existing occurrence verification

For an already rewarded occurrence:

- `isOnTime` and reward `policyVersion` must come from the existing initial ledger grant
- do not recalculate an old reward from today's schedule

The occurrence timestamps provide audit/verification evidence, but ledger reward facts remain frozen.

If an eligible completed occurrence requires an initial reward but no valid matching ledger grant exists after reconciliation:

```text
inconsistent state
→ target/profile notCutoverSafe
```

Do not reprice historical work.

---

## ADR 4.5 — Store-scoped gamification profile

V1.1.1 profile scope is the current durable store/container.

Canonical key inside that store:

```text
profile:v1:default
```

A local persistent store and CloudKit-backed store are different HabitHonker worlds.

They may each independently contain:

```text
profile:v1:default
```

They are NOT automatically merged.

Reconciliation never crosses store/container boundaries.

Switching store modes may expose a different task dataset and a different Honker progression.

Seamless cross-store migration is a future feature, not Phase 4.

---

## ADR 4.6 — Local storage must be truly offline-capable

When iCloud/sync is disabled:

HabitHonker must use a durable local persistent store that does not require CloudKit/network availability.

Required storage modes:

```text
durableCloud
durableLocal
ephemeralFallback
```

### durableLocal requirements

- persistent across launches
- CloudKit explicitly disabled for that configuration
- no network dependency
- no iCloud account dependency
- all normal Habit CRUD works
- Phase 5+ gamification may work normally
- enrollment allowed
- ledger/profile allowed
- reconciliation may operate locally
- app remains fully functional offline

### durableCloud requirements

- persistent CloudKit-capable store
- provisional/convergent multi-device semantics
- Phase 4G reconciliation rules apply

### ephemeralFallback requirements

- legacy Habit functionality may remain available according to existing fallback policy
- gamification enrollment forbidden
- gamified live completion forbidden
- durable balance/reconciliation writes forbidden

### Phase 4F audit requirement

Do not trust an existing configuration merely because it is named "local."

Inspect the actual `ModelConfiguration`.

If "sync off" currently still creates a CloudKit-capable configuration, Phase 4F is explicitly authorized to correct that configuration so local mode is genuinely local.

This is an approved v1.1.1 storage correctness requirement.

No schema change is required.

---

# 4. Updated Phase 4 execution roadmap

Phase 4 remains schema-free.

Execution order is frozen:

```text
4A → 4F → 4C → 4B → 4E → 4D → 4G
```

Each sub-phase is a separate implementation run with:

- fresh baseline
- focused implementation
- targeted tests
- full regression
- report
- STOP

## 4A — Metadata-safe persistence

### Goal

Metadata mutations can never overwrite authoritative completion history.

Separate metadata mutation from legacy completion mutation.

Required guarantees:

- stale Details save cannot erase a newer completion
- priority changes cannot replace completion records
- metadata updates cannot resurrect deleted tasks
- metadata saves must not create record-table growth/orphans as a side effect
- create/update semantics are explicit rather than broad production `upsert`

Target concepts:

- `HabitMetadata`
- `createHabit`
- `updateMetadata`
- `updatePriority`
- `recordLegacyCompletion`

`HabitMapper` metadata application must not replace records.

Claude's claim that current mapper leaves orphan rows must be proven with a baseline persistence test, not accepted blindly.

## 4F — Store-mode correctness and durability gate

### Goal

Create explicit, truthful storage semantics.

Required output:

```text
StorageDurabilityState
durableCloud
durableLocal
ephemeralFallback
```

Composition root owns classification.

`AppDependencies` receives it explicitly.

### Additional v1.1.1 requirement

Audit actual local configuration.

When sync is disabled:

- CloudKit must be explicitly disabled
- local store must work without network/iCloud

This requirement is part of 4F, not deferred.

No automatic cross-store data merge.

## 4C — Occurrence and baseline identity

Canonical identities:

```text
profile:v1:default

occ:v1:<UUID>:day:<YYYY-MM-DD>

occ:v1:<UUID>:once

rev:v1:<UUID>:baseline
```

Regular revision/action identities may use explicit versioned UUID-backed logical IDs.

Local civil day:

- Gregorian
- explicit profile timezone
- deterministic components
- half-open interval
- DST-safe

No `DateFormatter` identity.
No `Hasher`.
No current locale/timezone dependency.

## 4B — Schedule revision foundation

Gamification schedule history starts at enrollment.

Do NOT claim gamification schedule history before `trackingStartedAt`.

Before enrollment:

- metadata still changes normally
- no official BehaviorScheduleRevision gamification history is written

Enrollment creates baseline revision:

```text
rev:v1:<target>:baseline
effectiveFrom = canonical trackingStartedAt
```

After enrollment, relevant metadata mutations close/open revisions atomically with metadata mutation.

Revision-relevant fields:

- task type
- selected weekdays
- schedule time
- due timestamp
- priority
- icon
- notification state
- scheduling timezone/calendar

Non-relevant:

- title
- description
- tags
- color

## 4E — Profile enrollment

Enrollment remains explicit/foundation-only in Phase 4.

Not yet automatically called by production app launch.

Enrollment:

- requires durable store
- creates `profile:v1:default`
- starts balances at zero
- establishes `trackingStartedAt`
- establishes fixed scheduling timezone
- establishes Gregorian calendar
- creates deterministic baseline revisions for active habits
- creates no occurrence/event/ledger reward
- gives no retroactive XP

### Multi-device compatibility

Reconciliation rule for independently-created enrollment rows:

- earliest valid enrollment instant becomes canonical
- corresponding timezone/calendar becomes canonical
- compatible physical profile rows are normalized to that policy
- compatible baseline revision rows use deterministic baseline logical IDs
- conflicting baseline planning payload marks affected target unsafe

## 4D — OccurrencePlanner

Planner consumes:

- target/habit snapshot
- profile scheduling policy
- schedule revision
- existing occurrence group
- previous scheduled occurrence
- initial ledger grant when existing rewarded occurrence requires frozen reward facts
- legacy-day compatibility context

Planner produces normalized Phase 3 command facts.

### Scheduled repeating

- eligible
- occurrence is local scheduled day
- streak participates
- deadline timestamp = scheduledAt
- if `completedAt <= scheduledAt`: timing bonus
- if `completedAt > scheduledAt`: no timing bonus, no penalty

### Off-schedule repeating

- behavior recorded
- ineligible for reward
- does not advance streak
- does not satisfy another scheduled day

### One-time

- one lifetime occurrence
- eligible base reward
- streak = 0
- deadline = dueAt
- completion before/at dueAt gets timing bonus
- completion after dueAt gets no timing bonus
- no penalty

### No timestamp

If the required deadline timestamp is unavailable:

- timingEvaluation = unavailable
- timing multiplier = 1.00
- no invented timestamp
- no penalty

### Existing occurrence

Frozen occurrence planning facts are authoritative.

Frozen reward facts not stored on occurrence (`isOnTime`, reward policy version) must be recovered from the existing initial ledger grant.

Do not reprice.

### Type conversion

Repeating ↔ one-time reward alias policy remains unsupported in v1.1.1 if entitlement is ambiguous.

Return typed unsupported/conflict.

Target remains legacy-routable in future preflight.

## 4G — Reconciliation and logical multiplicity

### Goal

Make physical CloudKit duplication compatible with logical correctness without guessing conflicting history.

### Logical profile group

Compatible physical profile rows:

- normalize canonical enrollment policy
- rebuild balances from logical ledger
- update all compatible profile projections identically

Conflicting profile enrollment evidence:

- conflict
- no gamified cutover

### Logical ledger

Identical semantic duplicates:

- count once

Conflicting payload:

- financial conflict
- no winner
- no profile rebuild from that conflict

### Logical occurrence group

Compatible duplicates:

- treat as one logical occurrence
- use explicit immutable planning comparator
- observation state may converge monotonically where safe
- update all compatible physical occurrence projections if mutation is required

Conflicting immutable planning payload:

- target unsafe

### Logical event group

Same transition + identical receipt:

- logical one

Same transition + different receipt:

- conflict

### Logical revision group

Baseline duplicates use deterministic key.

Compatible baseline rows normalize to canonical enrollment boundary.

Incompatible planning metadata:

- target unsafe

Regular overlapping conflicting offline revision histories:

- target unsafe

No latest-wins guess.

### Legacy rows

Ambiguous multiple same-day legacy rows:

- do not sum automatically
- do not delete automatically
- target unsafe for gamified cutover

### Narrow Phase 3 compatibility extension

Phase 4G is authorized to introduce shared logical-group resolution into the Phase 3 transaction boundary.

Allowed:

```text
multiple compatible physical profiles → one logical profile group
multiple identical ledger rows → one logical entitlement
multiple compatible occurrence rows → one logical occurrence
multiple identical event receipts → one logical receipt
```

Required behavior:

- update all compatible mutable projection rows consistently where necessary
- immutable ledger rows remain unchanged
- conflicting duplicates continue to fail safely

Forbidden:

- first row wins
- arbitrary canonical financial row
- destructive reward history deletion
- silent conflict resolution

---

# 5. Phase 5 preflight model frozen by v1.1.1

Phase 5 remains future work.

The architecture it must use is now frozen:

```text
Completion request
        ↓
PRE-FLIGHT ROUTER
        ↓
feature enabled?
durable store?
profile enrolled?
reconciliation safe?
planner supports target/history?
        ↓
YES ------------------- NO
 |                       |
gamified                  legacy
transaction               completion
```

Legacy fallback is allowed ONLY before a gamified transaction begins.

Once gamified transaction begins:

- persistence failure
- planner/transaction conflict
- consistency error

must NOT silently invoke legacy completion.

Phase 5 must add explicit user-facing/retry behavior for such failure.

---

# 6. Theoretical stability audit

## Local single-device durable store

Expected stability after Phase 4:

**High**

Reasons:

- one shared actor
- one-context/one-save transaction
- deterministic occurrence identity
- explicit enrollment
- explicit schedule history
- no stale metadata overwrite
- local store has no CloudKit competition
- reconciliation can rebuild profile cache
- no hidden timing/calendar source

This is the simplest and strongest supported mode.

## Cloud store, one active device

Expected stability:

**High**

It behaves similarly to local mode, with CloudKit transport in the background.

Logical keys and frozen facts protect against retry/relaunch duplication.

## Cloud store, multiple online devices

Expected stability:

**Good, convergent**

Duplicates may physically occur because SwiftData/CloudKit does not provide the same logical uniqueness guarantees as the domain.

v1.1.1 handles this through:

- logical identity
- semantic comparators
- compatible profile groups
- deterministic baseline IDs
- ledger logical dedup
- non-destructive conflict detection

## Cloud store, multiple offline devices making conflicting schedule edits

Expected stability:

**Safe but conservative**

The application may refuse gamified cutover for the affected target after sync.

It does NOT invent the correct history.

Legacy completion remains the future preflight escape route.

This is intentional.

Data correctness is prioritized over invisible guessed merges.

## Ephemeral fallback

Gamification stability:

**Not supported by design**

Legacy task functionality may continue.

Durable XP/coins are forbidden.

This prevents apparent progress from disappearing at process/store reset.

---

# 7. Scope audit

The approved v1.1.1 changes remain inside the intended Phase 4 responsibility except for two explicit, justified boundary adjustments.

## Within Phase 4 scope

- metadata-safe persistence
- storage durability
- true local/offline mode
- occurrence identity
- baseline identity
- enrollment
- schedule revision planning
- occurrence planning
- timing verification
- reconciliation
- cutover safety state

## Narrow approved adjustment to Phase 3

Phase 4G must extend Phase 3 reads/mutations from:

```text
exactly one physical row
```

to:

```text
one compatible logical group
```

for selected entity types.

This is necessary because v1.1.1 intentionally does not delete compatible CloudKit duplicates.

The business transaction semantics remain unchanged.

Conflicts still fail.

## Phase 1 remains unchanged

Timing bonus remains `×1.10`.

No Phase 1 reward formula migration is required.

Phase 4 only improves the meaning and auditability of `isOnTime`.

## Phase 2 schema remains unchanged

Existing V2 fields already contain the required timestamps and schedule metadata.

No new model or V3 is required.

---

# 8. HabitHonker Exp v1.1.1 frozen roadmap

```text
Phase 1  Gamification Math                     COMPLETE
Phase 2  Versioned Persistence                 COMPLETE
Phase 3  Atomic Behavior Transaction           COMPLETE

Phase 4  Behavior Foundation
         4A Metadata Safety
         4F Durable/True Local Storage
         4C Occurrence Identity
         4B Schedule Revision
         4E Enrollment
         4D Occurrence Planner + Timing
         4G Reconciliation                     CURRENT

Phase 5  Live Cutover
Phase 6  Reversal / Restore
Phase 7  Weekly Review + Schema V3
Phase 8  DuckState + Core Gamification UI
Phase 9  Economy + Wardrobe
Phase 10 Prediction Engine
Phase 11 Intervention Engine
Phase 12 Honker AI Brain
Phase 13 Monetization
Phase 14 Production Hardening
```

---

# 9. What exists after Phase 4 but before Phase 5

The application should still look essentially identical to the user.

Internally it will possess:

```text
safe task metadata writes
+
real durable/offline store classification
+
deterministic occurrence identities
+
explicit enrollment model
+
historical schedule revisions from tracking boundary
+
streak/timing/eligibility planner
+
multi-device logical reconciliation
+
cutover safety diagnostics
```

But:

- live completion still uses the legacy route
- XP is not shown
- HonkerCoins are not shown
- duck gameplay is not shown

This is intentional.

Phase 4 builds the interpretation and convergence layer.

Phase 5 activates the engine.

---

# 10. Architectural invariants to preserve

1. No gamification reward side effect from arbitrary metadata `upsert`.
2. No reward formula outside `GamificationService` / calculator layer.
3. No current device timezone used to reinterpret historical occurrence identity.
4. No retroactive XP before enrollment.
5. No arbitrary winner for conflicting financial ledger rows.
6. No destructive reward-history deduplication.
7. No silent legacy fallback after a gamified transaction starts.
8. No gamification on ephemeral storage.
9. Local mode must truly operate without CloudKit/network dependency.
10. Profile is store-scoped in v1.1.1.
11. Profile is a projection; ledger is reward evidence.
12. Compatible physical duplicates may represent one logical object.
13. Conflicting logical payloads are surfaced, not guessed.
14. Late task completion receives no penalty.
15. Timing reward is positive-only and remains a modest `×1.10`.
16. Existing rewarded occurrences are never repriced from today's metadata.
17. Type-conversion reward ambiguity is not auto-resolved in v1.1.1.
18. Phase 4 remains SwiftData Schema V2.

---

# 11. Remaining implementation questions are engineering questions, not product-policy questions

After this v1.1.1 revision, Phase 4 no longer has unresolved critical product choices for:

- enrollment conflict policy
- baseline identity
- duplicate profile handling
- logical duplicate semantics
- on-time timestamp behavior
- timing reward size
- profile/store scope
- local offline storage behavior
- conflicting reward handling

Implementation must still verify repository facts such as:

- whether the current "local" ModelConfiguration actually disables CloudKit
- whether current metadata writes truly leave orphan `HabitRecordSD` rows
- exact source-guard locations
- exact adapter/protocol changes required for logical-group resolution

Those are implementation audits.

They are not permission to redesign the approved policies.
