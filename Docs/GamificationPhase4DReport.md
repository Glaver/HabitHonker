# Gamification Phase 4D — Deterministic Occurrence Planner

## 1. Status

**PASS, including the November 1, 2026 semantic correction (America/Los_Angeles).** Validated inactive periods now return `noActiveRevision`; empty/pre-first/zero-length-only history remains deferred. Xcode executed 23/23 targeted and 381/381 full-suite tests successfully after the fix. Both diff checks and the scope audit passed. The original fresh pre-4D baseline remains 358/358.

## 2. Starting commit / branch / initial tree state

- Commit: `6ed4d2320b121e32c226a5dd0e6d97c4e625af8e`.
- Branch: `experience-layer/initial`.
- No tracked modifications or staged changes.
- Initial untracked paths: `.phase4b/`, `.phase4c/`, `.phase4e/`, `Docs/GamificationPhase4EReport.md`.
- The completed 4E production/tests were already committed. Its untracked report and all prior tooling were preserved.
- Nothing committed in this phase.
- At the semantic-fix follow-up, both phase reports were already staged by the user. Their index contents were captured and preserved exactly; the updated 4D report remains an unstaged working-tree update.

## 3. Fresh baseline

Before adding production or test files, ran the complete `HabitHonkerTests` suite on the current pre-4D tree. Xcode 26.2 (17C52), iPhone 17 Pro Max simulator, iOS 26.0, destination `24629C99-E950-4563-BA70-118CE5D96451`.

**358 total, 358 passed, 0 failed, 0 skipped; exit 0.** Source: `.phase4d/baseline-approved.xcresult`, summary `.phase4d/baseline.summary.json`.

The initial sandboxed attempt could not access CoreSimulator. The authorized run above actually built and ran all tests. xcresult extraction also required access to Xcode's report cache. No code was changed before the successful baseline.

## 4. Goal and architecture

`BehaviorOccurrencePlanning` → `BehaviorOccurrencePlanner`: immutable scheduling inputs produce a planned obligation, a typed absence, or a typed deferral. Foundation only; no persistence, clock, random IDs, device policy, gameplay effects or application wiring.

The existing domain has no pure `TaskOccurrence` value. `TaskOccurrenceSD` is persistence state; the Phase 3 `BehaviorOccurrenceSnapshot` requires streak/provenance/alias facts that scheduling cannot supply. The new `BehaviorPlannedOccurrence` therefore carries only scheduling output, reusing `BehaviorScheduleSnapshot`, `LocalDay`, `BehaviorTargetID`, and `GamificationTaskType`. It does not fabricate a transaction or reward input.

## 5. Planner input contract

`BehaviorOccurrencePlanningInput` contains target ID, enrolled `BehaviorSchedulingPolicy`, all physical `BehaviorScheduleRevisionFacts` for that target, and action instant. All values come from the caller. Current Habit fields and completion records are not inputs.

The caller must fetch/filter rows by target **before** invoking the existing 4B mapper: a nil snapshot in `BehaviorScheduleRevisionFacts` cannot expose its target. Decodable snapshots with a different target are explicitly rejected. Integration tests demonstrate this adapter boundary without adding production persistence wiring.

## 6. Planner result contract

- `.planned`: logical occurrence ID, owning logical revision ID, complete frozen snapshot, local day, optional scheduled instant. Target, task type and one-time due instant are available from the snapshot.
- `.noOccurrence`: before enrollment, unselected weekday, candidate before enrollment, candidate outside the selected revision, or a proven no-active-revision interval.
- `.deferred`: invalid instant/interval, pre-enrollment history, duplicate revision identity, overlaps, undecodable/invalid snapshot, missing revision, or unrepresentable local day/clock.

All input/result types are immutable, Equatable and Sendable. There are no reward fields, persisted flags or mutations.

## 7. Repeating occurrence semantics

An action refers to its own profile-local day. There is no nearest-occurrence lookup, carry-over to a previous missed day, or background generation. The historical weekday mask must select that day: Sunday bit 0 through Saturday bit 6. Empty masks yield no occurrence.

Reminders off preserve nil hour/minute and nil scheduled instant. An untimed obligation exists on the part of the selected day where the action is inside the revision and after enrollment; no midnight reminder is invented. This permits an untimed obligation on a partial enrollment day.

Timed obligations use the snapshot's local clock. Both action and scheduled instant must fall in the selected revision; scheduled instants before enrollment are rejected. An action earlier than today's reminder is allowed if the reminder still belongs to that revision.

## 8. One-time occurrence semantics

`dueAt` is authoritative, including when notifications are off. Mask must be zero and hour/minute nil. The output's local day is the due instant's profile-local day, not the completion day; `scheduledAt` is nil and `dueAt` stays exact.

Early, exact-due and late actions have the same one-time identity when action and due instant are inside the owning revision. An expired revision cannot own a later action. A due instant before enrollment does not generate retroactive history. No timing reward classification is introduced.

## 9. Identity contract

The planner directly uses unchanged `OccurrenceIdentityV1`:

- repeating: `occ:v1:<target>:day:<local-day>`;
- one-time: `occ:v1:<target>:once`.

No duplicated string formatter, random UUID, physical row identity, hash-derived key or revision-dependent occurrence key. Equivalent inputs produce equal complete output, including identity.

## 10. Revision ownership and half-open boundaries

Action ownership is `[effectiveFrom, effectiveTo)`. At T, the old revision ending T is excluded and the new revision starting T is included. There is no epsilon or boundary adjustment. Timed/due candidate membership uses the identical half-open predicate.

4B's legitimate empty `[T,T)` revisions are accepted and own no actions. Backwards/nonfinite intervals are rejected. History input order cannot alter success or conflict classification; validation uses category passes, and row selection occurs only after proving uniqueness.

## 11. Enrollment boundary

An action before `trackingStartedAt` returns `.beforeEnrollment`. At enrollment, planning is allowed when the schedule and candidate timing permit it. Candidate reminder/due instants before enrollment return `.candidateBeforeEnrollment`. Input history starting before enrollment is deferred. No enrollment date is moved, no baseline created, and no legacy record is interpreted as a scheduled obligation.

## 12. Time-zone / calendar semantics

The enrolled profile's Gregorian calendar and exact zone identifier are authoritative. Snapshot policy must match. `GregorianLocalDayCalculator` supplies civil days and frozen 4C identity context. No device calendar/time zone/locale is read.

Integration test switches both actual system and default zones using the proven B82/E83 technique, asserts Tokyo and London preconditions, restores the prior environment, and compares complete planning results. January 15 01:00 UTC plans January 14 in LA.

## 13. DST semantics

Foundation `date(bySettingHour:minute:second:of:matchingPolicy:repeatedTimePolicy:direction:)` uses the policy calendar, `.nextTime`, `.first`, `.forward`, second zero. The result must stay within the candidate local day.

- LA spring forward, March 14 2027: missing 02:30 becomes 03:00 (10:00 UTC); local day is 23 hours.
- LA fall back, November 7 2027: repeated 01:30 selects the first instant (08:30 UTC); local day is 25 hours. Actions in either repeated hour yield identical output.
- Midnight is included without subtracting an epsilon; 23:59 stays on the profile day despite crossing the UTC date.

No fixed 24-hour arithmetic or implicit device-state normalization.

## 14. Ambiguous-history behavior

Validation is deliberately conservative across the supplied target history: duplicate logical IDs (including identical physical rows), overlapping nonempty intervals, undecodable snapshots and malformed scheduling facts defer the entire request, even if corruption is outside the action's interval. No row wins by input order, UUID, earliest time or latest time.

Malformed snapshot checks cover target/policy mismatch, out-of-range weekday masks/clocks, hidden clocks with notifications off, missing timed clocks, one-time missing/nonfinite due instant, and invalid type-specific fields. After all structural validation, zero covering revisions return `.noOccurrence(.noActiveRevision)` only when a nonempty closed revision has `effectiveTo <= actionAt`. This covers the exact deletion boundary, gaps before a later restore, and time after the final closed revision. An open/closed revision covering the action still follows normal planning. Multiple covering revisions remain deferred as overlaps.

Empty history, time before the first revision, and zero-length-only history remain `.deferred(.missingRevision)`: they cannot prove a prior active lifetime. No current Habit state, ordering, physical ID, lifecycle flag or reconciliation guess is used. Corruption elsewhere in the supplied chain is still rejected before absence classification.

Nothing reconciles, repairs, merges, closes, inserts or deletes history.

## 15. Production files changed

None of the existing production files changed. No existing test changed.

## 16. New production files

- `Core/Domain/BehaviorOccurrencePlan.swift`
- `Core/Protocols/BehaviorOccurrencePlanning.swift`
- `Core/Services/BehaviorOccurrencePlanner.swift`

Paths are relative to `HabitHonker/HabitHonker/`. Xcode's synchronized folders discover these files; the project file is unchanged.

## 17. Tests added

`BehaviorOccurrencePlannerTests`: 19 pure tests, including a 7×7 weekday matrix, malformed payload matrix, exact transitions, deterministic identities, early/on-time/late one-time actions, partial enrollment days, UTC crossings, DST, midnight, candidate membership, gaps, overlaps, duplicate rows, empty/invalid intervals, nonfinite dates and Foundation-only architecture guards. No SwiftData dependency in this test file.

`BehaviorOccurrenceIntegrationTests`: 4 integration tests. Total **23 tests** after the semantic fix (the original 20 passed in `.phase4d/targeted.xcresult`). Dedicated tests cover healthy gaps, exact deletion/restore boundaries, final closure, empty/pre-first histories, order independence, and unsafe-history precedence. `.phase4d/results.py` prints each declared test as PASS/FAIL/MISSING from xcresult (no console fallback).

## 18. Integration verification

Real production service/adapter/actor paths prove:

1. 4E enrollment creates a baseline usable by 4D; real schedule edit closes it and opens a normal revision; historical lookup remains unchanged and exact T belongs to the new revision.
2. Creation after enrollment creates a normal revision only; delete closes the revision without a replacement and yields `noActiveRevision` at/after deletion, including retrospective gap lookup after restore; restore opens a new normal revision without rewriting prior ownership.
3. Actual device timezone changes cannot change enrolled planning.
4. Planning leaves every persisted row unchanged; subsequent live completion creates a legacy record only, with zero occurrence/event/ledger rows and zero profile balances.

## 19. Schema / scope audit

**PASS.** `.phase4d/audit.sh` enforces no changed tracked file, an exact new-file allowlist, no model/schema/migration changes, no persistence/reward/enrollment operations in new production files, and preservation of the user’s existing staged reports. It runs both normal `git diff --check` and an untracked-inclusive check using a throwaway index.

The exact additive allowlist also prevents introducing any 4G or Phase 5 production service. All frozen 4B/4C/4E/4F, Phase 1/3, repository, UI and Xcode project files remain untouched.

## 20. Live behavior audit

No planner consumer was added to production. `HabitService.completeHabit`, `recordLegacyCompletion`, and transaction routing are byte-for-byte unchanged. No live occurrence/event/ledger writes, XP/coins, automatic enrollment, background work, notification changes, reconciliation or UI activation.

## 21. Baseline / targeted / final counts

| Run | Total | Passed | Failed | Skipped | Exit |
|---|---:|---:|---:|---:|---:|
| Fresh pre-4D baseline | 358 | 358 | 0 | 0 | 0 |
| Original Phase 4D targeted | 20 | 20 | 0 | 0 | 0 |
| Original full suite | 378 | 378 | 0 | 0 | 0 |
| Semantic-fix targeted | 23 | 23 | 0 | 0 | 0 |
| Semantic-fix final full suite | 381 | 381 | 0 | 0 | 0 |

Latest bundles: `.phase4d/fix-targeted.xcresult` and `.phase4d/fix-final.xcresult`; corresponding `.summary.json` and `.tests.json` files retain counts and per-test results. The 23-test PASS matrix is `.phase4d/fix-targeted-matrix.txt`. The final full run includes **124/124 Phase 4B** and **59/59 Phase 4E** regression tests, all PASS, along with all prior Phase 1/2/3/4C/4F, metadata persistence and notification tests. There were no skips.

Counts use xcresult summaries. `.phase4d/verify.sh` reproduces the workflow: extracts the captured pre-4D tracked-tree archive into a temporary directory, runs a fresh baseline, targeted tests with per-test matrix, full suite including 4B/4E regressions, then audits. Starting commit/branch/status are retained separately. `.phase4d/` is local tooling only and must not be committed.

## 22. Known limitations

- Action-centric same-day lookup only; arbitrary backdated assignment, carry-over and missed-obligation enumeration are outside this phase.
- Multiple nonoverlapping revisions on the same day can describe the same frozen daily identity at different action instants. This planner attributes each action without reconciling already persisted occurrences. Future transaction/reconciliation work must not silently rewrite an existing occurrence snapshot.
- One-time due changes preserve one lifetime identity. Existing persisted occurrence compatibility is a later transaction concern.
- Conservative validation may defer otherwise locally usable history. This is intentional; 4G will resolve history, not this planner.
- Empty and pre-first histories require more trusted lifecycle/coverage evidence to distinguish legitimate absence from missing history; that remains a 4G/Phase 5 concern. No speculative state is added.
- Caller must provide complete target-scoped physical history and an enrolled policy. No persistence adapter or live consumer was added.
- Foundation timezone rules are used explicitly; this is not a bundled, version-pinned timezone database.

## 23. Final gate

**PASS after semantic fix:** deterministic pure protocol-backed planner, historical revisions and profile policy authoritative, existing identity reused, half-open ownership, explicit one-time/repeating semantics, no retroactive enrollment, typed ambiguity, 23/23 targeted tests, 381/381 full-suite tests, both diff checks clean, scope audit OK. No schema/model or existing-file changes; no live writers, rewards or automatic enrollment enabled.

**READY FOR PHASE 4G / PHASE 5: NO.** No later phase started. Nothing committed.
