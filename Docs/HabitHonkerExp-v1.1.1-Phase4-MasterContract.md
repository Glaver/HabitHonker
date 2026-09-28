> **SUPERSEDED by HabitHonker Exp v1.1.2.** Use `Docs/HabitHonkerExp-v1.1.2.md` (architecture/ADRs) and `Docs/HabitHonkerExp-v1.1.2-Claude-Phase4.md` (execution prompt). Where this file differs, v1.1.2 wins.

# HABITHONKER EXP v1.1.1
# PHASE 4 — BEHAVIOR FOUNDATION BEFORE LIVE CUTOVER
# MASTER EXECUTION CONTRACT

You are the IMPLEMENTATION EXECUTOR for HabitHonker Exp v1.1.1.

You are NOT the product architect for this task.

The architecture, product rules, responsibility boundaries, phase order,
conflict policies and Phase 4 completion gates below are already approved.

Your job is to:

- inspect the current repository,
- verify the current source against the stated starting point,
- implement the approved Phase 4 architecture,
- preserve all previously completed Phase 1–3 behavior,
- add narrow protocols and dependency injection where specified,
- add focused tests,
- run full regressions,
- create implementation reports,
- stop at every requested phase gate.

DO NOT invent a new product rule.

DO NOT silently reinterpret an approved rule.

DO NOT choose "the most convenient" conflict winner.

DO NOT continue into Phase 5.

If current repository facts make an approved rule impossible without changing
SwiftData Schema V2 or violating a frozen Phase 1–3 contract:

STOP.

Report:

1. exact contradiction,
2. source file and symbol,
3. why the approved design cannot be implemented safely,
4. smallest technically valid alternatives,
5. which existing test/contract would be affected.

Do not choose an alternative yourself.

======================================================================
0. READ BEFORE ANY IMPLEMENTATION
======================================================================

Read the current repository and these documents first:

Docs/HabitHonkerExp-v1.1.1.md

Docs/GamificationArchitectureInvestigation.md

Docs/GamificationPhase1Report.md

Docs/GamificationPhase2Report.md

Docs/GamificationPhase3Report.md

Docs/GamificationTransactionContract.md

Any current Phase 4 report that already exists.

CURRENT SOURCE CODE takes precedence over stale implementation names in
historical reports.

The PRODUCT/ARCHITECTURE decisions in HabitHonkerExp-v1.1.1.md take
precedence over older Phase 4 planning drafts.

Do not revive superseded defaults from an earlier Phase 4 plan.

======================================================================
1. FROZEN PRODUCT ROADMAP
======================================================================

PHASE 1 — GAMIFICATION MATH
STATUS: COMPLETE / FROZEN

Already implemented:

GamificationPolicy
RewardCalculator
LevelCalculator
GamificationService
XP
Honk Coins
priority multipliers
streak multipliers
streak milestones
timing multiplier
level curve
deterministic rounding
pure protocol boundaries

Phase 1 owns arithmetic only.

------------------------------------------------------------

PHASE 2 — VERSIONED PERSISTENCE
STATUS: COMPLETE / FROZEN

Current persisted V2 behavior/gamification entities:

TaskOccurrenceSD
BehaviorScheduleRevisionSD
BehaviorEventSD
GamificationProfileSD
GamificationLedgerEntrySD

Legacy compatibility entities remain:

HabitSD
HabitRecordSD
DeletedHabitSD
StatisticsPresetSD

Migration:

V1 -> V2

------------------------------------------------------------

PHASE 3 — ATOMIC BEHAVIOR TRANSACTION
STATUS: COMPLETE / FROZEN
except for the narrowly-authorized logical-group compatibility extension
described under Phase 4G.

Current conceptual architecture:

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

Atomic write set:

HabitRecord compatibility projection
+
TaskOccurrenceSD
+
BehaviorEventSD
+
optional GamificationLedgerEntrySD
+
optional GamificationProfileSD update

Phase 3 already guarantees locally:

- one-save atomicity
- rollback
- durable command receipts
- reward entitlement idempotency
- occurrence idempotency
- checked arithmetic
- frozen reward snapshots
- injected GamificationService
- shared repository actor
- protocol-based DI

Historical Phase 3 verification was 112/112 tests.

This is historical evidence only.

Run a FRESH baseline before every Phase 4 sub-phase.

------------------------------------------------------------

PHASE 4 — CURRENT WORK

Execute in this exact order:

4A Metadata-safe persistence
4F Durable / true local storage
4C Occurrence identity
4B Schedule revision foundation
4E Gamification profile enrollment
4D Occurrence planner + timing semantics
4G Reconciliation / logical multiplicity

Each letter is a separate implementation run.

DO NOT execute the whole Phase 4 in one context window.

------------------------------------------------------------

PHASE 5 — LIVE CUTOVER
OUT OF SCOPE

Phase 5 will eventually route real completion through:

preflight
→ planner
→ atomic Phase 3 transaction

Phase 4 does NOT enable this.

------------------------------------------------------------

PHASE 6 — REVERSAL / RESTORE
OUT OF SCOPE

PHASE 7 — WEEKLY REVIEW + SWIFTDATA SCHEMA V3
OUT OF SCOPE

PHASE 8 — DUCK STATE + GAMIFICATION UI
OUT OF SCOPE

PHASE 9 — ECONOMY + WARDROBE
OUT OF SCOPE

PHASE 10 — PREDICTION
OUT OF SCOPE

PHASE 11 — INTERVENTION ENGINE
OUT OF SCOPE

PHASE 12 — HONKER AI BRAIN
OUT OF SCOPE

PHASE 13 — MONETIZATION
OUT OF SCOPE

PHASE 14 — PRODUCTION HARDENING
OUT OF SCOPE

======================================================================
2. CURRENT PHASE 4 STARTING POINT
======================================================================

Before Phase 4 implementation the following should still be true:

- live HabitService completion uses the legacy path
- live completion does NOT create TaskOccurrenceSD
- live completion does NOT create BehaviorEventSD
- live completion does NOT create GamificationLedgerEntrySD
- live completion does NOT update GamificationProfileSD
- no XP is visible
- no HonkerCoins are visible
- no gamification UI exists
- no automatic gamification enrollment exists
- no occurrence planner exists in the live path
- no reconciliation is called by the live app
- V2 remains the active schema

Verify these facts from current source.

Do not merely trust historical reports.

======================================================================
3. GLOBAL RESPONSIBILITY MODEL
======================================================================

HabitSD

    mutable CURRENT task definition

BehaviorScheduleRevisionSD

    historical schedule/planning interpretation from gamification enrollment
    onward

TaskOccurrenceSD

    one logical behavior occurrence

BehaviorEventSD

    durable transition / accepted-command evidence

GamificationLedgerEntrySD

    append-only reward history

GamificationProfileSD

    rebuildable cache/projection of ledger economics

Rules:

Habit/task state is NOT event sourced.

Do not rebuild the entire app from BehaviorEvents.

The Gamification Ledger is append-only historical reward evidence.

GamificationProfile is NOT financial truth.

Occurrence/schedule data preserve historical behavior meaning.

UI does NOT calculate gamification rules.

NotificationCenter does NOT orchestrate business behavior.

Prediction does NOT consume DuckState as source-of-truth.

Persistent logical identity must never rely on Swift Hasher.

======================================================================
4. GLOBAL DEPENDENCY-INJECTION RULES
======================================================================

Every meaningful business boundary must be protocol-backed.

Do not create protocols only for decorative abstraction.

Every protocol must own a specific responsibility.

Use constructor injection.

Composition happens in AppDependencies / the current composition root.

No mutable global singleton.

No service locator.

No static mutable global gamification state.

No SwiftData types in domain/service protocol signatures.

No ModelContext or ModelContainer leakage through domain/service protocols.

Persistence adapters may use SwiftData internally.

Where account-wide serialization matters, use the existing container-scoped
HabitsRepositorySwiftData actor.

Do NOT introduce a competing account-wide persistence actor.

Do NOT let several repositories independently save portions of one logical
transaction.

======================================================================
5. PURE DOMAIN RULES
======================================================================

Pure behavior-planning/identity services must not depend on:

SwiftUI
SwiftData
ModelContext
ModelContainer

Date()
Calendar.current
TimeZone.current
Locale.current

NotificationCenter
HabitEventCenter

Swift Hasher for persisted IDs

Reward formula duplication
Level formula duplication

Business time/calendar/timezone must be supplied explicitly.

======================================================================
6. SWIFTDATA SCHEMA BOUNDARY
======================================================================

PHASE 4 MUST REMAIN SWIFTDATA SCHEMA V2.

DO NOT:

create V3

add a new @Model

change a persisted V2 field

rename persisted V2 fields

change migration schemas

change migration plan

add WeeklyGamificationSnapshotSD

If a requirement appears to need persisted data that V2 cannot represent:

STOP.

Explain the missing state and why existing fields cannot represent it.

Do not silently mutate schema.

======================================================================
7. FROZEN REWARD BALANCE
======================================================================

Repeating:

base XP = 25
base HC = 3

One-time:

base XP = 40
base HC = 5

Priority XP:

Important / Not Urgent = ×1.30
Important / Urgent = ×1.20
Not Important / Urgent = ×1.10
Not Important / Not Urgent = ×1.00

Priority HC:

Important / Not Urgent = +2
Important / Urgent = +1
others = +0

Repeating streak XP:

1       = ×1.00
2–3     = ×1.05
4–6     = ×1.10
7–13    = ×1.15
14–29   = ×1.20
30+     = ×1.25

Milestone HC:

3   = +2
7   = +5
14  = +8
30  = +15
60  = +25
100 = +50

Timing:

on time = ×1.10
late = ×1.00
timing unavailable = ×1.00

There is NO lateness penalty.

Do not change the reward formula in Phase 4.

Do not change timing to ×1.25.

Reason:

×1.25 timing would make punctuality as powerful as the maximum long-term
streak multiplier.

V1.1.1 intentionally keeps punctuality as a modest positive signal.

======================================================================
8. APPROVED ARCHITECTURE DECISION — MULTI-DEVICE ENROLLMENT
======================================================================

The v1.1.1 policy is HYBRID B+C.

Problem:

Two devices can independently enroll the same Cloud-backed logical store
before synchronization.

Example:

Device A
profile:v1:default
trackingStartedAt = T1

Device B
profile:v1:default
trackingStartedAt = T2

They are separate physical rows but one logical profile.

------------------------------------------------------------
CANONICAL ENROLLMENT
------------------------------------------------------------

Among compatible physical profile rows:

canonical trackingStartedAt =
earliest valid trackingStartedAt

The scheduling timezone/calendar belonging to that earliest valid enrollment
becomes canonical.

Gregorian is the supported V1 scheduling calendar.

If two physical rows have the exact same earliest enrollment instant but
incompatible scheduling timezone/calendar:

CONFLICT.

Do not guess.

The earliest-wins exception applies ONLY to enrollment metadata.

It does NOT apply to:

XP
coins
ledger reward payload
occurrence planning conflicts
general CloudKit conflict resolution

------------------------------------------------------------
BASELINE REVISION ID
------------------------------------------------------------

Gamification enrollment baseline revision identity is deterministic:

rev:v1:<targetUUID>:baseline

Do not use a random baseline revision logical ID.

If two physical baseline revisions with this logical key have compatible
planning payload:

they represent one logical baseline revision.

If baseline planning payload conflicts:

the target is:

notCutoverSafe

No schedule winner is guessed.

======================================================================
9. APPROVED ARCHITECTURE DECISION — DUPLICATE PROFILE PROJECTIONS
======================================================================

All compatible physical GamificationProfileSD rows sharing the same
logicalProfileKey represent ONE logical profile.

DO NOT delete compatible physical profile rows merely to satisfy the
single-row assumptions of old Phase 3 code.

Profile is a CACHE.

Ledger is reward history.

Reconciliation must:

1. determine canonical enrollment policy
2. construct logical ledger projection
3. rebuild logical balance
4. update EVERY compatible physical profile row to the same canonical
   projection state

Compatible physical profile projection fields may therefore be normalized:

trackingStartedAt
scheduling timezone/calendar
totalXP
honkerCoins
lifetimeCoinsEarned
supported lifetimeCoinsSpent
aggregateFingerprint
projection maintenance fields

If profile rows are enrollment-incompatible:

CONFLICT.

No arbitrary selection.

======================================================================
10. APPROVED ARCHITECTURE DECISION — SEMANTIC COMPARATORS
======================================================================

Physical row equality is NOT logical equality.

Phase 4G must implement explicit domain comparators/grouping policies.

Do not compare every persisted scalar blindly.

Do not ignore financially meaningful differences.

------------------------------------------------------------
10.1 GamificationProfileSD
------------------------------------------------------------

Logical key:

logicalProfileKey

Compatibility:

same logical key
supported schema
enrollment metadata canonicalizable under Hybrid B+C
supported scheduling calendar

These are rebuildable cache values and DO NOT independently make profiles
conflicting:

totalXP
honkerCoins
lifetimeCoinsEarned
lifetimeCoinsSpent
aggregateFingerprint
updatedAt
lastProcessedWeekKey

Those fields are rebuilt/normalized where the supported ledger allows it.

------------------------------------------------------------
10.2 GamificationLedgerEntrySD
------------------------------------------------------------

Logical key:

logicalKey

Semantic entitlement comparison MUST include:

profileKey
targetID
occurrenceID
xpDelta
coinDelta
reasonRawValue
predecessorLogicalKey
schemaVersion
policyVersion
taskTypeRawValue
priorityRawValue
streakAfterCompletion
isOnTime
rewardEligibilityRawValue
baseXP
baseCoins
multiplierScale
priorityMultiplier
streakMultiplier
timingMultiplier
priorityCoinBonus
streakCoinBonus

These are NOT entitlement identity by themselves:

physical row UUID
transitionID
physical createdAt

Rules:

same logicalKey
+
same semantic entitlement payload
=
ONE logical ledger entry

same logicalKey
+
different semantic entitlement payload
=
FINANCIAL CONFLICT

DO NOT:

take earliest
take latest
average
sum both
delete one
choose smallest UUID

------------------------------------------------------------
10.3 TaskOccurrenceSD
------------------------------------------------------------

Logical key:

logicalOccurrenceID

Immutable/planning facts include where known:

target
scheduled local civil date
scheduledAt
dueAt
scheduling timezone
scheduling calendar
task type
schedule revision
priority snapshot
icon snapshot
notification snapshot
streak planning facts
reward eligibility
provenance
predecessor/alias

Unknown nil is NOT permission to invent a value.

Conflicting non-nil planning values:

CONFLICT.

Observation/projection state does NOT independently define financial
entitlement:

physical row UUID
completionCount
legacyRecordID
derived completion projection details

For compatible duplicate occurrences:

completed state may monotonically dominate scheduled state

earliest valid completion evidence may define logical first completion

completion count should be based on distinct accepted behavior transitions,
not by blindly summing physical occurrence counters

ambiguous legacy linkage makes target:

notCutoverSafe

------------------------------------------------------------
10.4 BehaviorEventSD
------------------------------------------------------------

Logical identity:

transitionID

Semantic receipt comparison:

commandID
targetID
occurrenceID
timestamp
kind
completionCount where semantically defined
predecessorTransitionID
source
provenance
schemaVersion

Ignore physical row UUID only.

Same transitionID + different semantic receipt:

CONFLICT.

------------------------------------------------------------
10.5 BehaviorScheduleRevisionSD
------------------------------------------------------------

Logical identity:

logicalRevisionID

Planning comparison:

target
task type
weekday mask
scheduled hour
scheduled minute
dueAt
scheduling timezone/calendar
priority
icon
notification state
schema version

Baseline ID:

rev:v1:<targetUUID>:baseline

For one logical revision:

identical planning payload = compatible

effectiveTo nil vs a valid closure may be treated as monotonic closure only
when the rest of the revision is compatible

different incompatible non-nil closure facts = conflict unless one can be
strictly derived from later authoritative evidence

Different logical revision IDs may form a normal revision chain.

Two incompatible simultaneously-open offline histories make target:

notCutoverSafe

No latest-wins merge.

------------------------------------------------------------
10.6 Legacy HabitRecordSD
------------------------------------------------------------

Legacy records lack sufficient command identity to determine whether two
same-day physical rows are:

two real deliberate completions

or

sync duplicates.

Therefore:

DO NOT blindly sum same-day legacy rows.

DO NOT automatically delete them.

Ambiguous multiple same-day legacy records required by a gamified target:

target = notCutoverSafe

======================================================================
11. APPROVED ARCHITECTURE DECISION — TIMESTAMP / TIMING
======================================================================

Timing is POSITIVE-ONLY gamification.

It is not punishment.

Introduce a pure concept equivalent to:

TimingEvaluation

onTime
late
unavailable

No new SwiftData model is required.

------------------------------------------------------------
REPEATING
------------------------------------------------------------

Occurrence planning deadline:

deadlineAt = scheduledAt

scheduledAt is derived from:

scheduled local civil day
+
revision scheduled hour/minute
+
profile scheduling timezone
+
Gregorian calendar

Evaluation:

completedAt <= scheduledAt
→ onTime

completedAt > scheduledAt
→ late

------------------------------------------------------------
ONE-TIME
------------------------------------------------------------

deadlineAt = dueAt

completedAt <= dueAt
→ onTime

completedAt > dueAt
→ late

------------------------------------------------------------
UNAVAILABLE TIMESTAMP
------------------------------------------------------------

If a valid required deadline cannot be established:

TimingEvaluation.unavailable

Mapping to reward:

isOnTime = false

Do NOT fabricate a timestamp.

Do NOT fail a normal completion solely because timing bonus cannot be
computed unless another required scheduling invariant is also invalid.

------------------------------------------------------------
REWARD EFFECT
------------------------------------------------------------

onTime:
timing multiplier ×1.10

late:
timing multiplier ×1.00

unavailable:
timing multiplier ×1.00

No negative XP.

No negative coins.

Do not break a streak merely because an otherwise completed scheduled task
was late.

Missing a scheduled occurrence and completing it late are DIFFERENT
concepts.

------------------------------------------------------------
EXISTING REWARDED OCCURRENCE
------------------------------------------------------------

For an already rewarded occurrence:

`isOnTime`
and
reward `policyVersion`

must come from its existing initial ledger grant.

Do not recalculate historical reward facts from current schedule metadata.

If reconciliation finds:

eligible completed occurrence
but
no valid required initial reward evidence

do not silently reprice it.

Return inconsistent/notCutoverSafe state.

======================================================================
12. APPROVED ARCHITECTURE DECISION — STORE-SCOPED PROFILE
======================================================================

V1.1.1 gamification profile belongs to one durable store/container.

Canonical logical key inside that store:

profile:v1:default

A local persistent store and a Cloud-backed store are two separate HabitHonker
worlds.

They may each contain:

profile:v1:default

They are NOT automatically merged.

Reconciliation NEVER crosses store/container boundaries.

Switching storage worlds may show a different task dataset and different
Honker progression.

Cross-store migration/merge is a future feature.

======================================================================
13. APPROVED ARCHITECTURE DECISION — TRUE OFFLINE LOCAL STORAGE
======================================================================

When iCloud/sync is disabled, HabitHonker must have a genuinely durable local
store.

Required modes:

durableCloud
durableLocal
ephemeralFallback

------------------------------------------------------------
durableLocal
------------------------------------------------------------

Must:

persist across app launches

explicitly disable CloudKit for that ModelConfiguration

require no network

require no iCloud account

support normal Habit CRUD

support Phase 5+ gamification

support enrollment

support profile/ledger persistence

support local reconciliation

work normally in airplane/offline conditions

------------------------------------------------------------
durableCloud
------------------------------------------------------------

Persistent Cloud-capable store.

Uses provisional/convergent multi-device semantics.

Phase 4G reconciliation rules apply.

------------------------------------------------------------
ephemeralFallback
------------------------------------------------------------

Existing legacy Habit behavior may continue according to current fallback
policy.

But it must NOT:

enroll gamification
run future gamified completion
present durable XP/coin progression
write/rebuild durable gamification projection

------------------------------------------------------------
PHASE 4F REQUIRED AUDIT
------------------------------------------------------------

Do NOT trust a configuration because code calls it "local."

Inspect the actual SwiftData ModelConfiguration.

If sync-off currently still creates CloudKit-capable configuration:

Phase 4F is explicitly authorized to correct it so local mode is genuinely
local/offline.

This is an APPROVED storage-correctness change.

No schema change.

======================================================================
14. TYPE-CONVERSION POLICY
======================================================================

Repeating ↔ one-time conversion may change schedule history.

Phase 4 may record the type revision.

But v1.1.1 does NOT approve an automatic reward alias rule when entitlement
becomes ambiguous.

If OccurrencePlanner cannot determine reward entitlement safely after type
conversion:

return typed unsupported/conflict state

mark target notCutoverSafe where required

Future Phase 5 can route that target to legacy path at PRE-FLIGHT.

Do not guess.

======================================================================
15. FUTURE PHASE 5 ROUTING RULE
======================================================================

Do NOT implement Phase 5.

But all Phase 4 services must support this architecture:

Completion request
        ↓
PRE-FLIGHT
        ↓
feature enabled?
durable store?
profile enrolled?
reconciliation state safe?
planner supports target/history?
        ↓
 YES ---------------- NO
  |                    |
gamified             legacy
transaction          completion

Legacy fallback is allowed ONLY before a gamified transaction starts.

Once the gamified transaction is selected:

transaction persistence failure
consistency conflict
unexpected transaction error

MUST NOT silently run the old legacy mutation afterward.

Why:

that would allow HabitRecord completion to commit while occurrence/event/
ledger/profile bundle did not commit.

This is forbidden.

Phase 5 will need explicit retry/error UX.

Do not implement that UX in Phase 4.

======================================================================
16. PHASE 4 EXECUTION ORDER
======================================================================

The order is frozen:

4A
→ 4F
→ 4C
→ 4B
→ 4E
→ 4D
→ 4G

Every sub-phase must have:

fresh baseline
targeted tests
full regression
diff audit
report
STOP

Do not continue automatically.

======================================================================
17. PHASE 4A — METADATA-SAFE PERSISTENCE
======================================================================

GOAL:

Metadata writes must no longer own completion history.

This fixes an existing application integrity problem before gamification
cutover.

------------------------------------------------------------
17.1 Audit first
------------------------------------------------------------

Inspect:

HabitMapper

HabitRepositoryProtocol

SwiftDataHabitRepository

HabitsRepositorySwiftData

HabitService

HabitServiceProtocol

HabitListViewModel

PriorityMatrixViewModel

HabitDetailView

current notification save flow

delete/archive behavior

current tests/spies relying on upsert/saveHabit

Before production changes, verify the stale-record hypothesis with tests.

------------------------------------------------------------
17.2 Required ownership split
------------------------------------------------------------

Create a domain value equivalent to:

HabitMetadata

containing editable Habit fields EXCEPT completion records.

Use project naming conventions.

Provide explicit operations conceptually equivalent to:

createHabit

updateMetadata

updatePriority

recordLegacyCompletion

Do not require these exact signatures if current code conventions suggest a
cleaner equivalent.

Behavior requirements:

CREATE

existing ID:
alreadyExists

never silently overwrite

UPDATE METADATA

missing ID:
notFound

never insert

never assign/replace completion records

return freshly persisted model including authoritative current records

UPDATE PRIORITY

priority only

never assign records

LEGACY COMPLETION

one actor operation

find matching record for supplied calendar day

if one:
checked increment
preserve record ID
preserve original record timestamp

if none:
insert record at explicit completion time

if historical ambiguity/multiple rows exists:
do not silently rewrite unrelated history

Use the narrowest safe behavior compatible with current legacy completion
semantics.

------------------------------------------------------------
17.3 Mapper
------------------------------------------------------------

Broad metadata application must never rebuild `records`.

If creation/import/migration paths legitimately need record construction,
keep that responsibility explicitly separate.

Do not break DeletedHabit conversion or migrations.

------------------------------------------------------------
17.4 Service
------------------------------------------------------------

Current HabitService completion remains LEGACY.

But it should stop requiring fetch→mutate whole HabitModel→upsert if the new
narrow recordLegacyCompletion repository call can preserve existing
semantics.

Use injected time/calendar where practical for testability.

Defaults may preserve today's live Date()/Calendar.current behavior at the
application boundary.

Do not introduce gamification planner/transaction.

------------------------------------------------------------
17.5 View models
------------------------------------------------------------

Creation and metadata edit must no longer rely on ambiguous "upsert means
either."

If current UI sends create/update through one saveItem path, a narrow routing
split is authorized.

View models must store the RETURNED fresh persisted HabitModel instead of a
submitted stale draft.

Priority updates must return/use fresh state.

------------------------------------------------------------
17.6 No-resurrection
------------------------------------------------------------

A queued stale update after delete must never reinsert the Habit.

Update missing target:

typed notFound

no new HabitSD

Preserve deleted/archive evidence.

Notification cleanup may be required if current ordering can leave an alarm
for an update rejected because the Habit no longer exists.

Do not otherwise redesign notifications.

------------------------------------------------------------
17.7 Orphan claim must be proven
------------------------------------------------------------

An earlier audit claimed broad mapper saves can leave old HabitRecordSD rows
orphaned.

DO NOT assume this blindly.

Add a baseline persistence characterization:

count total HabitRecordSD rows, including rows without inverse Habit

perform repeated metadata updates

measure again

If current baseline creates orphans:
document failing evidence and fix future metadata-write behavior.

Do not destructively clean already-existing orphan rows in Phase 4A.

If hypothesis is false:
document that result.

------------------------------------------------------------
17.8 Required 4A tests
------------------------------------------------------------

Stale draft:

draft = fetch
complete
change title in old draft
save metadata
reload

EXPECT:
new title
AND completion preserved

Priority after completion:

completion preserved

Repeated metadata updates:

record IDs
dates
counts
total persisted record rows
remain stable

Icon update:
records unchanged

Notification metadata update:
records unchanged

Schedule metadata update:
records unchanged

Delete then stale save:
notFound
no resurrection

Create same ID:
alreadyExists
no overwrite

Concurrent priority/metadata vs legacy completions through real service/
repository boundaries:
all committed completions remain

Legacy completion:
same supplied calendar day increments
next day inserts
explicit non-device timezone/calendar test

Existing statistics regression

Existing notifications regression

------------------------------------------------------------
17.9 4A forbidden work
------------------------------------------------------------

No schema changes.

No schedule revisions yet.

No profile enrollment.

No occurrences/events/ledger.

No Phase 3 changes.

No UI gamification.

------------------------------------------------------------
17.10 4A report
------------------------------------------------------------

Docs/GamificationPhase4AReport.md

Include:

fresh baseline

root cause

failing-first evidence

orphan hypothesis result

old/new APIs

production files changed

tests

behavior changes

protected files

full suite result

READY FOR 4F: YES/NO

STOP.

======================================================================
18. PHASE 4F — DURABLE / TRUE LOCAL STORAGE
======================================================================

GOAL:

Make storage durability explicit and make sync-off genuinely offline-local.

------------------------------------------------------------
18.1 Domain state
------------------------------------------------------------

Introduce an explicit value equivalent to:

StorageDurabilityState

durableCloud
durableLocal
ephemeralFallback

This is domain/application composition information.

------------------------------------------------------------
18.2 Ownership
------------------------------------------------------------

HabitHonkerApp / current container composition code knows how ModelContainer
was built.

It must pass storage mode into AppDependencies.

Do not rediscover mode inside repositories.

------------------------------------------------------------
18.3 Audit existing local configuration
------------------------------------------------------------

Inspect actual ModelConfiguration when sync/iCloud is disabled.

Determine:

CloudKit database mode
persistent store URL
whether it differs from cloud store
whether network/iCloud is truly unnecessary

Record exact findings.

If "local" still enables CloudKit:

correct it.

After correction durableLocal must explicitly disable CloudKit.

Do not change schema.

------------------------------------------------------------
18.4 Store scoping
------------------------------------------------------------

The DI graph must be container/store scoped.

Do not share gamification services/profile projection across local and cloud
containers.

Switching stores rebuilds dependencies.

------------------------------------------------------------
18.5 Durability gate
------------------------------------------------------------

Expose a protocol/value usable by:

Enrollment
Reconciliation
future Phase 5 router

durableLocal:
allowed

durableCloud:
allowed

ephemeralFallback:
gamification durable mutation forbidden

------------------------------------------------------------
18.6 Existing fallback
------------------------------------------------------------

Do not redesign existing fallback UX.

But eliminate silent inability to identify fallback mode.

If container creation currently swallows useful diagnostics, narrow
do/catch/logging improvements are authorized.

------------------------------------------------------------
18.7 Required 4F tests
------------------------------------------------------------

durableCloud reaches AppDependencies correctly

durableLocal reaches AppDependencies correctly

ephemeral fallback reaches AppDependencies correctly

durableLocal configuration has CloudKit disabled

durableLocal survives store/container reopen

durableLocal CRUD works without Cloud assumptions

dependency graph construction performs no gamification enrollment

fallback gate denies future enrollment mutation

fallback gate denies reconciliation mutation

normal legacy Habit graph still works under fallback

switch/rebuild creates container-scoped dependencies

No live gamification.

------------------------------------------------------------
18.8 Report
------------------------------------------------------------

Docs/GamificationPhase4FReport.md

Document actual pre-fix local configuration.

READY FOR 4C: YES/NO

STOP.

======================================================================
19. PHASE 4C — OCCURRENCE IDENTITY
======================================================================

GOAL:

Provide stable deterministic logical business identities.

Pure domain layer.

------------------------------------------------------------
19.1 Canonical identities
------------------------------------------------------------

Profile:

profile:v1:default

Repeating occurrence:

occ:v1:<canonicalUUID>:day:<YYYY-MM-DD>

One-time occurrence:

occ:v1:<canonicalUUID>:once

Enrollment baseline revision:

rev:v1:<canonicalUUID>:baseline

Other regular revision/action logical IDs may use versioned UUID-backed
identity following the project architecture.

Freeze the chosen UUID textual normalization in tests.

Do not rely on locale formatting.

------------------------------------------------------------
19.2 LocalDay
------------------------------------------------------------

Introduce a pure value equivalent to LocalDay containing:

canonical key YYYY-MM-DD

half-open DateInterval

Use:

explicit Gregorian calendar
explicit scheduling timezone

Calculate date components explicitly.

Do not use localized DateFormatter for business keys.

DST must naturally produce a 23/24/25 hour DateInterval when appropriate.

Never assume a day is 86,400 seconds.

------------------------------------------------------------
19.3 Command / transition identity
------------------------------------------------------------

Do NOT derive transition IDs from occurrence count.

Two independent devices could generate the same count.

Delivery/action IDs may use random UUID-backed versioned identities.

Occurrence identity itself is deterministic.

------------------------------------------------------------
19.4 Validation
------------------------------------------------------------

Reject invalid:

target identifier
date components
unsupported identity version
unsupported scheduling calendar where relevant

Do not invent fallback IDs.

------------------------------------------------------------
19.5 Required 4C tests
------------------------------------------------------------

same repeating target + same local day = same ID

neighbor local day = different ID

one-time due-date edit = same one-time ID

leap day

year change

DST 23-hour day

DST 25-hour day

midnight boundary

same instant under two explicit timezones creates corresponding civil dates

device locale does not affect identity

non-Gregorian device calendar does not affect identity

fresh service instances produce identical IDs

baseline revision identity deterministic per target

canonical profile key stable

source guard:

no Date()
no Calendar.current
no TimeZone.current
no Locale.current
no Hasher

------------------------------------------------------------
19.6 Report
------------------------------------------------------------

Docs/GamificationPhase4CReport.md

READY FOR 4B: YES/NO

STOP.

======================================================================
20. PHASE 4B — SCHEDULE REVISION FOUNDATION
======================================================================

GOAL:

Persist historical gamification schedule meaning from tracking enrollment
forward.

IMPORTANT:

Gamification schedule history starts at trackingStartedAt.

Do NOT fabricate official gamification schedule history before enrollment.

------------------------------------------------------------
20.1 Revision planner
------------------------------------------------------------

Create a pure protocol/implementation equivalent to:

BehaviorScheduleRevisionPlanning

Inputs:

previous frozen schedule snapshot
new frozen schedule snapshot
effectiveAt
explicit scheduling timezone/calendar

Output conceptually:

noChange

or

close previous revision
+
open next revision

No SwiftData in the planner.

------------------------------------------------------------
20.2 Revision-relevant fields
------------------------------------------------------------

A revision is required for changes affecting reward/planning meaning:

task type
selected weekdays
scheduled hour/minute
one-time dueAt
priority
icon
notification state
scheduling timezone
scheduling calendar

Do NOT create a revision for:

title
description
tags
display color

unless current code proves one of those participates in an already-approved
planner contract.

------------------------------------------------------------
20.3 Enrollment boundary
------------------------------------------------------------

Before a gamification profile exists:

metadata changes are saved safely

but no official schedule revision history is written.

Enrollment in 4E creates the baseline.

After enrollment:

revision-relevant edit:
close current
open new

non-relevant edit:
metadata only

------------------------------------------------------------
20.4 Revision intervals
------------------------------------------------------------

Half-open:

[effectiveFrom, effectiveTo)

Open:

effectiveTo = nil

Relevant edit:

old.effectiveTo = effectiveAt
new.effectiveFrom = effectiveAt

Delete/archive after enrollment:

close open revision

Restore after enrollment:

open new revision

------------------------------------------------------------
20.5 Atomicity with metadata
------------------------------------------------------------

A metadata mutation requiring a revision and that revision write must commit
inside:

one repository actor operation
one context
one save

Do not save metadata and revision separately.

Use a synchronous helper if appropriate, following Phase 3's safe pattern.

------------------------------------------------------------
20.6 Profile multiplicity while editing
------------------------------------------------------------

Before 4G, if metadata persistence encounters multiple physical profile rows:

do not arbitrarily choose one.

Schedule revision gating should recognize whether the logical enrollment can
be safely identified under the approved Hybrid B+C policy.

If the current sub-phase cannot yet safely normalize the group:

fail revision-history mutation with typed reconciliationRequired/conflict
rather than guessing.

Do not corrupt task metadata.

Clearly define whether metadata itself may still save while revision history
cannot be made safe.

Preferred correctness model:

after enrollment, planning-relevant metadata + required revision are one
atomic behavior-history responsibility.

Therefore if revision safety cannot be established, do not claim successful
historical update.

Document this exact behavior.

------------------------------------------------------------
20.7 Baseline identity
------------------------------------------------------------

Do not create baseline here for unenrolled existing tasks.

4E creates:

rev:v1:<target>:baseline

------------------------------------------------------------
20.8 Required 4B tests
------------------------------------------------------------

pre-enrollment title edit:
no revision

pre-enrollment priority edit:
no official gamification revision

enrolled fixture + title:
no new revision

enrolled fixture + priority:
close/open

weekday:
close/open

scheduled time:
close/open

one-time dueAt:
close/open

icon:
close/open

notification:
close/open

task type:
close/open

exactly one logical open revision in clean single-device case

delete closes

restore opens

metadata + revision injected failure:
both rollback

no occurrence created

no behavior event created

no ledger entry created

no reward/profile balance change

------------------------------------------------------------
20.9 Guard adjustments
------------------------------------------------------------

Existing tests/source guards written before schedule revision implementation
may prohibit legitimate Phase 4B references.

Narrow such guards ONLY to allow the approved revision writer responsibility.

Do not weaken unrelated Occurrence/Event/Ledger/Profile protections.

Document every guard change.

------------------------------------------------------------
20.10 Report
------------------------------------------------------------

Docs/GamificationPhase4BReport.md

READY FOR 4E: YES/NO

STOP.

======================================================================
21. PHASE 4E — GAMIFICATION PROFILE ENROLLMENT
======================================================================

GOAL:

Create an explicit durable boundary from which gamification history starts.

Enrollment is implemented but NOT automatically called by the live app in
Phase 4.

------------------------------------------------------------
21.1 Service boundary
------------------------------------------------------------

Create a protocol equivalent to:

GamificationEnrollmentServiceProtocol

Use explicit DI.

Service depends on:

narrow enrollment repository protocol
durability gate

No SwiftData API in service contract.

------------------------------------------------------------
21.2 Enrollment input
------------------------------------------------------------

Explicit command/value:

profileKey
trackingStartedAt
schedulingTimeZoneIdentifier
schedulingCalendarIdentifier

Canonical profile:

profile:v1:default

V1 calendar:

Gregorian

Service must not call Date() / TimeZone.current internally to choose business
facts.

Caller supplies them.

------------------------------------------------------------
21.3 Durability
------------------------------------------------------------

durableCloud:
allowed

durableLocal:
allowed

ephemeralFallback:
typed notDurable
no writes

------------------------------------------------------------
21.4 Atomic enrollment write
------------------------------------------------------------

One actor
one ModelContext
one save

Create:

GamificationProfileSD

AND

baseline BehaviorScheduleRevisionSD for every currently active Habit needing
a baseline

Initial profile:

totalXP = 0
honkerCoins = 0
lifetimeCoinsEarned = 0
lifetimeCoinsSpent = 0
trackingStartedAt = explicit enrollment instant
timezone = explicit scheduling timezone
calendar = Gregorian

Do NOT create:

TaskOccurrenceSD
BehaviorEventSD
GamificationLedgerEntrySD

Do NOT read old HabitRecords to seed progression.

------------------------------------------------------------
21.5 Baseline revision
------------------------------------------------------------

For each active Habit:

logicalRevisionID:

rev:v1:<targetUUID>:baseline

effectiveFrom:

trackingStartedAt

snapshot:

current planning-relevant Habit metadata at enrollment

Meaning:

"first known gamification scheduling state"

NOT:

"this metadata was historically true before trackingStartedAt"

Deleted/inactive old Habit:

no baseline.

------------------------------------------------------------
21.6 Single-device idempotency
------------------------------------------------------------

No profile:
create

Exactly one compatible profile:
alreadyEnrolled
no new balances
no duplicate baseline

------------------------------------------------------------
21.7 Multi-device duplicate enrollment
------------------------------------------------------------

Phase 4E does not destructively reconcile existing duplicate physical rows.

If multiple profile physical rows are already visible:

evaluate enough logical compatibility to return:

alreadyEnrolledCompatibleGroup

or

reconciliationRequired/conflict

Do not pick a physical row.

Full normalization belongs to 4G.

The approved future canonical rule is:

earliest trackingStartedAt
+
timezone/calendar of that enrollment
+
deterministic baseline IDs

------------------------------------------------------------
21.8 Required 4E tests
------------------------------------------------------------

first enrollment durableLocal

first enrollment durableCloud-shaped test environment

zero balances

trackingStartedAt exact preservation

timezone exact preservation

Gregorian policy

baseline for every active Habit

no baseline for deleted Habit

no occurrence/event/ledger

no retroactive XP

legacy HabitRecord history unchanged

on-disk reopen idempotency

compatible existing profile returns stable enrollment result

duplicate incompatible profile returns conflict/reconciliation required

ephemeral rejected

injected failure rolls back profile AND every baseline revision

construction of AppDependencies still does not auto-enroll

RootTabsView still does not auto-enroll in Phase 4

------------------------------------------------------------
21.9 Report
------------------------------------------------------------

Docs/GamificationPhase4EReport.md

READY FOR 4D: YES/NO

STOP.

======================================================================
22. PHASE 4D — OCCURRENCE PLANNER + TIMING
======================================================================

GOAL:

Convert explicit completion intent and durable behavior facts into all
normalized facts required by the existing Phase 3 transaction.

The planner:

DOES NOT save.

DOES NOT award XP.

DOES NOT update profile.

DOES NOT call BehaviorTransactionService itself.

------------------------------------------------------------
22.1 Interfaces
------------------------------------------------------------

Expected conceptual boundaries:

OccurrencePlanningServiceProtocol

OccurrencePlanning

BehaviorPlanningRepositoryProtocol

OccurrenceIdentifying

TimingEvaluating if useful as a separate pure responsibility

Use project-conventional names if cleaner.

All service/planner input/output is domain-only.

------------------------------------------------------------
22.2 Planning intent
------------------------------------------------------------

Provide explicit:

targetID
completedAt
profileKey
source
legacy/device-calendar context needed for legacy compatibility

Document ownership of:

commandID
transitionID

Do not accidentally make deterministic occurrence identity double as
delivery identity.

------------------------------------------------------------
22.3 Planning facts
------------------------------------------------------------

Planner/read layer must obtain:

current target existence/state

logical enrolled profile policy

effective schedule revision

existing logical occurrence group for computed occurrence ID

relevant prior scheduled occurrences/revisions for streak

existing initial ledger grant for an already-rewarded occurrence when needed

legacy-day compatibility information

type-conversion ambiguity state

No direct SwiftData object reaches pure planner.

------------------------------------------------------------
22.4 Output
------------------------------------------------------------

Produce enough normalized data for BehaviorCompletionCommand:

profileKey

targetID

occurrenceID

completedAt

legacyCompletionDate

legacyDay half-open DateInterval

GamificationRewardInput:
taskType
priority
streakAfterCompletion
isOnTime
rewardEligibility
policyVersion

BehaviorOccurrenceSnapshot:
scheduledLocalDateKey
scheduledAt
dueAt
timezone
calendar
scheduleRevisionID
iconName
notificationEnabled
streakBefore
provenance
predecessor/alias when approved

Do not calculate XP.

------------------------------------------------------------
22.5 New scheduled repeating occurrence
------------------------------------------------------------

Use the revision effective for that scheduled local civil date.

If local date is scheduled:

rewardEligibility = eligible

occurrence identity =
occ:v1:<target>:day:<local-date>

scheduledAt =
civil date + revision scheduled time in profile timezone

Timing:

completedAt <= scheduledAt
→ onTime

completedAt > scheduledAt
→ late/no timing bonus

Late DOES NOT:

subtract XP
subtract coins
break an otherwise completed occurrence's streak

------------------------------------------------------------
22.6 Off-schedule repeating completion
------------------------------------------------------------

Current app permits completing "Not for today."

Preserve behavior.

Occurrence uses actual completion civil date in profile scheduling timezone.

rewardEligibility = ineligible

isOnTime = false

does not advance streak

does not satisfy an adjacent scheduled occurrence

does not steal yesterday/tomorrow reward entitlement

Still creates normalized behavior evidence in the future gamified path.

------------------------------------------------------------
22.7 One-time
------------------------------------------------------------

Identity:

occ:v1:<target>:once

streakBefore = 0
streakAfterCompletion = 0

Reward eligibility:

eligible for its one lifetime occurrence

Timing:

completedAt <= dueAt
→ onTime

completedAt > dueAt
→ late/no timing bonus

Repeated deliberate completion later:

same occurrence identity

Phase 3 reward logical key ensures no second initial reward.

Missing required dueAt:

do not fabricate.

Return typed planner state appropriate to the actual domain requirement.

If completion can still exist but timing is unavailable:
TimingEvaluation.unavailable
isOnTime false

If dueAt is required to interpret the task at all:
typed planning error

Choose based on current Habit domain semantics and document the distinction.

------------------------------------------------------------
22.8 Streak
------------------------------------------------------------

V1.1.1 repeating streak = consecutive SCHEDULED occurrences completed.

Unscheduled days:
ignored

Off-schedule completions:
ignored

Scheduled completed occurrence:
participates

Scheduled missed occurrence:
breaks

Pre-enrollment obligations:
do not exist for streak purposes

First eligible scheduled completion after enrollment:

streakBefore 0
streakAfter 1

Unselected weekdays between scheduled days do NOT break streak.

Use schedule revisions historically.

Do not assume the previous calendar day is previous scheduled occurrence.

Use checked arithmetic.

------------------------------------------------------------
22.9 Existing occurrence is authoritative
------------------------------------------------------------

CRITICAL.

When an occurrence already exists:

DO NOT reconstruct its immutable frozen planning snapshot from today's Habit.

Reuse existing logical occurrence frozen facts.

Required regression:

09:00 completion under Priority P1

10:00 priority changed to P2

11:00 same logical occurrence deliberately completed again

Planner must produce a command compatible with stored occurrence P1.

Phase 3 must NOT throw conflictingOccurrenceSnapshot.

No second initial reward.

Run analogous tests for:

scheduled/reminder time edit

icon snapshot change

notification snapshot change

other immutable occurrence fact changes

------------------------------------------------------------
22.10 Existing reward facts
------------------------------------------------------------

V2 occurrence does not store every reward fact.

For already rewarded occurrence, frozen:

isOnTime
policyVersion
reward calculation facts

come from existing initial ledger grant.

Do NOT re-evaluate them from current schedule.

If the occurrence is eligible/completed and logical history says an initial
grant should exist but reconciliation cannot produce one valid grant:

notCutoverSafe / inconsistent state

Do not retroactively reprice.

------------------------------------------------------------
22.11 Type conversion
------------------------------------------------------------

Repeating ↔ one-time transitions may be recorded in schedule revision
history.

But reward entitlement aliasing is NOT approved in v1.1.1.

When planner encounters ambiguous type-conversion entitlement:

typed unsupportedTypeTransition/conflict

Future Phase 5 preflight can use legacy route.

Do not automatically set ineligible alias merely to keep gamification alive.

------------------------------------------------------------
22.12 Legacy day
------------------------------------------------------------

Gamification occurrence identity uses:

profile fixed timezone + Gregorian.

Legacy compatibility HabitRecord must preserve existing Statistics behavior.

The planner/orchestration facts must carry whatever explicit legacy calendar
context is required by the Phase 3 transaction.

Do not migrate Statistics now.

------------------------------------------------------------
22.13 Race architecture
------------------------------------------------------------

Phase 4 builds planner/read boundaries.

Phase 5 must eventually be able to do:

read planning facts
→ pure plan
→ apply Phase 3 transaction

inside one serialized actor ownership window without an await race between
read and commit.

Design Phase 4 APIs so this is possible.

Do NOT enable it live yet.

------------------------------------------------------------
22.14 Required 4D tests
------------------------------------------------------------

scheduled repeating before timestamp

scheduled repeating exactly at timestamp

scheduled repeating after timestamp

late gets no penalty

timing unavailable path

off-schedule repeating

first scheduled occurrence after enrollment

streak across unselected days

miss breaks streak

off-schedule does not extend streak

schedule change uses historical revision

priority change uses historical revision

one-time before dueAt

one-time exactly dueAt

one-time after dueAt

one-time repeated action same occurrence

existing occurrence after priority change

existing occurrence after reminder change

existing occurrence after snapshot metadata change

existing rewarded occurrence recovers isOnTime from ledger

existing rewarded occurrence recovers policyVersion from ledger

missing expected initial grant → typed unsafe/inconsistent

DST spring forward

DST fall back

year boundary

profile timezone != device timezone

pre-enrollment history ignored

ambiguous type conversion → typed unsupported/conflict

deterministic planner

pure-source dependency guard

real integration fixture feeding planner output to Phase 3 transaction
WITHOUT making it the live app path

------------------------------------------------------------
22.15 Report
------------------------------------------------------------

Docs/GamificationPhase4DReport.md

READY FOR 4G: YES/NO

STOP.

======================================================================
23. PHASE 4G — RECONCILIATION / LOGICAL MULTIPLICITY
======================================================================

GOAL:

Provide deterministic, non-destructive logical convergence for physical
duplication introduced by CloudKit/offline devices.

This is NOT globally-serializable exactly-once reward authority.

Do not claim it is.

------------------------------------------------------------
23.1 Service boundaries
------------------------------------------------------------

Create:

GamificationReconciliationServiceProtocol
or project-equivalent

and a narrow reconciliation repository protocol.

Dependencies:

repository
durability provider/gate
semantic comparator/grouping components where appropriate

No SwiftData leakage in service API.

------------------------------------------------------------
23.2 Scope
------------------------------------------------------------

Reconcile/logically inspect:

GamificationProfileSD

GamificationLedgerEntrySD

TaskOccurrenceSD

BehaviorEventSD

BehaviorScheduleRevisionSD

legacy HabitRecord compatibility anomalies needed for cutover safety

------------------------------------------------------------
23.3 Durability
------------------------------------------------------------

durableCloud:
allowed

durableLocal:
allowed

ephemeralFallback:
reconciliation mutation forbidden

Local reconciliation is still useful for cache rebuild/integrity checking,
even though local mode should not produce normal cross-device duplicates.

------------------------------------------------------------
23.4 Profile grouping
------------------------------------------------------------

Group by logicalProfileKey.

For compatible group:

canonical enrollment boundary per Hybrid B+C

canonical timezone/calendar per Hybrid B+C

build logical ledger projection

rebuild canonical profile values

update ALL compatible physical profile rows to identical projection state

Do not delete them merely because multiple rows exist.

If enrollment metadata cannot be canonicalized safely:

profile conflict
notCutoverSafe

------------------------------------------------------------
23.5 Ledger grouping
------------------------------------------------------------

Group by logicalKey.

Use the exact semantic comparator contract.

Identical entitlement payloads:

count ONCE logically

do not edit immutable ledger entries

do not sum duplicates

Conflicting payload:

financialConflict

profile cannot be safely rebuilt from unresolved financial history

No winner.

------------------------------------------------------------
23.6 Occurrence grouping
------------------------------------------------------------

Group by logicalOccurrenceID.

Compare immutable planning payload.

Compatible group:

represents one logical occurrence

derive/normalize observation projection only where safely supported by
distinct behavior events and monotonic facts

Do not blindly sum physical completionCount.

Conflicting immutable planning facts:

target conflict
notCutoverSafe

Ambiguous legacyRecordID linkage:

target notCutoverSafe

------------------------------------------------------------
23.7 Event grouping
------------------------------------------------------------

Group by transitionID.

Identical semantic receipt:

logical one

conflicting receipt:

conflict

Distinct transition IDs remain distinct user actions.

------------------------------------------------------------
23.8 Revision grouping
------------------------------------------------------------

Group by logicalRevisionID.

Baseline:

deterministic rev:v1:<target>:baseline

Compatible multi-device baseline rows:

one logical baseline

normalize effective enrollment boundary under Hybrid B+C where safe

Different baseline planning payload:

target conflict

For regular revision history:

compatible chain:
accept

two incompatible simultaneously-open histories:
target notCutoverSafe

Do not latest-wins merge.

------------------------------------------------------------
23.9 Legacy same-day anomalies
------------------------------------------------------------

Detect multiple legacy records within one required compatibility day.

Do not automatically sum.

Do not automatically delete.

If command identity/evidence is insufficient to determine meaning:

target notCutoverSafe

------------------------------------------------------------
23.10 Profile rebuild
------------------------------------------------------------

For currently-supported ledger reasons:

logical totalXP =
checked sum of DISTINCT logical entitlement entries

logical honkerCoins =
checked supported coin projection

lifetimeCoinsEarned =
checked supported earned-coin projection

lifetimeCoinsSpent =
only if current supported ledger reason semantics actually provide reliable
spend evidence

Do not fabricate spending.

Preserve/canonicalize enrollment policy according to approved rules.

Unsupported ledger reason:

typed unsupported reason
no guessed rebuild

------------------------------------------------------------
23.11 Fingerprint
------------------------------------------------------------

If using aggregateFingerprint:

define exact canonical logical projection

sort deterministically

encode stable fields deterministically

no Swift Hasher

standard cryptographic digest is acceptable

Repeated run over same logical state produces same fingerprint.

------------------------------------------------------------
23.12 Mutation ownership
------------------------------------------------------------

Reconciliation mutation:

one repository actor
one context
validate first
stage
one save

Do not mutate immutable ledger reward facts.

Do not delete reward history.

Do not silently rewrite conflicting occurrence/revision history.

Profile cache normalization is allowed.

Compatible mutable projection normalization needed for logical-group support
is allowed when precisely documented and tested.

------------------------------------------------------------
23.13 Narrow Phase 3 extension
------------------------------------------------------------

Phase 3 currently assumes some logical identities have exactly one physical
row.

Phase 4G is explicitly authorized to replace selected "one physical row"
assumptions with:

one compatible logical group

ONLY where the semantic comparator proves compatibility.

Expected allowed result:

multiple compatible physical profiles
→ one logical profile

multiple identical physical reward rows
→ one logical entitlement

multiple compatible physical occurrences
→ one logical occurrence

multiple identical physical receipts
→ one logical transition receipt

Conflicting duplicates MUST still fail.

DO NOT turn Phase 3 into:

fetch.first

DO NOT weaken conflict tests.

Add tests proving all old true conflicts still fail.

------------------------------------------------------------
23.14 Cutover safety result
------------------------------------------------------------

Reconciliation output must provide a domain-level safety assessment usable by
Phase 5 preflight.

Conceptually:

profile:
safeForGamifiedCutover
or conflict

target:
safeForGamifiedCutover
or conflict

Include typed reasons.

Possible unsafe reasons include:

financial ledger conflict

profile enrollment conflict

occurrence snapshot conflict

revision history conflict

ambiguous legacy-day records

missing required reward evidence

unsupported ledger reason

unsupported type-conversion history

Do not conflate these into one opaque bool internally.

------------------------------------------------------------
23.15 Required 4G tests
------------------------------------------------------------

clean consistent store:
safe, no mutation beyond optional fingerprint normalization

stale profile:
rebuilt

two compatible profile rows:
both normalized to same projection

two profile rows different balances but same compatible enrollment:
not a conflict; ledger rebuild wins

two profile rows incompatible enrollment:
conflict

earlier multi-device enrollment selected canonically

deterministic baseline duplicate compatible:
logical one

baseline duplicate incompatible planning payload:
target unsafe

identical physical ledger duplicate:
count once

conflicting ledger duplicate:
financial conflict

identical occurrence duplicates:
logical one

occurrence immutable payload conflict:
target unsafe

occurrence physical count disagreement:
do not blindly sum

identical event duplicate:
logical one

event receipt conflict:
conflict

compatible revision duplicate:
logical one

conflicting open offline revision histories:
target unsafe

legacy same-day ambiguity:
target unsafe

unsupported ledger reason:
no profile rebuild guess

arithmetic overflow:
rollback

repeated reconciliation:
idempotent

shuffled physical row order:
same logical result

on-disk close/reopen:
same result

durableLocal integrity rebuild:
works without network/CloudKit

ephemeral:
mutation rejected

Phase 3 new compatible-logical-group transaction test:
continues successfully

Phase 3 true-conflict tests:
still fail safely

------------------------------------------------------------
23.16 Report
------------------------------------------------------------

Docs/GamificationPhase4GReport.md

Include:

logical grouping rules

semantic comparators

profile projection rebuild

Hybrid B+C result

all conflict categories

cutover-safety model

Phase 3 extension

local vs cloud behavior

known distributed limitation

targeted tests

full regression

final Phase 4 gate

STOP.

======================================================================
24. PHASE 4 PERMANENT DOCUMENTATION
======================================================================

By the END of 4G, repository documentation must contain an implementation-
accurate permanent contract.

Create or update:

Docs/HabitHonkerExp-v1.1.1.md

Docs/BehaviorFoundationContract.md

Docs/GamificationPhase4AReport.md
Docs/GamificationPhase4FReport.md
Docs/GamificationPhase4CReport.md
Docs/GamificationPhase4BReport.md
Docs/GamificationPhase4EReport.md
Docs/GamificationPhase4DReport.md
Docs/GamificationPhase4GReport.md

The permanent BehaviorFoundationContract must document:

metadata ownership

storage modes

real local/offline guarantees

store-scoped profile

multi-device enrollment canonicalization

baseline revision identity

occurrence identity

schedule revision policy

enrollment boundary

planner responsibilities

timing semantics

streak semantics

off-schedule behavior

existing-occurrence authority

existing-ledger reward fact recovery

type conversion limitation

per-entity semantic comparators

logical-group reconciliation

profile rebuild

cutover safety

Phase 3 compatibility extension

Phase 5 preflight boundary

distributed CloudKit limitation

Do not document future functionality as implemented.

======================================================================
25. PHASE 4 PROTECTED EXISTING BEHAVIOR
======================================================================

At the end of Phase 4, unless a narrow approved 4A correctness fix applies,
the existing user-visible app remains behaviorally the same.

Must preserve:

task creation

task metadata editing

legacy completion behavior

same-day count semantics

Priority Matrix

Statistics

notification semantics

delete/archive behavior

current navigation/UI

Phase 1 reward math

Phase 2 migration

Phase 3 atomic behavior transaction

Must NOT expose:

XP UI

Honk Coins UI

level UI

DuckState UI

wardrobe

weekly report UI

prediction UI

AI

subscription

Live HabitService completion must still NOT call the gamified transaction.

======================================================================
26. TESTING STANDARD FOR EVERY SUB-PHASE
======================================================================

Before changes:

git status

record HEAD

preserve user/unrelated work

fresh full HabitHonkerTests run

record:

executed
passed
failed
skipped
exit code
command

Historical numbers must not replace fresh baseline.

If baseline fails:

STOP.

Do not "repair" unrelated failures silently.

------------------------------------------------------------
During implementation
------------------------------------------------------------

Run focused new tests.

Where a current bug is claimed, prefer a failing-first characterization test.

Do not weaken old assertions to get green.

If an old architectural guard is intentionally superseded by approved Phase
4 responsibility:

narrow it precisely

document why

leave unrelated protections intact

------------------------------------------------------------
After implementation
------------------------------------------------------------

Run targeted sub-phase tests.

Run FULL HabitHonkerTests.

Compare baseline test identities, not only counts.

Run:

git status --short
git diff
git diff --stat
git diff --check

Audit every changed production file.

Ensure no unrelated feature drift.

======================================================================
27. FINAL PHASE 4 ACCEPTANCE GATE
======================================================================

PHASE 4 IS COMPLETE ONLY IF EVERY CONDITION BELOW IS TRUE.

------------------------------------------------------------
27.1 4A PASS
------------------------------------------------------------

Metadata updates cannot erase completion history.

Priority edits cannot erase records.

Metadata updates do not resurrect deleted tasks.

Create/update semantics are explicit.

Legacy completion no longer depends on stale whole-model upsert behavior.

Any newly-created HabitRecord orphan bug is prevented.

All legacy behavior regressions pass.

------------------------------------------------------------
27.2 4F PASS
------------------------------------------------------------

Storage mode is explicit in DI.

durableCloud is identified correctly.

durableLocal is genuinely persistent and CloudKit-disabled.

durableLocal does not require network/iCloud.

ephemeral fallback is distinguishable.

Gamification durable mutations are gated from ephemeral storage.

No automatic gamification side effects occur from dependency construction.

------------------------------------------------------------
27.3 4C PASS
------------------------------------------------------------

Occurrence identity is deterministic.

One-time lifetime identity is stable.

Repeating day identity is stable.

Baseline revision ID is deterministic.

LocalDay is DST-safe.

Identity is locale-independent.

No hidden current timezone/calendar.

------------------------------------------------------------
27.4 4B PASS
------------------------------------------------------------

Official gamification schedule history does NOT predate enrollment.

Post-enrollment planning-relevant metadata produces revision history.

Metadata + revision mutation is atomic.

Non-planning metadata does not create revisions.

Delete/restore schedule lifecycle is represented where supported.

No reward/occurrence side effects.

------------------------------------------------------------
27.5 4E PASS
------------------------------------------------------------

Gamification enrollment is explicit.

No automatic live launch enrollment yet.

Enrollment works on durableCloud.

Enrollment works on durableLocal.

Enrollment rejects ephemeral fallback.

Profile starts at zero.

trackingStartedAt is explicit.

Gregorian/fixed timezone policy is explicit.

Baseline revisions are atomic with profile creation.

No retroactive XP.

No retroactive occurrences.

No retroactive streak.

No ledger reward.

------------------------------------------------------------
27.6 4D PASS
------------------------------------------------------------

OccurrencePlanner produces all facts required by Phase 3.

Scheduled/off-schedule/one-time policies are explicit.

Timing timestamp evaluation works.

×1.10 timing rule remains unchanged.

No late penalty.

Streak calculation respects scheduled occurrences and enrollment boundary.

Existing occurrence snapshot is authoritative.

Existing reward facts are recovered from ledger rather than repriced.

Priority/reminder edits after first completion do not break same occurrence.

Type-transition ambiguity is rejected, not guessed.

Planner is pure/deterministic.

No live cutover.

------------------------------------------------------------
27.7 4G PASS
------------------------------------------------------------

Per-entity semantic comparators exist.

Compatible duplicate profiles form one logical profile.

Every compatible profile projection is normalized identically.

Earliest enrollment Hybrid B+C policy is implemented.

Deterministic baseline revision IDs converge.

Identical logical ledger duplicates count once.

Conflicting ledger payload is a financial conflict.

Compatible occurrence duplicates form one logical occurrence.

Conflicting immutable occurrence snapshots remain conflicts.

Identical event receipts deduplicate logically.

Conflicting receipts remain conflicts.

Compatible revision duplicates converge logically.

Conflicting schedule histories remain unsafe.

Ambiguous legacy-day physical records are not guessed/merged.

Profile rebuild is deterministic.

Reconciliation is idempotent.

No immutable reward history is destructively rewritten.

Phase 3 accepts compatible logical groups where explicitly approved.

Phase 3 still rejects real semantic conflicts.

Cutover-safety result is available.

------------------------------------------------------------
27.8 NO SCHEMA DRIFT
------------------------------------------------------------

Still Schema V2.

No new @Model.

No V3 migration.

No persisted-property mutation.

------------------------------------------------------------
27.9 NO PHASE 5 CUTOVER
------------------------------------------------------------

Live HabitService completion remains legacy.

No live XP award.

No live coin award.

No user-visible gamification.

------------------------------------------------------------
27.10 FULL REGRESSION
------------------------------------------------------------

Every Phase 1 test passes.

Every Phase 2 migration/persistence test passes.

Every Phase 3 atomic transaction test passes.

Every new 4A/F/C/B/E/D/G test passes.

Existing statistics tests pass.

Existing notification tests pass.

Existing completion tests pass.

Existing delete/archive tests pass.

Final full HabitHonkerTests suite:

0 Phase-4-caused failures

0 Phase-4-caused skipped tests

======================================================================
28. REQUIRED FINAL PHASE 4 REPORT
======================================================================

After 4G and the full final regression create:

Docs/GamificationPhase4Report.md

Structure:

# Gamification Phase 4 Final Report

## 1. Status

PASS / PARTIAL / FAIL

## 2. Starting baseline

Commit
Test command
Executed/passed/failed/skipped

## 3. 4A Metadata Safety

What changed
Protocols
Tests
Result

## 4. 4F Storage Durability

Actual old local configuration
Final local configuration
CloudKit-disabled proof
Protocols
Tests

## 5. 4C Identity

Canonical formats
LocalDay rules
Tests

## 6. 4B Schedule Revisions

Enrollment boundary
Revision fields
Atomicity
Tests

## 7. 4E Enrollment

Profile policy
Baseline revisions
Hybrid B+C preparation
Tests

## 8. 4D Planner

Inputs
Outputs
Timing
Streak
Existing occurrence
Ledger fact recovery
Type-conversion handling
Tests

## 9. 4G Reconciliation

Semantic comparators
Logical groups
Profile rebuild
Conflicts
Hybrid B+C
Phase 3 compatibility extension
Tests

## 10. Architecture / DI

List every new protocol.

For each:

responsibility
consumer
implementation
dependencies

Show final dependency graph.

## 11. Existing production files changed

For every existing file:

path
symbol
reason
behavior effect

## 12. New files

Path
responsibility

## 13. Schema

Explicitly confirm:

Schema V2 unchanged
No @Model added
Migration plan unchanged

## 14. Baseline vs final tests

Baseline

Per-subphase targeted suites

Final full suite

## 15. Production behavior verification

Explicitly answer:

Did live HabitService completion cut over?
NO

Does live app award XP?
NO

Does live app award Honk Coins?
NO

Does AppDependencies construction auto-enroll?
NO

Can durableLocal work without CloudKit?
YES / NO

Are metadata writes safe?
YES / NO

Is occurrence identity deterministic?
YES / NO

Is enrollment explicit?
YES / NO

Can planner build Phase 3 normalized commands?
YES / NO

Can reconciliation distinguish compatible duplicates from true conflicts?
YES / NO

Can profile cache be rebuilt safely?
YES / NO

## 16. Known limitations

Only actual remaining limitations.

## 17. Phase 5 readiness

READY FOR PHASE 5 LIVE CUTOVER:
YES / NO

If NO:
list exact blockers.

Do NOT implement Phase 5.

======================================================================
29. REQUIRED PROTOCOL / SERVICE AUDIT AT PHASE 4 END
======================================================================

The exact naming may vary with current project conventions, but the final
architecture must have explicit testable responsibility boundaries covering:

metadata-safe Habit persistence

storage durability state/provider

occurrence identity

schedule revision planning

schedule revision persistence

gamification enrollment service

enrollment persistence

behavior planning reads

occurrence planning

timing evaluation if kept as an independent responsibility

gamification reconciliation service

reconciliation persistence/logical grouping

Phase 3 behavior transaction

GamificationService

RewardCalculator

LevelCalculator

Do not create one protocol per class mechanically.

The audit question is:

"Can every important business responsibility be independently tested and
injected without exposing SwiftData?"

======================================================================
30. FINAL SYSTEM EXPECTED AFTER PHASE 4
======================================================================

The running app should STILL look basically the same.

Internally the architecture should now be capable of:

safe metadata persistence
+
true durable local/offline storage
+
durable Cloud store classification
+
explicit gamification enrollment
+
fixed scheduling timezone/calendar
+
deterministic occurrence IDs
+
deterministic baseline revision IDs
+
historical schedule revisions from enrollment onward
+
streak planning
+
off-schedule eligibility planning
+
timestamp timing verification
+
one-time lifetime occurrence planning
+
existing occurrence frozen-fact reuse
+
semantic Cloud duplicate comparison
+
compatible multi-device logical convergence
+
profile cache rebuild
+
typed cutover safety assessment

But the engine is NOT live yet.

The final pre-Phase-5 architecture should conceptually be:

                       ┌────────────────────┐
                       │   Habit metadata   │
                       └─────────┬──────────┘
                                 │
                           ScheduleRevision
                                 │
                                 ▼
┌─────────────┐        ┌───────────────────┐
│ Enrollment  │───────▶│ Planning Policy   │
└─────────────┘        └─────────┬─────────┘
                                 │
                       OccurrenceIdentity
                                 │
                                 ▼
                       OccurrencePlanner
                                 │
                                 ▼
                     normalized completion
                                 │
                     [NOT LIVE CONNECTED]
                                 │
                                 ▼
                 Phase 3 Atomic Transaction
                                 │
             ┌───────────────────┼─────────────────┐
             ▼                   ▼                 ▼
        Occurrence             Event             Ledger
                                                   │
                                                   ▼
                                                Profile

Cloud/local durability and reconciliation surround this system.

Phase 5 will connect the user completion action to it.

======================================================================
31. HOW YOU MUST EXECUTE THIS MASTER CONTRACT
======================================================================

DO NOT implement Phase 4 in one giant run.

FIRST RUN:

Implement ONLY Phase 4A.

At the end return:

PHASE 4A STATUS:
PASS / PARTIAL / FAIL

Fresh baseline:
X executed / X passed / X failed / X skipped

Targeted 4A:
X / X / X / X

Final full suite:
X / X / X / X

Production files changed:
...

New files:
...

Schema changed:
YES / NO

Live gamification enabled:
YES / NO

Known deviations:
...

Report:
Docs/GamificationPhase4AReport.md

READY FOR 4F:
YES / NO

STOP.

Do not begin 4F.

When explicitly told:

"Continue HabitHonker Exp v1.1.1 Phase 4 with 4F"

then:

read the master architecture contract
read 4A report
inspect current source
run a fresh baseline
execute ONLY 4F
report
STOP

Repeat:

4A
4F
4C
4B
4E
4D
4G

At every stage:

Never continue from FAIL.

Never continue from PARTIAL without explicit user approval.

Never trust the presence of a report as proof that code passed.

Verify current source and current tests.

======================================================================
32. FINAL INSTRUCTION
======================================================================

For this invocation:

START WITH PHASE 4A ONLY.

Do not implement 4F yet.

Do not implement future sub-phases preemptively.

You may inspect later-phase code/models to avoid architectural mistakes,
but production changes must remain inside the authorized 4A scope.

At the end of 4A:

produce the required report,
show the gate result,
and STOP.