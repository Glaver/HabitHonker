# HabitHonker Exp v1.1.2
## Architecture & Behavior Foundation Contract

**Status:** architecture revision approved and frozen for Phase 4 execution; no Phase 4 production implementation has been executed by this document.

**Purpose:** freeze the HabitHonker Exp v1.1.2 engineering model after review of Phases 1–3 and the Phase 4 audit, including the approved multi-device, reconciliation, timing, and local-storage decisions.


## v1.1.2 revision summary

v1.1.2 keeps the v1.1.1 Phase 1–14 roadmap and Phase 4 order unchanged, but closes the final behavior-policy gaps discovered during implementation review.

New approved decisions:

- **ADR 4.7 — Explicit Timed Reward Eligibility:** a stored time is considered a real gamification deadline only when the current V1 model gives evidence that the user explicitly opted into that time. In v1.1.2 the available proxy is `notificationEnabled == true`. Otherwise timing is `.unavailable` and earns no timing multiplier.
- **ADR 4.8 — Legacy Streak Bridge:** an unambiguous post-enrollment scheduled completion that was intentionally handled by the legacy path is neutral for streak continuity: it neither increases nor breaks the gamified streak.
- **ADR 4.9 — Metadata Availability Beats Gamification-History Availability:** current Habit metadata is still allowed to save when revision history cannot be safely extended. The revision is not fabricated; the target becomes derived `notCutoverSafe` until reconciliation/history is safe again.
- **ADR 4.10 — Persistent Store Continuity:** disabling CloudKit must not silently point the app at a new empty store. The existing intended local store identity/data must be preserved, or Phase 4F stops for an explicit migration design.
- **ADR 4.11 — Occurrence Timezone Identity Is Immutable:** an occurrence produced under a non-canonical scheduling timezone is never renamed to another civil-day key. If canonicalization would change its logical day identity, the target is `notCutoverSafe`.

These rules supersede any older Phase 4 draft that conflicts with them.

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

A proposed `×1.25` timing multiplier is intentionally NOT adopted in v1.1.2 because it would make timing as powerful as the maximum streak multiplier and materially overweight punctuality relative to the existing priority/streak economy.

Examples:

Maximum repeating XP multiplier under v1.1.2:

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

# 2. HabitHonker Exp v1.1.2 core responsibility model

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

This is an approved v1.1.2 storage correctness requirement.

No schema change is required.

---


## ADR 4.7 — Explicit timed reward eligibility

### Problem

The current Habit model can contain a time even when the user never deliberately chose a gamification deadline.

Examples:

- a repeating habit created at 21:43 may retain `21:43` even when reminders are off;
- a one-time item may default its stored date/time to the creation moment;
- the current UI labels the date field as a start-style value and disables time editing when reminders are off.

Treating those implicit timestamps as deadlines would make the timing multiplier accidental.

### Decision

V1.1.2 grants the timing bonus only when the stored timestamp is considered an **explicit meaningful timed commitment**.

With the current domain/UI model, the approved V1 proxy is:

```text
notificationEnabled == true
```

When `notificationEnabled == false`:

```text
TimingEvaluation = unavailable
isOnTime = false
timing multiplier = ×1.00
```

This applies to both repeating and one-time tasks in v1.1.2.

No penalty is applied.

This is deliberately conservative. A future schema/domain version may separate:

```text
hasDeadline
```

from:

```text
notificationEnabled
```

so a task can have a real deadline without requiring a notification. That is outside Phase 4.

### Repeating

When explicitly timed:

```text
deadlineAt = scheduledAt
```

where `scheduledAt` is built from:

- occurrence scheduled local day;
- revision hour/minute;
- profile scheduling timezone;
- Gregorian calendar.

Then:

```text
completedAt <= scheduledAt → onTime
completedAt > scheduledAt  → late
```

### One-time

When explicitly timed:

```text
deadlineAt = dueAt
```

Then:

```text
completedAt <= dueAt → onTime
completedAt > dueAt  → late
```

When not explicitly timed:

```text
TimingEvaluation.unavailable
```

even if a default `dueAt` value physically exists.

### Reward balance

The existing `×1.10` on-time XP multiplier remains unchanged.

There is no late penalty.

---

## ADR 4.8 — Legacy streak bridge after enrollment

### Problem

After enrollment, Phase 5 may intentionally route a completion through the legacy path because:

- the kill switch is off;
- the target is not safe for gamified cutover;
- storage/preflight does not permit gamified execution.

The legacy path writes `HabitRecord` compatibility data but no `TaskOccurrenceSD`.

If the planner interpreted absence of an occurrence as a miss, a user could lose a streak even though they actually completed the habit.

### Decision

An **unambiguous post-enrollment scheduled legacy completion** is a neutral streak bridge.

It:

- does not increase the streak;
- does not break the streak;
- grants no XP;
- grants no HonkerCoins;
- does not create a retroactive occurrence;
- does not create a retroactive event;
- does not create a retroactive ledger entry.

Example:

```text
Monday:
gamified completion
streakAfter = 5

Wednesday:
legacy completion only
neutral bridge

Friday:
gamified completion
streakBefore = 5
streakAfter = 6
```

### Required proof

A legacy bridge is valid only when the required scheduled day has one unambiguous completion interpretation under the legacy compatibility calendar policy.

If the required legacy day contains ambiguous evidence, the planner/reconciler must not guess.

That target becomes unsafe for the affected planning path.

### Required legacy day

Only legacy history that is actually needed for the current decision is blocking:

- the legacy day the current completion will touch;
- a legacy scheduled day traversed while establishing current streak continuity;
- a legacy record directly referenced by an existing occurrence.

Unrelated years-old legacy anomalies are diagnostics, not permanent cutover blockers.

---

## ADR 4.9 — Metadata availability versus revision-history availability

### Problem

After enrollment, a planning-relevant metadata edit ideally writes:

```text
Habit metadata
+
ScheduleRevision history
```

atomically.

But Cloud/import duplication may make revision history ambiguous before 4G can reconcile it.

Blocking the entire Habit edit would make normal task editing fail because gamification history is unhealthy.

### Decision

The current mutable `HabitSD` remains the current-task source of truth.

Therefore a user's metadata edit is allowed to save even when the revision history cannot be safely extended.

Two outcomes are distinguished:

```text
metadataSaved + revisionApplied
```

or:

```text
metadataSaved + revisionDeferred(historyConflict)
```

When revision is deferred:

- do not fabricate or arbitrarily choose an open revision;
- do not mutate conflicting revision history;
- current Habit metadata still persists;
- the target is derivably `notCutoverSafe` until the history is reconciled or explicitly repaired.

No new persisted flag is required in Phase 4.

The unsafe state can be derived by reconciliation from the mismatch/conflict between current task metadata and trustworthy revision history.

### Preferred API semantics

A result equivalent to:

```swift
enum MetadataHistoryOutcome {
    case revisionApplied
    case revisionNotRequired
    case revisionDeferred(BehaviorHistoryConflict)
}
```

may be used if it fits current project conventions.

The UI may continue its current behavior in Phase 4; Phase 5 preflight uses the cutover-safety result.

---

## ADR 4.10 — Persistent store continuity when disabling CloudKit

### Problem

Making a "local" `ModelConfiguration` that points at a new store file can make all existing habits appear to disappear.

That is data-path breakage, even if the old store remains on disk.

### Decision

Turning CloudKit off must preserve the intended existing local persistent data world.

Phase 4F must first establish:

- the actual current store URL used by local/sync-off mode;
- the actual current store URL used by Cloud mode;
- the actual `ModelConfiguration` CloudKit options;
- whether the same existing store can be reopened safely with CloudKit disabled.

### Required safety test

Create a store with the current pre-4F configuration and seed representative data:

- Habit IDs;
- HabitRecord IDs/counts/dates;
- deleted/archive rows;
- StatisticsPreset where applicable.

Close the container.

Open using the proposed `durableLocal` configuration.

The same intended user dataset must still exist.

Testing only that two default URL strings look equal is insufficient.

### Hard stop

If SwiftData cannot safely disable CloudKit while preserving the intended current store identity/data without an explicit migration/copy operation:

**STOP Phase 4F.**

Report the exact limitation.

Do not silently open a new empty database.

Do not design an unapproved store-copy migration yourself.

---

## ADR 4.11 — Scheduling-timezone occurrence identity is immutable

### Problem

Two devices may independently enroll with different scheduling timezones before reconciliation.

A later-enrolled device can create an occurrence whose canonical day key under its timezone differs from the day that would be produced under the canonical earliest-enrollment timezone.

Example:

```text
Device B occurrence:
occ:v1:<task>:day:2026-09-26

Canonical profile timezone after reconciliation:
America/Los_Angeles

The same completion instant belongs to:
2026-09-25
```

### Decision

Do not rename an existing occurrence key.

Do not rewrite:

```text
day:2026-09-26
```

into:

```text
day:2026-09-25
```

because occurrence identity participates in:

- reward logical keys;
- ledger linkage;
- transition linkage;
- historical schedule meaning.

If an occurrence was created under a scheduling policy incompatible with the canonical profile policy and canonicalization would change the logical occurrence identity:

```text
occurrenceIdentityConflict
target = notCutoverSafe
```

Reconciliation reports the conflict.

It does not rename or merge the occurrence automatically.

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

## 4F — Store-mode correctness, durability gate, and store continuity

### Goal

Create explicit truthful storage semantics and guarantee that sync-off mode is genuinely durable/offline without silently switching the user to an empty database.

Required output:

```text
StorageDurabilityState
durableCloud
durableLocal
ephemeralFallback
```

Composition root owns classification.

`AppDependencies` receives it explicitly.

### Actual configuration audit is mandatory

Do not trust a variable or UI setting called "local".

Inspect the actual SwiftData `ModelConfiguration`:

- CloudKit database setting;
- store URL/path;
- whether the current "sync off" mode is still CloudKit-capable;
- whether local and cloud modes currently use the same or different physical store identity.

### durableLocal contract

When sync is disabled:

- CloudKit must be explicitly disabled;
- data must persist across launches;
- no network/iCloud account is required;
- all normal Habit CRUD works;
- later gamification is allowed;
- enrollment is allowed;
- ledger/profile are durable;
- local reconciliation can run;
- offline/airplane operation is fully supported.

### Store continuity

Do not create a new named local configuration that silently opens a different empty store.

Phase 4F must prove that representative data written with the current intended local/sync-off storage path remains present under the proposed `durableLocal` configuration.

The verification must compare real seeded data, not only nominal URLs.

At minimum preserve:

- Habit IDs;
- HabitRecord IDs/dates/counts;
- deleted/archive records;
- statistics preset data where applicable.

If the current store cannot safely be reopened with CloudKit disabled without a migration/copy operation:

**STOP 4F and report.**

Do not invent a migration without approval.

### durableCloud

Persistent Cloud-capable store.

Uses provisional/convergent multi-device semantics.

4G reconciliation applies.

### ephemeralFallback

Legacy Habit behavior may continue under existing fallback policy.

But:

- no gamification enrollment;
- no gamified cutover;
- no durable XP/coins;
- no profile rebuild claimed as durable.

### No automatic cross-store merge

A local store and cloud store remain separate HabitHonker worlds in v1.1.2.


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

- metadata still changes normally;
- no official BehaviorScheduleRevision gamification history is written.

Enrollment creates baseline revision:

```text
rev:v1:<target>:baseline
effectiveFrom = canonical trackingStartedAt
```

After enrollment, planning-relevant metadata normally closes/opens revision history.

Revision-relevant fields:

- task type;
- selected weekdays;
- schedule time;
- due timestamp;
- priority;
- icon;
- notification state;
- scheduling timezone/calendar.

Non-relevant:

- title;
- description;
- tags;
- color.

### Safe revision path

When exactly one compatible logical open revision can be established:

```text
metadata mutation
+
close/open revision mutation
```

must share one repository actor operation, one ModelContext, and one save.

### Revision-history conflict path

If profile multiplicity/open-revision multiplicity/history conflict prevents a safe revision write:

**do not block the user's current metadata edit solely because gamification history is unhealthy.**

Persist the current Habit metadata.

Do not fabricate a revision.

Do not choose `fetch.first`.

Do not choose latest/earliest open revision.

Return/record an application-layer outcome equivalent to:

```text
metadataSaved + revisionDeferred(historyConflict)
```

The target becomes derivably:

```text
notCutoverSafe
```

until reconciliation/history repair makes it safe.

No persisted `notCutoverSafe` flag is required in Schema V2.

4G derives safety from the current state.

### Duplicate open revisions

Multiple candidate open revisions receive the same conservative treatment as duplicate profile/history ambiguity:

- if they are already semantically compatible logical duplicates that the approved grouping rule can safely recognize, operate on the logical group;
- otherwise defer revision history and mark the target unsafe;
- never select one arbitrarily.

### Delete / restore

After enrollment:

- delete/archive closes trustworthy open revision history when safe;
- restore opens a new revision when safe;
- if history is ambiguous, preserve the core task lifecycle and expose deferred/unsafe history rather than fabricate a revision.


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

- target/habit snapshot;
- profile scheduling policy;
- trustworthy schedule revision;
- existing logical occurrence group;
- previous scheduled occurrence/history needed for streak;
- initial ledger grant when existing rewarded occurrence requires frozen reward facts;
- legacy-day compatibility context;
- explicit completion intent/time/source.

Planner produces normalized Phase 3 command facts.

It does not save and does not calculate XP itself.

### Explicit timed reward eligibility

Timing bonus is available only when the V1 model proves an explicit meaningful time commitment.

Approved V1.1.2 proxy:

```text
notificationEnabled == true
```

If `notificationEnabled == false`:

```text
TimingEvaluation.unavailable
isOnTime = false
timing multiplier = ×1.00
```

This applies to both repeating and one-time tasks.

The existence of a default stored Date is not enough.

### Scheduled repeating

- eligible;
- occurrence is the profile-timezone scheduled civil day;
- streak participates;
- if explicitly timed, deadline = `scheduledAt`;
- `completedAt <= scheduledAt` → `.onTime`;
- `completedAt > scheduledAt` → `.late`;
- if untimed → `.unavailable`;
- late/unavailable means no timing bonus, never a penalty.

### Off-schedule repeating

- behavior can be recorded;
- ineligible for reward;
- does not advance streak;
- does not satisfy another scheduled day;
- does not steal yesterday/tomorrow entitlement.

### One-time

- one lifetime occurrence;
- eligible base reward;
- streak before/after = 0;
- if explicitly timed, deadline = `dueAt`;
- before/at dueAt → `.onTime`;
- after dueAt → `.late`;
- if untimed → `.unavailable`;
- no penalty.

### Legacy streak bridge

A post-enrollment scheduled day completed through the legacy path may participate only as **neutral continuity evidence**.

When the required legacy day is unambiguous:

```text
legacy completion:
does not increment streak
does not break streak
```

It grants:

- no retroactive XP;
- no retroactive coins;
- no occurrence backfill;
- no behavior-event backfill;
- no ledger backfill.

When traversing streak history:

```text
previous gamified completed scheduled occurrence → continue from stored streakAfter

legacy-completed scheduled day → skip neutrally and continue searching backward

true scheduled miss → reset to 0
```

Only required legacy days may block planning.

Years-old unrelated legacy anomalies do not permanently poison the target.

### Required legacy day

A legacy day is required only when it is:

- the compatibility day the current completion will mutate;
- a scheduled day traversed to determine current streak continuity;
- directly referenced by an existing occurrence.

Ambiguous evidence on a required day:

typed unsafe/conflict.

### Existing occurrence

Frozen occurrence planning facts are authoritative.

Do not reconstruct them from current Habit metadata.

Frozen reward facts not present on occurrence (`isOnTime`, reward policy version) must be recovered from the existing initial ledger grant.

Do not reprice.

### Timezone identity conflict

If an existing occurrence was created using a scheduling timezone/calendar policy incompatible with the reconciled canonical profile policy, and canonical interpretation would produce a different occurrence day key:

```text
occurrenceIdentityConflict
target = notCutoverSafe
```

Do not rename the occurrence.

Do not rewrite its reward key.

### Type conversion

Repeating ↔ one-time reward alias policy remains unsupported in v1.1.2 when entitlement is ambiguous.

Return typed unsupported/conflict.

Target remains legacy-routable in future Phase 5 preflight.


## 4G — Reconciliation and logical multiplicity

### Goal

Make physical CloudKit duplication compatible with logical correctness without guessing conflicting history.

### Logical profile group

Compatible physical profile rows:

- normalize canonical enrollment policy;
- rebuild balances from logical ledger;
- update all compatible profile projections identically.

Conflicting profile enrollment evidence:

- conflict;
- no gamified cutover.

### Logical ledger

Identical semantic duplicates:

- count once.

Conflicting payload:

- financial conflict;
- no winner;
- no profile rebuild from that conflict.

### Logical occurrence group

Compatible duplicates:

- treat as one logical occurrence;
- use the explicit immutable planning comparator;
- observation state may converge monotonically where safe;
- do not blindly sum physical completion counts.

Conflicting immutable planning payload:

- target unsafe.

### Occurrence timezone-policy validation

After canonical enrollment policy is determined, validate each relevant occurrence against that scheduling timezone/calendar.

If an occurrence identity would map to a different civil-day key under the canonical policy:

- flag `occurrenceIdentityConflict`;
- mark target `notCutoverSafe`;
- do not rename;
- do not migrate logical occurrence ID;
- do not rewrite ledger logical keys.

### Logical event group

Same transition + identical receipt:

- logical one.

Same transition + different receipt:

- conflict.

### Logical revision group

Baseline duplicates use deterministic key.

Compatible baseline rows normalize to canonical enrollment boundary.

Incompatible planning metadata:

- target unsafe.

Regular overlapping conflicting offline revision histories:

- target unsafe.

No latest-wins guess.

Multiple open revisions are not resolved by arbitrary selection.

### Legacy rows

Do not scan all historical same-day anomalies and permanently block a target.

Only **required legacy days** participate in cutover safety for the current planning path.

Required means:

- current completion compatibility day;
- day traversed for the active streak calculation;
- record referenced by an existing occurrence.

On a required day:

ambiguous multiple legacy records
→ do not sum automatically
→ do not delete automatically
→ target unsafe for that cutover/planning path.

Unrelated old anomalies remain diagnostics.

### Legacy neutral bridge

4G must make enough normalized evidence available for 4D to identify an unambiguous post-enrollment legacy completion as neutral streak continuity.

This does not create retroactive occurrence/event/ledger rows.

### Metadata/revision mismatch

When 4B saved metadata but deferred revision history, 4G must detect the resulting untrustworthy planning mismatch and report the target as `notCutoverSafe`.

It must not fabricate the missing historical revision.

### Narrow Phase 3 compatibility extension

Phase 4G is authorized to introduce shared logical-group resolution into the Phase 3 transaction boundary.

Allowed:

```text
multiple compatible physical profiles → one logical profile group
multiple identical ledger rows → one logical entitlement
multiple compatible occurrence rows → one logical occurrence
multiple identical event receipts → one logical receipt
```

Required:

- update all compatible profile projection rows consistently;
- immutable ledger entries remain unchanged;
- true semantic conflicts still fail;
- no `fetch.first`;
- no destructive financial deduplication.


# 5. Phase 5 preflight model frozen by v1.1.2

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

v1.1.2 handles this through:

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

The approved v1.1.2 changes remain inside the intended Phase 4 responsibility except for two explicit, justified boundary adjustments.

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

This is necessary because v1.1.2 intentionally does not delete compatible CloudKit duplicates.

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

# 8. HabitHonker Exp v1.1.2 frozen roadmap

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
10. Profile is store-scoped in v1.1.2.
11. Profile is a projection; ledger is reward evidence.
12. Compatible physical duplicates may represent one logical object.
13. Conflicting logical payloads are surfaced, not guessed.
14. Late task completion receives no penalty.
15. Timing reward is positive-only and remains a modest `×1.10`.
16. Existing rewarded occurrences are never repriced from today's metadata.
17. Type-conversion reward ambiguity is not auto-resolved in v1.1.2.
18. Phase 4 remains SwiftData Schema V2.

---


## v1.1.2 additional invariants


19. Timing bonus requires an explicit meaningful timed task in V1.1.2; current proxy is `notificationEnabled == true`.
20. Untimed repeating/one-time work gets no timing multiplier and no penalty.
21. Unambiguous post-enrollment legacy completions are neutral streak bridges, not misses and not streak increments.
22. User metadata remains editable even when gamification revision history must be deferred.
23. Deferred revision history makes the target derivably `notCutoverSafe`; history is never fabricated.
24. Disabling CloudKit must not silently select a new empty store.
25. Existing occurrence logical day identity is never renamed across timezone-policy reconciliation.
26. Only legacy history required for the current completion/streak path can block cutover; unrelated old anomalies are diagnostics.

# 11. Remaining implementation questions are engineering questions, not product-policy questions

After this v1.1.2 revision, Phase 4 no longer has unresolved critical product choices for:

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
