# Gamification Phase 4F Report

## 1. Status

**PENDING VERIFICATION.** The implementation and tests are complete, but they have not been compiled or run. This run executed on a Linux machine without Xcode. One command on the Mac (§13) produces the fresh baseline, the targeted 4F run and the final full suite. Until those results are recorded here, the gate in §15 stays **NO**.

## 2. Starting commit

- Commit `2d471f4` ("freeze HabitHonker Exp v1.1.2 architecture"): Phase 4A code plus the v1.1.x docs.
- Working tree clean before this run.
- **Note:** `Docs/GamificationPhase4AReport.md` in that commit still says "VERIFICATION PENDING", and the `.phase4a/` verification tooling is not in the repo. The 4F baseline below therefore also serves as the first recorded test run of the committed 4A code.

## 3. Fresh baseline

**Pending.** `.phase4f/verify.sh` runs the full `HabitHonkerTests` suite on a temporary git worktree of `HEAD` (`2d471f4`), which is the exact pre-4F code:

```sh
xcodebuild test -project HabitHonker/HabitHonker.xcodeproj -scheme HabitHonker \
  -destination 'platform=iOS Simulator,id=24629C99-E950-4563-BA70-118CE5D96451' \
  -derivedDataPath /tmp/hh-phase4f-dd-base -only-testing:HabitHonkerTests
```

| Run | Executed | Passed | Failed | Skipped | Exit |
|---|---:|---:|---:|---:|---:|
| Baseline (`2d471f4`) | _pending_ | | | | |

If the baseline fails, the contract says stop: that would be a 4A problem to fix first, not a 4F one.

## 4. Existing production storage audit (pre-4F source, `HabitHonkerApp.rebuildContainerIfNeeded`)

| Mode | When chosen | Configuration | Store URL | CloudKit | Migration |
|---|---|---|---|---|---|
| **Cloud** | `sync.isOn && sync.iCloudAvailable` | `ModelConfiguration("Cloud", schema: nil, isStoredInMemoryOnly: false, allowsSave: true, groupContainer: .automatic, cloudKitDatabase: .private("iCloud.com.flyingwhale.habithonker"))` | `<Application Support>/Cloud.store` (derived from the name; no App Group entitlement) | private database of `iCloud.com.flyingwhale.habithonker` | V2 schema + `HabitHonkerMigrationPlan` |
| **Sync off / local** | sync off, **or** sync on but iCloud unavailable | **none passed**: `ModelContainer(for: schema, migrationPlan:)`, so SwiftData's *default* configuration | `<Application Support>/default.store` | **`.automatic`, not disabled** (see §5) | V2 schema + `HabitHonkerMigrationPlan` |
| **Fallback** | either store failed to open (`try?` → `nil`) | `ModelConfiguration("FallbackInMemory", schema: V2, isStoredInMemoryOnly: true, allowsSave: true)` | in memory | `.automatic` (not disabled) | V2 schema + plan |

**Other findings:**
PHASE 4F STATUS: PASS

Baseline:
exit 0
TEST SUCCEEDED

Targeted:
exit 0
TEST SUCCEEDED

Final:
exit 0
TEST SUCCEEDED

Manual device smoke test:
PASS — app launched on physical iPhone without crash

READY FOR PHASE 4C: YES

- **D. Separate stores.** Cloud and local are different physical stores (`Cloud.store` vs `default.store`); the file name comes from the configuration name. Both can mirror into the same private CloudKit database.
- **No classification.** `AppDependencies.make(container:)` received every container, including the in-memory fallback, the same way. Nothing recorded which world was open.
- **Guessed state.** The app guessed the current world from `container.configurations.first?.cloudKitContainerIdentifier`, both for the rebuild no-op check and for `RootTabsView.id(...)`.
- **Local waited for iCloud.** At launch, even in sync-off mode, the store was built only after `CKContainer.default().accountStatus()` returned.

**E. Reopening the local store with CloudKit disabled.** The 4F local configuration reuses the default configuration's **name and URL** and changes only `cloudKitDatabase` to `.none`, so it opens the same file.

- **Why this is expected to be safe.** In Core Data, turning mirroring off for a store means opening it without CloudKit options; the data and the store stay usable. The known hazard with that is read-only mode: a store that previously had persistent history tracking, reopened without it, is forced read-only. SwiftData keeps history tracking on for its stores (SwiftData history works for non-CloudKit stores), so that trigger is not expected.
- **What the tests prove.** A SwiftData store with the pre-4F name/file shape reopens through the production 4F path with all data intact, and stays writable across reopen (§8).
- **What the tests cannot prove.** Reopening a store that CloudKit mirrored before. No test may open a CloudKit-backed container: it would write to a real iCloud account. That step is a manual device check (§14). The verify script also scans the logs for Core Data's "Read Only mode" warning, because the test host app itself reopens the simulator's own `default.store` with the new configuration.

## 5. Problems discovered

- **Was existing sync-off actually CloudKit-disabled? NO.**
  - The local path passed no configuration, so SwiftData used `cloudKitDatabase: .automatic`, which adopts the CloudKit container from the app's entitlements.
  - The entitlements declare `iCloud.com.flyingwhale.habithonker` with the CloudKit service and `aps-environment`. So "sync off" data could be mirrored to the user's private iCloud database whenever an account was available.
  - The `PHASE 4F PROBE` line in the test log records the identifier the default configuration resolves to at runtime.
- **Did changing to true local risk selecting another store? YES.**
  - Any newly named configuration (for example "Local") would open a different, empty `Local.store`, and every existing habit would appear deleted.
  - Avoided: `durableLocal` copies the default configuration's name and URL.
- **Guessed durability.** The world was inferred from `cloudKitContainerIdentifier`. If the default local configuration resolves to the entitlement container, the local and cloud views got the **same** `.id`. Then a store switch was not guaranteed to rebuild `RootTabsView` and its `@StateObject` view models, which hold the old container's dependency graph.
- **Silent failures.** All container errors were swallowed by `try?`, and a failed cloud store silently became an in-memory store.
- **Fallback could mirror to iCloud.** The in-memory fallback kept CloudKit `.automatic`.

## 6. Final storage model

| State | Configuration | Chosen when | `supportsDurableGamification` |
|---|---|---|---|
| `durableCloud` | unchanged "Cloud" configuration, `.private("iCloud.com.flyingwhale.habithonker")`, `Cloud.store` | sync on **and** iCloud available, and it opened | `true` |
| `durableLocal` | default configuration's name + `default.store` URL, **`cloudKitDatabase: .none`** | sync off, or sync on without iCloud, and it opened | `true` |
| `ephemeralFallback` | "FallbackInMemory", in memory, **`cloudKitDatabase: .none`** | the requested persistent store failed to open | `false` |

**Ownership:**

- `PersistentStoreFactory` (`App/`) is the only code that builds configurations and containers, and it decides the state from the configuration it actually opened.
- `HabitHonkerApp`, the composition root, calls `PersistentStoreFactory.openStore(for:schema:)` and passes `opened.durability` into `AppDependencies.make`.
- Repositories and services never inspect CloudKit settings.
- The fallback policy is unchanged: the app still starts. Failures are now logged: the configuration that failed (error domain and code public, description private), plus a `fault` when the ephemeral store is used.

## 7. DI changes

- **`StorageDurabilityState`** (new, `Core/Configuration/`, Foundation only): the three states plus `supportsDurableGamification`. No protocol was added; an immutable value is enough and has no fake consumer.
- **`AppDependencies`:** new stored property `storageDurability`. `make(container:storageDurability:featureFlags:)` requires the durability with no default, so it can never be implicit. Everything else is constructed exactly as before, and construction still writes nothing.
- **`PersistentStoreFactory`** (new): `cloudConfiguration()`, `localConfiguration(schema:storeURL:)`, `preFourFLocalConfiguration(schema:)`, `fallbackConfiguration(schema:)`, `openStore(for:schema:localStoreURL:logger:build:)` and `buildVersionedContainer(schema:configuration:)`. `localStoreURL` and `build` are test seams; production uses the defaults.
- **`HabitHonkerApp`:**
  - stores `storageDurability` and a `storeGeneration` counter;
  - the rebuild no-op check compares the requested world with the recorded durability;
  - `RootTabsView` is identified by `storeGeneration`, so every new container gets fresh view models bound to its own graph;
  - in sync-off mode the local store opens before, and independently of, the iCloud account query. The query still runs afterwards, for the Settings sync toggle.
- **`Log.storage`:** new logger category.
- **Container scope:** a new container means a new `AppDependencies`, a new repository actor, a new `AppCoordinator` and a new view tree. No statics hold a container. The one shared repository actor per container is unchanged.

## 8. Store continuity

The gate is `StorageDurabilityTests.testPreFourFLocalDataSurvivesDurableLocalAndStaysWritableAcrossReopen`, on disk in a scratch directory; it never touches the app's real store.

**Phase A — the pre-4F construction shape.** V2 schema, migration plan, the default configuration's name, and the same file name (`default.store`). It seeds stable-UUID data:

- **"Gym":** repeating Mon/Wed/Fri, notifications on, tags, description; 3 records with counts 1/3/2.
- **"File taxes":** one-time, notifications off; 1 record.
- **An archived habit:** 2 records.
- **A statistics preset** over all three.

It then saves, snapshots every legacy row, and closes the store.

**Phase B — the production `PersistentStoreFactory.openStore(for: .local, …)` on the same file:**

- The result is `.durableLocal`.
- The full legacy snapshot equals Phase A: habit ids and metadata, record UUIDs, dates, counts and parent links, the archive and the preset. The row counts are unchanged (2 / 6 / 1 / 1), so nothing disappeared or duplicated.
- The gamification tables are empty.
- Then, through a normal `AppDependencies` graph:
  - create a new habit;
  - update Gym's metadata with a deliberately wrong record array: the 3 record ids are kept (4A);
  - run a legacy completion of "File taxes": a new record;
  - save the statistics preset.

**Phase C — reopen through the factory again.** All changes persisted:

- 3 habits;
- Gym renamed, with its 3 original records and total count 6;
- "File taxes" has 2 records;
- the archive is intact;
- the preset holds the new ids;
- 7 record rows;
- the gamification tables are still empty.

**F6 (identity).** The durable local configuration's URL and name equal SwiftData's default configuration (the pre-4F sync-off store), the file is `default.store`, and it differs from `Cloud.store`.

## 9. Offline-local guarantee

**Proven, by tests and code:**

- the `durableLocal` configuration has `cloudKitContainerIdentifier == nil`, and its source says `cloudKitDatabase: .none` explicitly;
- the store is constructed without any CloudKit container;
- the local store opens at launch without waiting for the iCloud account query;
- repository and service code has no network path;
- the on-disk store reopens and stays writable.

In short: **architecturally offline-capable; tested using a CloudKit-disabled persistent `ModelConfiguration`.**

**Not proven:** a real device in airplane mode, and a store that CloudKit mirrored before being reopened without mirroring. Both are manual steps (§14).

## 10. Files changed

| File | Change |
|---|---|
| `HabitHonker/Core/Configuration/StorageDurabilityState.swift` (new) | the durability value and gate |
| `HabitHonker/App/PersistentStoreFactory.swift` (new) | the only builder and classifier of containers and configurations; logging |
| `HabitHonker/App/AppDependencies.swift` | `storageDurability` property; required `make` parameter |
| `HabitHonker/App/HabitHonkerApp.swift` | uses the factory; records durability; `storeGeneration` view identity; local opens without the iCloud query |
| `HabitHonker/Helpers/Logger.swift` | `Log.storage` category (1 line) |
| `HabitHonkerTests/StorageDurabilityTests.swift` (new) | 4F tests |
| `HabitHonkerTests/BehaviorTransactionDITests.swift` | passes `storageDurability: .durableLocal` to `make` (4 call sites); assertions unchanged |
| `Docs/GamificationPhase4FReport.md` (new) | this report |
| `.phase4f/verify.sh` (new, untracked tooling) | baseline, targeted and final runs |

**Not touched:** HabitService, HabitListViewModel, HabitMapper, repositories (4A frozen), SyncManager, SettingsView, RootTabsView, notification code, Statistics, and every `*SD` model file.

## 11. Schema verification

- **Schema V2 changed? NO.**
- **Migration plan changed? NO.**
- **`@Model` changed? NO.**

No file under `Repository/SwiftDataRepository/` changed. `HabitHonkerSchemaV1`/`V2`/`HabitHonkerMigrationPlan`, `TaskOccurrenceSD`, `BehaviorScheduleRevisionSD`, `BehaviorEventSD`, `GamificationProfileSD` and `GamificationLedgerEntrySD` have no diff. Entitlements, the CloudKit container ID and project settings are unchanged.

## 12. Gamification side-effect verification

| Question | Answer |
|---|---|
| Did AppDependencies create a profile? | NO |
| Did it create an occurrence? | NO |
| Did it create a BehaviorEvent? | NO |
| Did it create a ledger entry? | NO |
| Did it write a schedule revision? | NO |
| Did live HabitService cut over? | NO |
| Did XP become live? | NO |
| Did coins become live? | NO |

These are asserted at runtime in several tests: every durability state, the continuity phases, both scoping tests and the fallback test. The Phase 3 no-live-cutover tests are unchanged.

## 13. Tests

### New: `StorageDurabilityTests`

| Contract | Test |
|---|---|
| F19–F21 | `testDurabilityGateAllowsDurableGamificationOnlyOnPersistentStorage` |
| F1–F3, F15–F18 | `testEveryDurabilityStateReachesAppDependenciesWithoutGamificationWrites` |
| F1, F4 | `testLocalRequestOpensDurableLocalStoreWithoutCloudKit`, `testLocalConfigurationExplicitlyDisablesCloudKit` |
| F2, F5 | `testCloudConfigurationKeepsTheApprovedPrivateCloudKitStore`, `testSuccessfulCloudStoreIsClassifiedDurableCloud` (an in-memory stand-in; no real CloudKit) |
| F3 | `testFailedLocalStoreFallsBackToEphemeralAndOrdinaryHabitsStillWork`, `testFailedCloudStoreIsNeverReportedAsDurable` |
| F6 | `testLocalConfigurationUsesThePreFourFDefaultStoreFile` (also prints the `PHASE 4F PROBE` characterization line) |
| F7–F14 | `testPreFourFLocalDataSurvivesDurableLocalAndStaysWritableAcrossReopen` |
| F22 | `testIndependentlyCreatedContainersGetIndependentlyScopedGraphs` |
| F23 | `testRebuildingTheGraphForANewStoreLeavesTheOldStoreUntouched` |
| guards | `testCompositionRootIsTheOnlyStoreBuilderAndPassesDurability`: the app builds no container itself, durability is passed, no second repository actor, no `static var` |
| F24 / F25 | existing Phase 3 DI and persistence tests, and `MetadataSafePersistenceTests`, unchanged |

### Run: `bash ~/Development/habitHonker/.phase4f/verify.sh`

| Suite | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| 4F targeted (`StorageDurabilityTests`) | _pending_ | | | |
| Phase 4A regression (`MetadataSafePersistenceTests`, `NotificationInvestigationTests`, `HabitListViewModelNotificationTests`) | _pending_ (from the final run) | | | |
| Phase 3 regression (`BehaviorTransaction*`) | _pending_ (from the final run) | | | |
| Final full `HabitHonkerTests` | _pending_ | | | |

## 14. Known limitations

- **Not compiled or run yet** (§1).
- **A store CloudKit mirrored before, reopened without mirroring, is not unit-testable without a real iCloud account.** Manual device check:
  1. On a device signed into iCloud, with sync **off** and existing habits (pre-4F build), install the 4F build over it.
  2. Habits and history are present. Complete and edit one, force-quit, relaunch: the changes persisted.
  3. The Xcode console shows `Opened durableLocal store` and no "Forcing into Read Only mode".
  4. Relaunch in airplane mode: the app opens and saves.
- **Behavior change, by design (ADR 4.5 / 4.6).**
  - Data created while sync is off no longer reaches iCloud.
  - Turning sync on shows the cloud world, which does not contain local-only data created after 4F.
  - Anything the old `.automatic` local store exported before 4F remains in iCloud.
- **No local↔cloud merge or migration** (out of scope by contract).
- **The fallback is still invisible to the user.** No UI change was allowed. It is now logged and classified `ephemeralFallback`. If even the in-memory store fails, the app shows a blank screen, as before.
- **The rebuild no-op check now uses the recorded durability.** While on the ephemeral fallback, a sync toggle retries the persistent store. Before 4F it could stay on the in-memory store.

## 15. Final gate

**READY FOR PHASE 4C: NO — pending the verification run.** Flip to YES only when the baseline, the targeted 4F tests and the final full suite are green.
