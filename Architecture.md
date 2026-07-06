# HabitHonker Architecture

This document captures the Stabilization Phase baseline. It describes the current app shape, known boundaries, and risks without changing product behavior. It should be updated as stabilization work lands.

## 1. Current App Overview

HabitHonker is a SwiftUI habit and task tracker backed by SwiftData, UserDefaults-backed settings, local notifications, and an optional CloudKit-backed SwiftData container.

Current primary tabs:

- List: active habits/tasks, completion, create/edit/delete entry points.
- Priority: Eisenhower-style priority matrix with drag/drop priority changes.
- Statistic: calendar-style completion history for selected habits.
- Settings: appearance, priority theme, background image, and iCloud sync toggle.

Current production dependency flow is mostly:

```text
SwiftUI View -> ViewModel -> Service -> Repository Protocol -> SwiftData Repository -> SwiftData Models
```

The current architecture is stable enough to begin stabilization work, but not yet stable enough for the Core phase or prediction-engine work.

## 2. Bounded Contexts

### Habit Tracking

Owns active habits/tasks, create/edit/delete, daily completion, schedule metadata, and current list sorting/filtering.

Primary files:

- `HabitHonker/HabitHonker/Screens/TaskList/HabitModel.swift`
- `HabitHonker/HabitHonker/Screens/TaskList/HabitListView.swift`
- `HabitHonker/HabitHonker/Screens/TaskList/HabitListViewModel.swift`
- `HabitHonker/HabitHonker/Screens/AddNewHabit/HabitDetailView.swift`
- `HabitHonker/HabitHonker/Core/Services/HabitService.swift`

### Persistence And Sync

Owns SwiftData models, mapping, local/CloudKit container setup, active/deleted habit storage, and statistics preset storage.

Primary files:

- `HabitHonker/HabitHonker/App/HabitHonkerApp.swift`
- `HabitHonker/HabitHonker/Repository/SwiftDataRepository/HabitItemSD.swift`
- `HabitHonker/HabitHonker/Repository/SwiftDataRepository/DeletedHabitSD.swift`
- `HabitHonker/HabitHonker/Repository/SwiftDataRepository/StatisticsPresetSD.swift`
- `HabitHonker/HabitHonker/Repository/SwiftDataRepository/HabitMapper.swift`
- `HabitHonker/HabitHonker/Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift`
- `HabitHonker/HabitHonker/Core/Repositories/SwiftDataHabitRepository.swift`

### Notifications

Owns local notification authorization, scheduling, rescheduling, and cancellation.

Primary files:

- `HabitHonker/HabitHonker/Servise/HabitNotificationService.swift`
- `HabitHonker/HabitHonker/Screens/TaskList/HabitListViewModel.swift`

### Priority Matrix

Owns priority display, drag/drop priority changes, priority colors, and custom priority titles.

Primary files:

- `HabitHonker/HabitHonker/Screens/PriorityMatrix/PriorityMatrixView.swift`
- `HabitHonker/HabitHonker/Screens/PriorityMatrix/PriorityMatrixViewModel.swift`
- `HabitHonker/HabitHonker/Screens/PriorityMatrixEditor/PriorityMatrixEditorView.swift`
- `HabitHonker/HabitHonker/Core/Services/PriorityThemeService.swift`
- `HabitHonker/HabitHonker/Repository/UserDefaultsStore/UserDefaultsStore.swift`

### Statistics

Owns statistics habit selection, selection persistence, calendar generation, and display of completion history, including deleted habits selected for historical display.

Primary files:

- `HabitHonker/HabitHonker/Screens/StaisticsScreen/StaisticsView.swift`
- `HabitHonker/HabitHonker/Screens/StaisticsScreen/StaisticsViewModel.swift`
- `HabitHonker/HabitHonker/Screens/StaisticsScreen/CalendarBuilder.swift`
- `HabitHonker/HabitHonker/Screens/SelectHabits/SelectHabitsView.swift`
- `HabitHonker/HabitHonker/Screens/SelectHabits/SelectHabitsViewModel.swift`
- `HabitHonker/HabitHonker/Core/Services/StatisticsService.swift`

### Settings And Appearance

Owns app color scheme, custom priority theme, background image storage, and the iCloud toggle UI.

Primary files:

- `HabitHonker/HabitHonker/Screens/SettingsScreen/SettingsView.swift`
- `HabitHonker/HabitHonker/Screens/SettingsScreen/SettingsViewModel.swift`
- `HabitHonker/HabitHonker/Helpers/SyncManager.swift`
- `HabitHonker/HabitHonker/Core/Services/BackgroundService.swift`
- `HabitHonker/HabitHonker/Helpers/BackgroundStorage.swift`

## 3. Glossary

- Habit: A repeating behavior target or one-time task displayed in the app.
- HabitModel: Current in-memory app model for habits/tasks.
- HabitSD: SwiftData active habit model.
- DeletedHabitSD: SwiftData archived/deleted habit model used for soft delete and historical statistics.
- HabitRecord: Current completion aggregate for a habit on a date.
- PriorityEisenhower: Current four-quadrant priority enum.
- StatisticsPresetSD: SwiftData model storing selected habit IDs for statistics.
- BehaviorTarget: Pure domain value type introduced under `Core/Domain` for a habit/task-like thing. Not wired into production flow yet.
- BehaviorSchedule: Pure domain value type introduced under `Core/Domain` for repeating weekday schedules and one-time due dates.
- BehaviorPriority: Pure domain value type introduced under `Core/Domain` for the four current Eisenhower priority concepts.
- BehaviorEvent: Pure domain value type introduced under `Core/Domain` for future event history. Not wired into production flow yet.
- TargetReminderConfig: Pure domain value type introduced under `Core/Domain` for future reminder delivery configuration. Not wired into notification scheduling yet.

## 4. Current Module And Layer Map

### App Layer

- `HabitHonkerApp` creates or rebuilds the SwiftData `ModelContainer`.
- `AppDependencies` creates shared services, repositories, feature flags, and the current event center.
- `RootTabsView` creates the tab-level ViewModels.

### UI Layer

- SwiftUI screens live under `Screens`.
- Some views still launch async work through `Task {}` closures.
- Some views import SwiftData even when persistence is not directly used.

### ViewModel Layer

- `HabitListViewModel` owns list loading, save/delete/complete orchestration, notification side effects, appearance loading, and event reload subscription.
- `PriorityMatrixViewModel` owns matrix loading, theme loading, and priority changes.
- `StatisticsViewModel` owns preset loading, selected filters, and calendar generation pipeline.
- `SettingsViewModel` owns priority theme editing and background image processing.

### Service Layer

- `HabitService` wraps habit mutations and emits coarse habit events.
- `StatisticsService` resolves selected statistics habits from active and deleted stores.
- `PriorityThemeService` wraps UserDefaults-backed priority colors/titles.
- `BackgroundService` wraps background image file storage and image optimization.

### Configuration Layer

- `FeatureFlags` is a local/static feature flag value injected through `AppDependencies`.
- Flags are not remote-configured and are not persisted.
- All future-facing flags default to `false`.
- SwiftUI views should not reach for global flag state directly. Prefer passing flags through dependencies to ViewModels/services when a future change needs a gated branch.

### Repository Layer

- `HabitRepositoryProtocol` abstracts habit persistence.
- `SwiftDataHabitRepository` adapts `HabitsRepositorySwiftData`.
- `HabitsRepositorySwiftData` is an actor that creates a new `ModelContext` per operation.

### Core Domain Layer

- `HabitHonker/HabitHonker/Core/Domain/BehaviorTarget.swift`
- `HabitHonker/HabitHonker/Core/Domain/BehaviorSchedule.swift`
- `HabitHonker/HabitHonker/Core/Domain/BehaviorPriority.swift`
- `HabitHonker/HabitHonker/Core/Domain/BehaviorEvent.swift`
- `HabitHonker/HabitHonker/Core/Domain/TargetReminderConfig.swift`

These types are pure Swift values for future Core phase work. They do not import SwiftUI, SwiftData, UserNotifications, or CloudKit. They are not yet wired into production services, repositories, ViewModels, or screens.

`HabitModel` remains the production in-memory app model for now.

## 5. Data Flow

### Create Habit

1. User opens add habit from `HabitListView`.
2. `HabitDetailView` builds a new `HabitModel`.
3. `HabitListViewModel.saveItem` stores the item and schedules notification side effects.
4. `HabitService.saveHabit` upserts through the repository and emits `.created`.
5. Event subscribers reload relevant screens.

### Edit Habit

1. User opens detail from `HabitListView`.
2. `HabitDetailView` edits a copy of the current `HabitModel`.
3. `HabitListViewModel.saveItem` saves the edited habit.
4. `HabitService.saveHabit` emits `.updated`.

### Complete Habit

1. User swipes a habit in `HabitListView`.
2. `HabitListViewModel.habitCompleteWith` performs an optimistic in-memory completion.
3. `HabitService.completeHabit` fetches, updates `HabitRecord`, persists, and emits `.completed`.
4. List and matrix reload through event subscription.

### Delete / Archive Habit

1. User confirms delete from `HabitDetailView`.
2. `HabitListViewModel.deleteItem` calls notification cancellation and service delete.
3. `HabitsRepositorySwiftData.delete` maps active `HabitSD` to `DeletedHabitSD`, inserts the deleted row, deletes the active row, and saves.
4. `HabitService.deleteHabit` emits `.deleted`.

### Restore Habit

Restore exists in service/repository code, but an active UI entry point was not confirmed during the baseline audit.

### Priority Change

1. User drags a habit in `PriorityMatrixView`.
2. `PriorityMatrixViewModel.changePriorityFor` performs an optimistic priority change.
3. `HabitService.changePriority` persists the change and emits `.priorityChanged`.

### Statistics Refresh

1. `StatisticsViewModel.loadPresetHabits` loads selected active/deleted habits.
2. `CalendarBuilder` indexes completion records by day.
3. `StaisticsView` renders months and day cells.
4. Habit events trigger preset reloads.

### Settings

1. Appearance uses `@AppStorage("appearance")`.
2. Priority theme uses `UserDefaultsStore`.
3. Background image uses file storage in app documents.
4. iCloud toggle uses `SyncManager` and triggers container rebuild in `HabitHonkerApp`.

## 6. Persistence Model

Current SwiftData schema:

- `HabitSD`: active habit/task.
- `HabitRecordSD`: completion record linked to either active or deleted habit.
- `DeletedHabitSD`: archived/deleted habit.
- `StatisticsPresetSD`: selected statistics habit IDs.

Current model risks:

- No explicit migration/versioning strategy is documented.
- CloudKit support is configured by rebuilding the SwiftData container.
- If container creation fails, the app currently falls back to an in-memory container.
- `HabitModel` contains `SwiftUI.Color`, so it is not a pure domain model.
- Repeating habits use `dueDate` as notification time, while due-date tasks use it as date/time.

## 7. Notification Flow

Current behavior:

- Authorization is requested on app launch from `HabitListViewModel.onAppLaunch`.
- `HabitNotificationService.reschedule` cancels existing requests for a habit and schedules new requests if enabled.
- Due-date habits schedule a one-shot notification.
- Repeating habits schedule one repeating notification per selected weekday.

Known stabilization risk:

- Save/delete callers can miss cancellation when notifications are disabled or when deleting a habit whose notification state is not the same as the current ViewModel editing item.

## 8. Known Risks

| Risk | Current status | Stabilization need |
|---|---|---|
| Notification lifecycle | Fragile | Validate disable/delete cancellation and fix before Core phase. |
| Statistics stale refresh | Fragile | Verify completion events refresh calendar when selected IDs do not change. |
| CloudKit/in-memory fallback | Fragile | Make fallback visible and manually verify sync toggle behavior. |
| No test target | Confirmed | Add test target and first service/model tests. |
| Restore UI unknown | Unknown | Confirm whether restore is supported in UI or document unsupported state. |
| HabitModel UI coupling | Confirmed | Document now; separate domain/UI model later. |

## 9. Feature Flag Policy

Current stabilization policy:

- No remote config during Stabilization or early Core work.
- No feature should become active because a flag exists; every new flag defaults off.
- Flags should gate future layers only at clear boundaries, preferably ViewModels, services, or dependency construction.
- Avoid scattered `FeatureFlags` checks inside SwiftUI view bodies.
- Removing obsolete flags is part of the cleanup responsibility after a feature graduates.

Current local flags:

| Flag | Default | Intended future use |
|---|---:|---|
| `enableEventLoggingV0` | `false` | Gate first local eventization experiments. |
| `enableBehaviorTargetShadowMapping` | `false` | Gate non-user-visible mapping from `HabitModel` toward `BehaviorTarget`. |
| `enablePredictionCoach` | `false` | Gate future anti-slip prediction coach surfaces. |
| `enableRescueCards` | `false` | Gate future rescue/intervention card UI. |
| `enableAppIntents` | `false` | Gate future App Intents work. |
| `enableWidgets` | `false` | Gate future widget work. |
| `enableStabilizationDiagnostics` | `false` | Gate temporary diagnostics used during stabilization. |

## 10. Future Mapping

| Current concept | Future concept | Notes |
|---|---|---|
| `HabitModel` | `BehaviorTarget` | Represents the thing the user wants to maintain or complete. |
| `HabitModel.HabitRecord` / `HabitRecordSD` | `BehaviorEvent` | Current data is daily aggregate history, not event-level history. |
| `PriorityEisenhower` | `BehaviorPriority` | Current priority is four fixed buckets with customizable display. |
| `isNotificationActivated`, `dueDate`, `repeating` | `DeliveryPreferences` / `TargetReminderConfig` | Needs a dedicated reminder config later. |
| `StatisticsPresetSD` and `CalendarBuilder` inputs | `EventHistory` / snapshot input | Statistics should eventually read from event history. |
| `HabitEvent` | `DomainEvent` | Current event bus is coarse and payload-free. |

The first pure domain types for this mapping now exist under `Core/Domain`, but the mapping itself is not implemented yet. `HabitModel` remains the production model used by current screens, ViewModels, services, and persistence adapters.

## 11. Stabilization Acceptance Checklist

- All existing tabs open correctly.
- Create habit works.
- Edit habit works.
- Delete/archive/soft delete works.
- Restore works if the app supports it.
- Complete habit works.
- Priority matrix still works.
- Statistics still works and refreshes after completion.
- Local notifications are not broken.
- iCloud toggle and sync-related settings are not broken.
- Major business logic is not hidden directly inside SwiftUI views where it blocks the next architecture step.
- Feature flags are planned before future engine/event layers are added.
- This document and the manual QA checklist stay current.
