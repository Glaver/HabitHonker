# Claude Execution Prompt — HabitHonker Exp v1.1.2 Phase 4

You are now the IMPLEMENTATION EXECUTOR.

Do not return another roadmap review.
Do not return another list of product questions.
Do not spend the response re-auditing decisions that are already frozen.

The architecture and product decisions are in:

- `Docs/HabitHonkerExp-v1.1.2.md`
- `Docs/GamificationTransactionContract.md`
- `Docs/GamificationPhase3Report.md`
- `Docs/GamificationArchitectureInvestigation.md`

Read them, inspect the current source, and WRITE CODE.

The user has explicitly approved HabitHonker Exp v1.1.2.

If the repository contradicts a frozen rule in a way that makes implementation impossible without:
- changing SwiftData Schema V2,
- destructive data migration,
- violating Phase 1 reward math,
- violating Phase 3 atomicity,
then STOP and report the concrete blocker.

Otherwise IMPLEMENT.

Do not stop merely because you discovered another edge case.
Use the frozen v1.1.2 policy.

============================================================
PHASE 4 STATUS / ORDER
============================================================

Phase 1: COMPLETE / FROZEN
Phase 2: COMPLETE / FROZEN
Phase 3: COMPLETE / FROZEN

Phase 4 order:

4A Metadata-safe persistence
4F Durable/true local storage
4C Occurrence identity
4B Schedule revision foundation
4E Profile enrollment
4D Occurrence planner + timing/streak bridge
4G Reconciliation/logical multiplicity

Each sub-phase must have:
- fresh baseline,
- code implementation,
- focused tests,
- full regression,
- report,
- clear PASS/FAIL gate.

Do not implement Phase 5 live cutover.

For THIS RUN:
IMPLEMENT 4A NOW.

Do not answer with "4A is ready".
Do not answer with a proposed prompt.
Do not only describe what you would change.
Make the changes in the repository.

============================================================
GLOBAL HARD RULES
============================================================

- No SwiftData Schema V3 in Phase 4.
- No new @Model.
- No persisted V2 property change.
- No reward formula duplication.
- No UI gamification.
- No live XP/coin cutover.
- No mutable global singleton.
- No service locator.
- Use explicit DI.
- Keep SwiftData behind persistence adapters/repository actor.
- Preserve one shared `HabitsRepositorySwiftData` actor for serialized persistence.
- Do not invent conflict winners.
- No financial "fetch.first".
- No destructive ledger deduplication.
- No hidden Date()/Calendar.current/TimeZone.current inside pure planners.
- Preserve Statistics and notification behavior except narrowly required integrity fixes.

============================================================
FROZEN v1.1.2 POLICIES YOU MUST NOT REOPEN
============================================================

1. Multi-device enrollment:
   earliest valid enrollment defines canonical trackingStartedAt;
   timezone/calendar from that earliest enrollment;
   deterministic baseline revision ID:
   `rev:v1:<targetUUID>:baseline`.

2. Compatible duplicate profiles:
   represent one logical profile;
   reconciliation rebuilds and updates ALL compatible physical profile projections;
   do not delete them merely for duplication.

3. Per-entity semantic comparators:
   financial ledger conflicts are hard conflicts;
   physical duplication alone is not.

4. Timing:
   timing reward is +10% XP only;
   no lateness penalty;
   an explicit meaningful timed task is required;
   in current V1.1.2, `notificationEnabled == true` is the approved proxy;
   otherwise timing is `.unavailable` and multiplier is ×1.00.

5. Store scope:
   one profile per durable store/container;
   local and Cloud stores are separate worlds;
   no automatic cross-store merge.

6. True local mode:
   `durableLocal` must explicitly disable CloudKit and work offline.

7. Legacy streak bridge:
   an unambiguous post-enrollment scheduled completion handled through legacy flow is NEUTRAL:
   it neither extends nor breaks streak;
   no retro XP/coins/occurrence/event/ledger backfill.

8. Metadata vs revision conflict:
   current Habit metadata still saves;
   unsafe revision is deferred, not fabricated;
   target becomes derivably `notCutoverSafe`.

9. Store continuity:
   disabling CloudKit must not silently open a new empty store.
   Preserve the intended existing store/data or STOP 4F for explicit migration design.

10. Timezone identity:
    never rename an occurrence logical ID because canonical enrollment timezone changed.
    If canonical policy would produce another day key, mark `occurrenceIdentityConflict`.

11. Required legacy day:
    only legacy data needed for current completion/streak/reference may block cutover.
    Unrelated old anomalies are diagnostics.

============================================================
4A — IMPLEMENT NOW
============================================================

GOAL:
Eliminate broad metadata writes that can replace completion history.

Current metadata mutation and legacy completion history must become separate responsibilities.

Inspect first:
- HabitMapper
- HabitRepositoryProtocol
- SwiftDataHabitRepository
- HabitsRepositorySwiftData
- HabitService / protocol
- HabitListViewModel
- HabitListView create/edit routing
- PriorityMatrixViewModel
- HabitDetailView
- notification save/reconcile flow
- delete/archive flow
- all existing spies/tests using upsert/saveHabit

PRE-FLIGHT:
1. `git status --short`
2. record HEAD
3. do not touch unrelated user work
4. run the complete HabitHonkerTests target
5. record executed/passed/failed/skipped/exit code
6. if baseline itself is broken, STOP with exact failure
7. otherwise continue directly into code changes

CHARACTERIZE THE BUG BEFORE FIX:
Add a focused test proving:
- load stale draft
- complete Habit
- save changed metadata from stale draft
- latest completion remains

If it unexpectedly already passes, inspect actual current source and explain why; do not force a fake failing test.

Also characterize whether repeated broad metadata saves actually create orphan HabitRecordSD rows.
Measure all HabitRecordSD rows, including rows whose inverse relationship is nil.
Do not assume old audit claim.

TARGET DOMAIN:
Introduce `HabitMetadata` or equivalent pure value containing all editable Habit fields EXCEPT completion history.

TARGET PERSISTENCE API:
Use explicit semantics, project naming may vary:

- createHabit(...)
- updateMetadata(...)
- updatePriority(...)
- recordLegacyCompletion(...)

CREATE:
- existing ID => typed alreadyExists
- never silently overwrite
- normal new Habit starts with correct empty/new record semantics

UPDATE METADATA:
- missing ID => typed notFound
- NEVER insert
- NEVER replace/recreate completion record collection
- return a freshly persisted HabitModel containing current authoritative records

UPDATE PRIORITY:
- only priority
- never rewrite records

RECORD LEGACY COMPLETION:
- execute in one repository actor operation
- explicit completion time
- explicit calendar
- one matching day record => checked increment, preserve record UUID/date
- no matching => insert
- do not perform unrelated metadata rewrite

MAPPER:
Split metadata application from record construction.
Normal metadata apply must not assign `sd.records`.
Keep creation/import/deleted conversion behavior explicit.
Do not break migration helpers.

PRODUCTION ROUTING:
Remove ambiguous production upsert where operation semantics are known.
Do not resurrect deleted tasks from a stale update.

HabitService:
- create operation uses create semantics
- metadata edit uses update semantics
- priority uses narrow priority semantics
- legacy complete uses narrow record completion operation where behavior remains equivalent
- publish existing transient events only after successful persistence

View model:
- creation and edit may require separate routes
- store the RETURNED fresh persisted model, not submitted stale draft
- preserve per-ID coordinator behavior
- preserve existing notification ordering unless a narrow no-resurrection notification fix is required

DELETE RACE:
delete
then queued stale update
=> update must fail notFound
=> no new HabitSD
=> no archive corruption
=> no orphan notification caused by the failed stale update

4A TESTS REQUIRED:
A1 stale Details draft cannot erase completion
A2 priority after completion preserves completion
A3 repeated title/icon/color/notification/schedule metadata changes preserve record IDs/dates/counts
A4 persistent HabitRecord row count does not grow from metadata saves
A5 if baseline orphan creation is proven, new path prevents new orphans
A6 deleted Habit cannot be resurrected by stale update
A7 create duplicate ID fails
A8 same-day legacy completion increments and preserves ID/date
A9 next local day creates new record
A10 supplied non-device calendar/timezone controls day grouping in repository test
A11 concurrency: metadata/priority operations do not lose committed legacy completions
A12 existing Statistics tests pass
A13 existing notification tests pass
A14 Phase 1–3 tests all pass

FILES / STRUCTURAL GUARDS:
If a Phase 3 structural source test depends on method placement, respect it.
New normal CRUD methods should be placed in the repository's approved CRUD area, not inside the Phase 3 transaction source-inspection window.

Update test doubles/spies to the new protocol API without weakening their behavioral assertions.

4A FORBIDDEN:
- no ScheduleRevision writes yet
- no profile enrollment
- no occurrence/event/ledger writes
- no Phase 3 gamified completion
- no SwiftData schema change
- no UI gamification

4A REPORT:
Create `Docs/GamificationPhase4AReport.md`.

Include:
- fresh baseline
- characterization evidence
- whether orphan hypothesis was true or false
- root cause
- API before/after
- all production files modified
- all tests added/updated
- targeted test result
- final full suite
- `git diff --check`
- remaining risks
- READY FOR 4F: YES/NO

If 4A is green:
STOP AFTER THE REPORT.
Do not implement 4F in this run.

============================================================
FUTURE 4F CONTRACT — DO NOT IMPLEMENT THIS RUN
============================================================

When later explicitly told to continue 4F:

- add explicit `durableCloud`, `durableLocal`, `ephemeralFallback`;
- pass storage durability through composition root / AppDependencies;
- inspect the REAL local ModelConfiguration;
- prove CloudKit is disabled in durableLocal;
- prove durableLocal works without network/iCloud assumptions;
- most importantly preserve existing intended persistent store/data.

Store continuity test:
seed current pre-4F intended store with Habit/records/archive/statistics data;
close;
open with proposed durableLocal;
verify exact data survives.

If safe same-store conversion is impossible:
STOP 4F.
Do not open a new empty store.
Do not invent unapproved store migration.

============================================================
FUTURE 4C CONTRACT — DO NOT IMPLEMENT THIS RUN
============================================================

Canonical IDs:
`profile:v1:default`
`occ:v1:<UUID>:day:<YYYY-MM-DD>`
`occ:v1:<UUID>:once`
`rev:v1:<UUID>:baseline`

LocalDay:
Gregorian
explicit profile timezone
half-open interval
DST safe
no DateFormatter identity
no Hasher

============================================================
FUTURE 4B CONTRACT — DO NOT IMPLEMENT THIS RUN
============================================================

Official schedule history begins at enrollment.

When history is trustworthy:
metadata + revision share one actor/context/save.

When revision history is unsafe:
SAVE CURRENT HABIT METADATA;
DO NOT fabricate revision;
return revisionDeferred/historyConflict;
target becomes derivably notCutoverSafe.

Duplicate open revisions:
never arbitrarily choose one.

============================================================
FUTURE 4E CONTRACT — DO NOT IMPLEMENT THIS RUN
============================================================

Explicit enrollment only.

No automatic launch call yet.

One actor/context/save:
profile zero balances
+
deterministic baseline revisions for active Habits

No retro reward/history.

Compatible duplicate enrollment follows earliest-enrollment Hybrid B+C.
Full normalization remains 4G.

============================================================
FUTURE 4D CONTRACT — DO NOT IMPLEMENT THIS RUN
============================================================

Planner produces normalized Phase 3 command facts.

Timing:
only explicit timed task (`notificationEnabled == true`) qualifies;
otherwise `.unavailable`.

Repeating:
scheduled occurrence eligible;
off-schedule ineligible.

One-time:
one lifetime occurrence.

Legacy post-enrollment completion:
neutral streak bridge when unambiguous.

Existing occurrence:
reuse frozen occurrence facts.

Existing rewarded occurrence:
recover `isOnTime` and policyVersion from ledger.

Occurrence under incompatible timezone identity:
do NOT rename;
mark unsafe.

Type transition ambiguity:
typed unsupported/conflict.

============================================================
FUTURE 4G CONTRACT — DO NOT IMPLEMENT THIS RUN
============================================================

Logical grouping, not physical-row assumptions.

Compatible duplicate profiles:
one logical profile; update all profile projections identically.

Identical ledger entitlement duplicates:
count once, never modify immutable rows.

Conflicting ledger:
financial conflict.

Compatible occurrences/events/revisions:
logical groups.

True semantic conflicts:
remain conflicts.

Required legacy ambiguity only blocks the current relevant path.

Metadata/revision mismatch from 4B:
target unsafe.

No arbitrary winner.
No destructive reward-history cleanup.

Narrow Phase 3 extension may accept compatible logical groups, but real conflicts must still fail.

============================================================
PHASE 4 FINAL DEFINITION OF DONE
============================================================

Phase 4 is only complete after 4A, 4F, 4C, 4B, 4E, 4D, 4G all PASS.

Final architecture must provide meaningful protocol/DI boundaries for:
- metadata-safe Habit persistence
- storage durability
- occurrence identity
- schedule revision planning/persistence
- enrollment
- planning reads
- occurrence planning
- timing evaluation (separate protocol only if useful)
- reconciliation
- existing Phase 3 transaction
- GamificationService/RewardCalculator/LevelCalculator

Final tests must prove:
- stale metadata cannot erase completion history
- no resurrection
- true durable local/offline mode
- store continuity
- deterministic DST-safe identities
- no pre-enrollment schedule history
- explicit enrollment/no retro rewards
- timestamp timing only for explicit timed tasks
- no lateness penalty
- neutral legacy streak bridge
- correct scheduled streak behavior
- existing occurrence frozen snapshot reuse
- no historical repricing
- duplicate semantic comparators
- compatible profile projection normalization
- identical ledger duplicate count-once
- conflicting financial history fail-safe
- occurrence timezone identity never renamed
- unrelated old legacy anomalies do not globally poison targets
- Phase 3 atomicity remains intact
- Schema V2 remains unchanged
- live HabitService is NOT cut over
- no user-visible XP/coins yet
- full HabitHonkerTests green

Final permanent docs after 4G:
- `Docs/HabitHonkerExp-v1.1.2.md`
- `Docs/BehaviorFoundationContract.md`
- reports for every Phase 4 sub-phase
- final `Docs/GamificationPhase4Report.md`

Final Phase 4 report must end with:

`READY FOR PHASE 5 LIVE CUTOVER: YES/NO`

Do not implement Phase 5.
