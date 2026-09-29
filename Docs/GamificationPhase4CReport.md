# Gamification Phase 4C Report

Occurrence identity + local day (HabitHonker Exp v1.1.2).

## 1. Status

**PHASE 4C STATUS: PASS**

`.phase4c/verify.sh` ran on the Mac on 2026-09-28, 17:51:02–17:52:54 PDT (Xcode 26.2, build 17C52; iPhone 17 Pro Max simulator, iOS 26.0, `24629C99-E950-4563-BA70-118CE5D96451`):

```sh
bash /Users/Vlad/Development/habitHonker/.phase4c/verify.sh
```

| Run | Exit | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|---:|
| Baseline (`8fa4fcf`, worktree) | **0** | 141 | 141 | 0 | 0 |
| Targeted (`LocalDayTests` + `OccurrenceIdentityTests`) | **0** | 34 | 34 | 0 | 0 |
| Final (full `HabitHonkerTests`, 4C working tree) | **0** | 175 | 175 | 0 | 0 |
| `git diff --check` (tracked; and including new files) | | | | | **clean** (see §16) |

**Verification fixes (test file only; no production code touched):**

1. **Compile fix in `OccurrenceIdentityTests.testI9DaylightSavingChangesDurationNotKeyFormat`.** `days.map(\.duration)` is `[TimeInterval]` (`[Double]`), but the expected literal `[23 * 3600, 24 * 3600, 25 * 3600]` was inferred as `[Int]`. The expected array is now declared `let expectedDurations: [TimeInterval] = [23 * 3_600, 24 * 3_600, 25 * 3_600]`. `LocalDay.duration`, `GregorianLocalDayCalculator` and the identity code are unchanged, and nothing is cast to `Int`. The test file was last saved at 17:49:55 PDT, before the 17:51 run, so all three runs above include this fix.
2. **Whitespace fix.** The 17:51 run's `git diff --check` including new files reported one finding: trailing whitespace on the blank line 263 of `OccurrenceIdentityTests.swift`, which was introduced by fix 1. The spaces were removed (the blank line stays). After this edit, both diff checks, the tracked-changes check and the production-consumer check were rerun at 18:10 PDT and are clean. This edit changes only whitespace on an empty line, so the build and test results above still apply. The three xcodebuild runs were not repeated after it, because the machine that made the edit has no Xcode. A fresh `verify.sh` on the Mac will record all four checks in one run.

Note on `summary.txt`: its per-test list shows `MISSING LocalDayTests.testC1UTCNormalDay`. That is a log-interleaving artifact. In `targeted.log`, an xcodebuild debug line was written into the middle of that test's status line (`…testC1UTCNormalDay()' passe2026-09-28 17:52:17…`), so the text match failed. `targeted.xcresult` records the test as **Passed**, and the targeted count is 34/34.

## 2. Starting Commit

- `HEAD` = `8fa4fcf` (`8fa4fcfa1a5e0533e8dc8b736337041b7530bdcb`), "feat: establish durable storage modes", branch `experience-layer/initial`.
- Working tree before this run: clean (`git status --short` printed nothing).
- Working tree after this run: 7 new Swift files and this report, all untracked, plus the `.phase4c/` tooling (not to be committed). **No tracked file is modified.**

## 3. Fresh Baseline

**Exit 0: 141/141 passed.** `verify.sh` runs the complete `HabitHonkerTests` suite on a temporary `git worktree` of `HEAD` (`8fa4fcf`). The untracked 4C files are not in that worktree, so this is exactly the committed pre-4C code. If the baseline fails, the script stops and skips the 4C runs, as the contract requires.

```sh
xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
  -destination '<discovered>' -derivedDataPath <fresh temp dir> \
  -resultBundlePath .phase4c/logs/baseline.xcresult -only-testing:HabitHonkerTests
```

- **Destination:** the script reads the scheme's eligible destinations (`xcodebuild -showdestinations`). It uses the simulator Phase 4F was verified on (`24629C99-E950-4563-BA70-118CE5D96451`) if it is still listed, otherwise the iPhone simulator with the newest iOS. `DEST=...` overrides it.
- **Destination used:** `platform=iOS Simulator,id=24629C99-E950-4563-BA70-118CE5D96451` (iPhone 17 Pro Max, iOS 26.0: the Phase 4F simulator).
- **Xcode version:** Xcode 26.2 (17C52).

| Run | Destination | Xcode | Executed | Passed | Failed | Skipped | Exit |
|---|---|---|---:|---:|---:|---:|---:|
| Baseline (`8fa4fcf`) | iPhone 17 Pro Max, iOS 26.0 | 26.2 (17C52) | 141 | 141 | 0 | 0 | **0** |

## 4. Identity Contract Implemented

| Key | Exact format | Produced by |
|---|---|---|
| Profile | `profile:v1:default` | `BehaviorLogicalIdentity.defaultProfileKey` |
| Repeating occurrence | `occ:v1:<target uuid>:day:<YYYY-MM-DD>` | `OccurrenceIdentityV1.repeatingOccurrenceID(targetID:localDay:)` |
| One-time occurrence | `occ:v1:<target uuid>:once` | `OccurrenceIdentityV1.oneTimeOccurrenceID(targetID:)` |
| Enrollment baseline revision | `rev:v1:<target uuid>:baseline` | `BehaviorLogicalIdentity.baselineRevisionID(targetID:)` |

- **UUID normalization.** `BehaviorLogicalIdentity.canonicalUUIDText(_:)` returns `uuid.uuidString.lowercased()`. All three target-derived keys use it, so the rule exists in one place. `A0B1C2D3-E4F5-4678-9ABC-DEF012345678` becomes `a0b1c2d3-e4f5-4678-9abc-def012345678`. No `description`, localized formatting, `hashValue` or `Hasher` is involved.
- **Frozen examples** (asserted exactly in the tests):
  - `occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-28`
  - `occ:v1:123e4567-e89b-12d3-a456-426614174000:once`
  - `rev:v1:123e4567-e89b-12d3-a456-426614174000:baseline`
- **Version.** `v1` is literal text in each format. No API takes a version argument, and callers cannot produce `v2`. A future version is a new type (for example `OccurrenceIdentityV2`), not a parameter.
- **Inputs.** Repeating: `BehaviorTargetID` + `LocalDay`. One-time: `BehaviorTargetID` only. Baseline: `BehaviorTargetID` only. There is no parameter for a due date, completion time, priority, title, icon, notification state, schedule revision, completion count, streak, reward policy or physical row id. Identity is never built from `HabitModel`.
- **No time zone in the key.** The key names the civil date only. Which zone governs gamification is the profile's decision (Phase 4E), not this layer's. The same instant can therefore give two different keys under two zones (C29). Two zones that agree on the date give the same key.

**Invariants** (documented on `OccurrenceIdentifying`):

| | Invariant | Tests |
|---|---|---|
| I1 | same target + same civil date → same key | C20, C22 |
| I2 | same target + different date → different key | C23 |
| I3 | same date + different target → different key | C24 |
| I4 | one-time key unaffected by due-date changes | C25 |
| I5 | deterministic across new instances | C14, C22, C30 |
| I6 | locale cannot change output | C15, C21 (ASCII-only keys), guard |
| I7 | device `Calendar.current` cannot change output | C16, guard |
| I8 | device time zone cannot change interpretation | `testI8…`, C3, C29, guard |
| I9 | DST changes duration, not key format | `testI9…`, C6, C7 |
| I10 | physical row id unrelated to identity | C26 (no such input), C30 (only the target UUID appears in a key) |

## 5. LocalDay Contract

- **Value.** `LocalDay` is a struct with `year`, `month`, `day`, `timeZoneIdentifier` (exactly as supplied), `start`, `end`, `canonicalKey`, `contains(_:)`, `interval` and `duration`. It is `Equatable` and `Sendable`. It is not `Codable`, because nothing needs it yet.
- **Only the calculator creates one.** The initializer is `fileprivate`. `GregorianLocalDayCalculator` lives in the same file and is the only producer, so every `LocalDay` is a validated Gregorian date with calculated bounds.
- **Gregorian policy.** Every call builds `Calendar(identifier: .gregorian)` and assigns `TimeZone(identifier:)` for the requested zone. The locale is pinned to `en_US_POSIX`; it does not affect the numeric components used. `Calendar.current`, `Calendar.autoupdatingCurrent`, `TimeZone.current` and `Locale.current` are never read.
- **Time zone input.** An identifier string, because profile and revision rows store identifiers. An unknown identifier throws `LocalDayError.invalidTimeZoneIdentifier(id)`. There is no fallback to UTC, GMT or the device zone.
- **Entry points.** `localDay(containing:timeZoneIdentifier:)` and `localDay(year:month:day:timeZoneIdentifier:)`.
- **Strict validation.** The components are resolved to a date and read back. Year, month and day must match exactly, so February 30 is rejected, never turned into March 2.
- **Supported years: 1583…9999.** Foundation's `.gregorian` calendar is really Julian before 15 October 1582, so an earlier date would not be a Gregorian date. A 1500-02-29, for example, exists only in the Julian calendar. The upper bound keeps every key at `YYYY-MM-DD`.
- **Canonical key.** Zero-padded integer text (`2026-01-03`, `2028-02-29`), plain ASCII, no formatter.
- **Boundaries.** `start` = start of the civil day. `end` = start of the *next* civil day, found with `calendar.date(byAdding: .day, value: 1, to: start)` followed by `startOfDay`. There is no fixed number of seconds anywhere. The `startOfDay` step also handles zones where midnight itself is skipped.
- **Half-open membership.** `contains(date)` is explicitly `date >= start && date < end`. `interval` (`DateInterval`) is a convenience only.
- **DST.** In `America/Los_Angeles`, 2026-03-08 is 23 hours and 2026-11-01 is 25 hours; see §10.
- **Errors** (`LocalDayError`, `Equatable`, `Sendable`):
  - `invalidTimeZoneIdentifier(String)`
  - `invalidGregorianDate(year:month:day:)`: a date that does not exist, or a year outside 1583…9999.
  - `unrepresentableInstant(Date)`: a non-finite `Date`, or an instant whose civil year is outside 1583…9999.
  - Not added: `unsupportedCalendar`, because the calendar is not an input. `invalidIdentityInput`, because identity inputs are typed and cannot be invalid. UUID formatting never throws.
- **Behavior notes.** A civil date that a zone skipped entirely (for example `Pacific/Apia` 2011-12-30) has no instants there, so it is rejected as `invalidGregorianDate` for that zone. `LocalDay` equality includes the identifier string as supplied, so two aliases of one zone give unequal `LocalDay`s with equal keys.

## 6. New Protocols

| Protocol | Responsibility | Implementation | Why the boundary exists |
|---|---|---|---|
| `LocalDayCalculating` | Instant or date components + explicit zone → `LocalDay` | `GregorianLocalDayCalculator` | Civil-day time math is its own business rule, with the calendar policy in one place. The 4D planner can take any calculator, so its tests can use fixed days. |
| `OccurrenceIdentifying` | Minimal facts → logical occurrence key | `OccurrenceIdentityV1` | Identity is a frozen compatibility contract, separate from time math. The version is explicit in the type name. The protocol's two signatures are frozen by a test. |

`BehaviorLogicalIdentity` is deliberately not a protocol. It is a namespace for fixed values: the profile key, the UUID text rule and the baseline key.

## 7. New Production Files

All under `HabitHonker/HabitHonker/`. Each imports only `Foundation`. Target membership is automatic (file-system-synchronized groups), so there is no `project.pbxproj` change. The repo keeps protocols in `Core/Protocols` and domain types in `Core/Domain`; there is no `Core/Services/Protocols`.

| Path | Responsibility |
|---|---|
| `Core/Domain/LocalDay.swift` | `LocalDay`, `LocalDayError`, `GregorianLocalDayCalculator` (together so only the calculator can create a `LocalDay`) |
| `Core/Protocols/LocalDayCalculating.swift` | Local-day calculation protocol |
| `Core/Protocols/OccurrenceIdentifying.swift` | Occurrence identity protocol and the I1–I10 invariants |
| `Core/Domain/OccurrenceIdentityV1.swift` | V1 occurrence keys |
| `Core/Domain/BehaviorLogicalIdentity.swift` | Canonical profile key, V1 UUID text rule, baseline revision key |

## 8. Existing Production Files Modified

**None.** No existing Swift file, project file, schema or configuration was changed. `AppDependencies` is not wired to the new types, because there is no production consumer until the later phases.

## 9. Test Matrix

New tests: `LocalDayTests` (17) and `OccurrenceIdentityTests` (17). All 34 **passed** in the targeted run and again in the final full-suite run (from `targeted.xcresult` and `final.xcresult`, 2026-09-28 17:51 PDT).

| # | Requirement | Test | Result |
|---|---|---|---|
| C1 | UTC normal day, `YYYY-MM-DD`, bounds | `LocalDayTests.testC1UTCNormalDay` | PASS |
| C2 | `2026-01-03` zero padding | `testC2SingleDigitMonthAndDayAreZeroPadded` | PASS |
| C3 | one instant: LA `2026-09-27`, Tokyo `2026-09-28` | `testC3SameInstantBelongsToDifferentCivilDaysInLosAngelesAndTokyo` | PASS |
| C4 | start belongs, end does not (end = next day's start) | `testC4StartBelongsAndEndBelongsToTheNextDay` | PASS |
| C5 | instant just before end belongs | `testC5InstantJustBeforeEndBelongsAndJustBeforeStartDoesNot` | PASS |
| C6 | 2026-03-08 LA is 23 h | `testC6SpringForwardDayInLosAngelesIs23Hours` | PASS |
| C7 | 2026-11-01 LA is 25 h | `testC7FallBackDayInLosAngelesIs25Hours` | PASS |
| C8 | normal LA day is 24 h | `testC8NormalLosAngelesDayIs24Hours` | PASS |
| C9 | 2026-12-31 → 2027-01-01 | `testC9YearBoundaryNextDayIsJanuaryFirst` | PASS |
| C10 | 2028-02-29 valid | `testC10LeapDayIsValid` | PASS |
| C11 | 2026-02-29 rejected | `testC11February29InANonLeapYearIsRejectedNotNormalized` | PASS |
| C12 | 2026-04-31 rejected (also Feb 30, month 0/13, day 0/32, years 0 and 10000, Julian-only 1500-02-29, 1582-10-10); 1583-01-01 accepted | `testC12ImpossibleDatesAreRejected` | PASS |
| C13 | invalid zone → typed error, both entry points | `testC13InvalidTimeZoneIdentifierIsATypedErrorWithoutFallback` | PASS |
| C14 | fresh calculators, identical `LocalDay` | `testC14FreshCalculatorsAndBothEntryPointsProduceIdenticalDays` | PASS |
| C15 | no `Locale.current` dependence | `testC15CanonicalKeyIsASCIIDigitsAndHyphensOnly` + guard | PASS |
| C16 | Gregorian regardless of device calendar | `testC16ResultIsGregorianWhateverOtherCalendarsSay` + guard | PASS |
| C17 | `profile:v1:default` exactly | `OccurrenceIdentityTests.testC17CanonicalProfileKeyIsExact` | PASS |
| C18 | `rev:v1:<lowercase uuid>:baseline` exactly | `testC18BaselineRevisionIDIsExact` | PASS |
| C19 | `occ:v1:<lowercase uuid>:once` exactly | `testC19OneTimeOccurrenceIDIsExact` | PASS |
| C20 | `occ:v1:<lowercase uuid>:day:2026-09-28` exactly | `testC20RepeatingOccurrenceIDIsExact` | PASS |
| C21 | alphabetic hex lowercased in every key | `testC21AlphabeticHexDigitsAreLowercasedInEveryKey` | PASS |
| C22 | same target + day across independent instances | `testC22SameTargetAndDayGiveTheSameKeyAcrossIndependentInstances` | PASS |
| C23 | neighboring day → different key | `testC23NeighboringDaysGiveDifferentKeys` | PASS |
| C24 | different target → different key | `testC24DifferentTargetsOnTheSameDayGiveDifferentKeys` | PASS |
| C25 | one-time ignores due-date edits; no due-date input exists | `testC25OneTimeIdentityIgnoresDueDateEdits` | PASS |
| C26 | repeating ignores priority/title/notification/schedule; those inputs do not exist | `testC26RepeatingIdentityIgnoresPriorityTitleNotificationAndSchedule` | PASS |
| C27 | leap-date key | `testC27LeapDayOccurrenceKey` | PASS |
| C28 | year-boundary keys | `testC28YearBoundaryOccurrenceKeys` | PASS |
| C29 | one instant, two zones → two days → two keys | `testC29OneInstantUnderTwoZonesGivesTwoDaysAndTwoKeys` | PASS |
| C30 | no UUID in a key except the supplied target | `testC30KeysContainNoUUIDOtherThanTheSuppliedTarget` + guard | PASS |
| + | non-finite instant → typed error | `LocalDayTests.testNonFiniteInstantIsATypedError` | PASS |
| + | I8: device time zone change | `testI8DeviceTimeZoneChangesDoNotChangeDaysOrKeys` | PASS |
| + | I9: DST keeps key format | `testI9DaylightSavingChangesDurationNotKeyFormat` | PASS |
| + | purity guard | `testGuardPhase4CFilesArePureFoundationWithoutDeviceStateHashingOrRandomness` | PASS |

How C25/C26 prove that an input does not exist:

- **Compile time.** The tests bind `OccurrenceIdentityV1.oneTimeOccurrenceID(targetID:)` and `…repeatingOccurrenceID(targetID:localDay:)` to their exact function types. Adding any parameter breaks the test build.
- **Source.** The protocol and the V1 type must each declare exactly the two expected signatures.

## 10. DST Verification

Expected values. They are asserted exactly in the tests and were cross-checked in this run against the IANA tz database (Python `zoneinfo`). **Test result: PASS** (C6, C7, C8 and `testI9…` passed).

| Day (America/Los_Angeles) | start (UTC) | end (UTC) | Length | Also asserted | Test |
|---|---|---|---|---|---|
| 2026-03-08 spring-forward | 08:00 (00:00 PST) | 2026-03-09 07:00 (00:00 PDT) | 23 h | 01:59 PST and 03:00 PDT are both inside | C6 |
| 2026-11-01 fall-back | 07:00 (00:00 PDT) | 2026-11-02 08:00 (00:00 PST) | 25 h | both 01:30s (08:30Z, 09:30Z) map to this day | C7 |
| 2026-09-28 normal | 07:00 | 2026-09-29 07:00 | 24 h | | C8 |

The key format stays `YYYY-MM-DD` on all three days (`testI9…`).

## 11. Timezone Verification

**Test result: PASS** (C3, C13, C29 and `testI8…` passed).

- **Same instant, two zones (C3, C29).** `2026-09-28T05:30:00Z` is 22:30 on Sep 27 in Los Angeles, so the key is `2026-09-27`. In Tokyo it is 14:30 on Sep 28, so the key is `2026-09-28`. The repeating IDs are `occ:v1:123e4567-…:day:2026-09-27` and `…:day:2026-09-28`. At `2026-09-28T12:00:00Z` both zones say Sep 28, so the keys are equal.
- **Device zone (I8).** The test switches the process default time zone to `Pacific/Kiritimati` (+14), `Pacific/Pago_Pago` (−11), `Asia/Kolkata` and `Europe/London`. The Los Angeles day and key for the same instant must stay identical. The original default is restored afterwards.
- **Invalid identifiers (C13).** `Mars/Olympus_Mons`, `""` and `Not A Zone` throw `invalidTimeZoneIdentifier` from both entry points. There is no fallback.

## 12. Purity Audit

For the five new files. Checked in this run by scanning the source. The guard test enforces the same checks on every test run (passed in the targeted and final runs).

| Question | Answer |
|---|---|
| SwiftData imported? | **NO** |
| SwiftUI imported? | **NO** |
| `Calendar.current`? | **NO** |
| `TimeZone.current`? | **NO** |
| `Locale.current`? | **NO** |
| `Hasher` / `hashValue`? | **NO** |
| Random UUID used for logical keys? | **NO** |

The guard (`testGuard…`) requires that `import Foundation` is each file's only import. It also rejects:

- other frameworks: CloudKit, Combine, UIKit, CoreData
- persistence: `ModelContext`, `ModelContainer`, `@Model`, `FetchDescriptor`, `UserDefaults`
- device settings: `*.autoupdatingCurrent`, `NSCalendar`, `NSTimeZone`, `NSLocale`
- text conversion: `DateFormatter`, `String(format`, `.description`, `String(describing`
- UUID construction: any `UUID(` (UUID as a type is fine), `NSUUID`
- clock reads and fixed seconds: `Date()`, `Date.now`, `Date(timeInterval…`, `addingTimeInterval`, `86400` / `86_400`
- the word "random"

It also checks that the one calendar in `LocalDay.swift` is `Calendar(identifier: .gregorian)` with `TimeZone(identifier: timeZoneIdentifier)`, and that the day's end comes from `date(byAdding: .day, value: 1, …)`. The scan is limited to these five files. It is not an app-wide `UUID()` ban.

## 13. Schema Verification

| Question | Answer |
|---|---|
| Schema V2 changed? | **NO** |
| Migration plan changed? | **NO** |
| `@Model` added? | **NO** |

No tracked file changed; `verify.sh` re-checks this.

## 14. Persistence Side Effects

| Does identity construction create… | Answer |
|---|---|
| TaskOccurrence? | **NO** |
| ScheduleRevision? | **NO** |
| BehaviorEvent? | **NO** |
| Profile? | **NO** |
| Ledger? | **NO** |

The new code has no persistence dependency at all. It consists of pure functions that return values and strings.

## 15. Production Behavior Verification

| Question | Answer |
|---|---|
| Did `HabitService.completeHabit` change? | **NO** |
| Did live XP turn on? | **NO** |
| Did live coins turn on? | **NO** |
| Did storage behavior change? | **NO** |

No existing file changed. No production file outside the five new ones references the new types (checked by `grep` in this run; `verify.sh` repeats it).

## 16. Tests

| Run | Scope | Result |
|---|---|---|
| Baseline | full `HabitHonkerTests` on `8fa4fcf` (worktree) | **exit 0**: 141 executed, 141 passed, 0 failed, 0 skipped (TEST SUCCEEDED) |
| Targeted | `LocalDayTests` + `OccurrenceIdentityTests` (34 tests, guards included) | **exit 0**: 34 executed, 34 passed, 0 failed, 0 skipped (TEST SUCCEEDED) |
| Final | full `HabitHonkerTests` on the 4C working tree | **exit 0**: 175 executed, 175 passed, 0 failed, 0 skipped (TEST SUCCEEDED; 141 existing + 34 new) |
| `git diff --check` | tracked changes | **clean** (17:52 run and 18:10 recheck; there are no tracked changes) |
| `git diff --check` including new files | the 8 new files, through a throwaway index | **clean** at the 18:10 recheck, after the whitespace fix in §1. The 17:52 run flagged trailing whitespace on `OccurrenceIdentityTests.swift:263`. |
| Tracked files changed vs `HEAD` | | **none** |
| Production references to the 4C layer outside its five files | | **none** |

Destination for all runs: iPhone 17 Pro Max simulator, iOS 26.0 (`24629C99-E950-4563-BA70-118CE5D96451`), Xcode 26.2 (17C52), fresh temporary derived data.

`verify.sh` also writes the xcresult counts (executed/passed/failed/skipped), the Xcode version and destination, and a PASS/FAIL line for each targeted test. It repeats both diff checks, the changed-files check and the no-consumer check. A finding in either of the last two also fails the script. Every run builds in fresh temporary derived data. Everything goes to `.phase4c/logs/summary.txt`.

## 17. Known Limitations

- **The xcodebuild runs predate a whitespace-only edit** (§1, fix 2). The diff checks were rerun after it; the three test runs were not. A fresh `verify.sh` on the Mac records everything in one run.
- **`summary.txt` per-test list shows one false MISSING** (C1) because of log interleaving; the xcresult bundle records it as passed (§1).
- **Locale and device calendar cannot be changed inside a test process.** No API exists for that, so I6 and I7 are proven by the source guard plus the ASCII-key (C15, C21) and cross-calendar (C16) tests. The device time zone *can* be changed in-process, so I8 is also tested behaviorally.
- **Years 1583…9999 only.** Foundation's Gregorian calendar is Julian before October 1582, and the key has exactly four year digits. Anything outside that range is a typed error.

## 18. Final Gate

Definition of done (§36), current state:

- **Done in code:**
  - LocalDay is a pure value, with explicit Gregorian calendar and explicit time zone.
  - No silent zone fallback.
  - Deterministic `YYYY-MM-DD`, half-open interval, no 86 400-second arithmetic.
  - One canonical profile key; exact one-time, repeating and baseline formats; lowercase UUID text frozen by tests.
  - One-time identity has no due-date input; repeating identity takes only target + LocalDay.
  - No SwiftData, UI, current-calendar or current-zone dependency; no Hasher; no random UUID; no persistence write.
  - No AppDependencies integration; schema V2 unchanged; `git diff --check` clean; this report.
- **Verified by execution** (`verify.sh`, 2026-09-28 17:51 PDT):
  - fresh baseline green: exit 0, 141/141
  - spring-forward, fall-back, leap and year-boundary tests green
  - Phase 1–4F regressions green: all 141 pre-existing tests pass in the final run
  - targeted 4C tests green: exit 0, 34/34
  - full `HabitHonkerTests` green: exit 0, 175/175
  - `git diff --check` clean (tracked, and including new files after the whitespace fix)

**PHASE 4C STATUS: PASS**

**READY FOR PHASE 4B: YES**

`.phase4c/` is verification tooling and is not to be committed.

STOP.
